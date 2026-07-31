import Combine
import Foundation
#if os(macOS)
import Network
#endif

// The listening side of the protocol only ever runs on the Mac — the
// companion and the MCP server. Compiling it for iOS linked a TCP listener
// into every consumer app, which is dead code that still drags Network into
// their App Store binary and invites questions from security review.
#if os(macOS)

/// Receives measurement snapshots from instrumented apps. Used by the
/// PrismKit companion (or any custom tooling) on the Mac side.
public final class MeasurementStreamServer: ObservableObject {
    /// The most recent snapshot received from a connected app.
    @Published public private(set) var snapshot: MeasurementSnapshot?

    /// Whether at least one instrumented app is currently connected.
    @Published public private(set) var isReceiving = false

    /// The last listener error, if any (e.g. the port is already in use).
    /// The server retries automatically while this is non-nil.
    @Published public private(set) var lastError: String?

    /// Whether the connected app answered its last liveness probe in time.
    ///
    /// False while nothing is connected — there is nothing to be responsive —
    /// and, more usefully, false while the app is connected but its main
    /// thread is not running: stopped at a breakpoint, deadlocked, or busy in
    /// a long synchronous call. That is the case the socket alone cannot tell
    /// apart from a screen that simply is not changing.
    @Published public private(set) var isAppResponsive = false

    /// How long the last answered probe took to come back, or nil if none has
    /// been answered since the app connected.
    @Published public private(set) var lastProbeRoundTrip: TimeInterval?

    /// The most recent screen the app rendered for us, or nil if none has been
    /// asked for yet — or if the connected app is built against a PrismKit
    /// that predates frames, in which case the request is simply ignored and
    /// the caller should fall back to whatever picture it had before.
    @Published public private(set) var screenFrame: ScreenFrame?

    /// Components most recently drawn on their own, by measurement id.
    ///
    /// An id being absent is normal: the app may be on iOS 15, where a view
    /// cannot be drawn off screen, or the component may have gone. Callers are
    /// expected to fall back to cropping `screenFrame`, which shows the
    /// component with everything drawn on top of it.
    @Published public private(set) var componentRenders: [String: ComponentRender] = [:]

    /// Measurement ids the app declined to draw, via `PrismKit.rendersComponent`.
    /// Worth showing: a blank where a picture was expected is a bug hunt, and
    /// "the app is set not to send this one" ends it in a sentence.
    @Published public private(set) var refusedComponentRenders: Set<String> = []

    /// While paused, incoming snapshots are drained without decoding or
    /// publishing, freezing `snapshot` on the last received frame. The
    /// connection stays open so resuming is instant.
    @Published public var isPaused = false {
        didSet {
            let paused = isPaused
            queue.async { self.pausedFlag = paused }
        }
    }

    private var pausedFlag = false
    private let queue = DispatchQueue(label: "PrismKit.StreamServer")
    private let decoder = JSONDecoder()
    private var listener: NWListener?
    private var connectionCount = 0
    private var activeConnection: NWConnection?
    private var port: UInt16 = MeasureStreamDefaults.resolvedPort
    private var isStopped = false

    private var probeTimer: DispatchSourceTimer?
    /// The probe waiting for an answer, and when it went out.
    private var pendingProbe: (id: String, sentAt: Date)?
    /// Counts probes so each carries a distinct id without needing randomness.
    private var probeCount = 0

    private var frameRequestCount = 0
    /// The frame request still outstanding, and when it went out. One at a
    /// time: asking again while the app is still drawing the last one would
    /// queue work on its main thread faster than it can be done.
    private var pendingFrameRequest: (id: String, sentAt: Date)?

    private var componentRequestCount = 0
    private var pendingComponentRequest: (id: String, sentAt: Date)?
    /// After this, an unanswered request is abandoned so the next one can go
    /// out. Without it, one app that never replies — an older PrismKit that
    /// has never heard of frames, or a render that failed — would mean no
    /// frame is ever requested again for the rest of the session.
    private let frameTimeout: TimeInterval = 5

    /// How often the app is asked whether it is still running its main thread.
    /// Cheap — one short line each way — so this is about how quickly a stall
    /// is noticed, not about cost.
    private let probeInterval: TimeInterval = 2
    /// How long an unanswered probe waits before the app is called stalled.
    /// Generous on purpose: a device mid-animation can be slow to reply, and
    /// crying "paused" at a working app is worse than noticing a second late.
    private let probeTimeout: TimeInterval = 3

    public init() {}

    /// Starts listening. Throws if the listener cannot be created; a port
    /// conflict surfaces asynchronously via `lastError` and is retried.
    /// The default honors `PRISMKIT_PORT`, like the client side.
    public func start(port: UInt16 = MeasureStreamDefaults.resolvedPort) throws {
        self.port = port
        isStopped = false
        let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                DispatchQueue.main.async { self.lastError = nil }
            case .failed(let error):
                DispatchQueue.main.async {
                    self.lastError = "Listener failed: \(error.localizedDescription)"
                }
                self.queue.asyncAfter(deadline: .now() + 2) { [weak self] in
                    guard let self, !self.isStopped else { return }
                    self.listener?.cancel()
                    self.listener = nil
                    try? self.start(port: self.port)
                }
            default:
                break
            }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    public func stop() {
        isStopped = true
        listener?.cancel()
        listener = nil
        queue.async { self.stopProbing() }
    }

    private func accept(_ connection: NWConnection) {
        connectionCount += 1
        activeConnection = connection
        updateReceiving()
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    /// Pushes live size overrides back to the connected app; each message
    /// replaces the app's active override set.
    public func send(_ message: OverrideMessage) {
        queue.async {
            guard let connection = self.activeConnection,
                  var data = try? JSONEncoder().encode(message) else { return }
            data.append(0x0A)
            connection.send(content: data, completion: .contentProcessed { _ in })
        }
    }

    /// Pushes new values for tweaks the app offered. Only the names included
    /// change; the rest are left alone.
    public func send(_ message: TweakMessage) {
        queue.async {
            guard let connection = self.activeConnection,
                  var data = try? JSONEncoder().encode(message) else { return }
            data.append(0x0A)
            connection.send(content: data, completion: .contentProcessed { _ in })
        }
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }

            // Snapshots arrive as newline-delimited JSON.
            while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let line = buffer[buffer.startIndex..<newlineIndex]
                buffer.removeSubrange(buffer.startIndex...newlineIndex)

                // A pong is a few dozen bytes; a snapshot is tens of
                // kilobytes. Checking the length first keeps this from
                // parsing every snapshot twice just to find out it is not a
                // pong.
                if line.count < 64,
                   let pong = try? self.decoder.decode(PongMessage.self, from: Data(line)) {
                    self.received(pong)
                    continue
                }

                // Frames are the largest thing on this socket and arrive only
                // when asked for, so trying them before snapshots costs a
                // failed parse per snapshot — but only while one is
                // outstanding, which is a fraction of the time.
                if self.pendingFrameRequest != nil,
                   let message = try? self.decoder.decode(ScreenFrameMessage.self, from: Data(line)) {
                    self.received(message)
                    continue
                }
                if self.pendingComponentRequest != nil,
                   let message = try? self.decoder.decode(ComponentRenderMessage.self, from: Data(line)) {
                    self.received(message)
                    continue
                }

                // Pausing freezes what is drawn. It is not a reason to stop
                // knowing whether the app is alive — the answer matters most
                // precisely when the picture has stopped moving.
                guard !self.pausedFlag else { continue }
                if let snapshot = try? self.decoder.decode(MeasurementSnapshot.self, from: Data(line)) {
                    DispatchQueue.main.async { self.snapshot = snapshot }
                }
            }

            if isComplete || error != nil {
                connection.cancel()
                self.connectionCount -= 1
                if self.activeConnection === connection {
                    self.activeConnection = nil
                }
                self.updateReceiving()
            } else {
                self.receive(on: connection, buffer: buffer)
            }
        }
    }

    private func updateReceiving() {
        let receiving = connectionCount > 0
        DispatchQueue.main.async { self.isReceiving = receiving }
        if receiving {
            startProbing()
        } else {
            stopProbing()
        }
    }

    // MARK: - Liveness

    /// Asks the connected app, every couple of seconds, whether its main
    /// thread is still running — and reports the answer as
    /// `isAppResponsive`. See `PingMessage` for why this is not the same
    /// question as whether the socket is open.
    private func startProbing() {
        guard probeTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        // Immediately, not one interval from now: a healthy app that just
        // connected would otherwise read as unresponsive for two seconds, and
        // a warning that is wrong on every launch is a warning people learn to
        // ignore. Over loopback the answer comes back in about a millisecond.
        timer.schedule(deadline: .now(), repeating: probeInterval)
        timer.setEventHandler { [weak self] in self?.probe() }
        timer.resume()
        probeTimer = timer
    }

    private func stopProbing() {
        probeTimer?.cancel()
        probeTimer = nil
        pendingProbe = nil
        pendingFrameRequest = nil
        pendingComponentRequest = nil
        DispatchQueue.main.async {
            self.isAppResponsive = false
            self.lastProbeRoundTrip = nil
            // The pictures belonged to the app that just left. Keeping them
            // would draw one app's components over the next one's screen.
            self.componentRenders = [:]
            self.refusedComponentRenders = []
        }
    }

    private func probe() {
        guard let connection = activeConnection else { return }

        if let pending = pendingProbe {
            // Still within the timeout: give it longer rather than piling up
            // probes.
            guard Date().timeIntervalSince(pending.sentAt) > probeTimeout else { return }

            // Timed out — the app is not running its main thread. Report it,
            // then abandon this probe and ask again below. Waiting on the
            // original answer forever looks tempting (it would measure how
            // long the stall lasted) but an app that recovers without ever
            // answering that particular probe would then read as stalled for
            // the rest of the session. Verified: it did.
            DispatchQueue.main.async { self.isAppResponsive = false }
            pendingProbe = nil
        }

        probeCount += 1
        let id = "p\(probeCount)"
        pendingProbe = (id: id, sentAt: Date())
        guard var data = try? JSONEncoder().encode(PingMessage(ping: id)) else { return }
        data.append(0x0A)
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    // MARK: - Frames

    /// Asks the connected app to render its screen.
    ///
    /// Silently does nothing while a previous request is still outstanding, or
    /// while nothing is connected. Callers are expected to drive this from
    /// whatever already decides that a fresh picture is wanted — the same
    /// judgement that used to decide when to shell out to `simctl`.
    public func requestFrame() {
        queue.async {
            guard let connection = self.activeConnection else { return }
            if let pending = self.pendingFrameRequest {
                guard Date().timeIntervalSince(pending.sentAt) > self.frameTimeout else { return }
            }
            self.frameRequestCount += 1
            let id = "f\(self.frameRequestCount)"
            self.pendingFrameRequest = (id: id, sentAt: Date())
            guard var data = try? JSONEncoder().encode(FrameRequestMessage(requestFrame: id)) else {
                self.pendingFrameRequest = nil
                return
            }
            data.append(0x0A)
            connection.send(content: data, completion: .contentProcessed { _ in })
        }
    }

    private func received(_ message: ScreenFrameMessage) {
        guard pendingFrameRequest?.id == message.id else { return }
        pendingFrameRequest = nil
        let frame = message.frame
        DispatchQueue.main.async { self.screenFrame = frame }
    }

    /// Asks the app to draw the named components on their own.
    ///
    /// Pass the ids you are about to show — a selection, or one level of the
    /// tree — not everything on screen. Each one is a separate off-screen
    /// render on the app's main thread.
    public func requestComponentRenders(ids: [String]) {
        guard !ids.isEmpty else { return }
        queue.async {
            guard let connection = self.activeConnection else { return }
            if let pending = self.pendingComponentRequest {
                guard Date().timeIntervalSince(pending.sentAt) > self.frameTimeout else { return }
            }
            self.componentRequestCount += 1
            let id = "c\(self.componentRequestCount)"
            self.pendingComponentRequest = (id: id, sentAt: Date())
            let message = ComponentRenderRequestMessage(requestComponents: id, ids: ids)
            guard var data = try? JSONEncoder().encode(message) else {
                self.pendingComponentRequest = nil
                return
            }
            data.append(0x0A)
            connection.send(content: data, completion: .contentProcessed { _ in })
        }
    }

    private func received(_ message: ComponentRenderMessage) {
        guard pendingComponentRequest?.id == message.id else { return }
        pendingComponentRequest = nil
        let renders = message.components
        let refused = message.refused
        DispatchQueue.main.async {
            // Merged rather than replaced: a request names a few components,
            // and dropping the rest would throw away pictures that are still
            // good and cost the app real work to produce.
            for render in renders {
                self.componentRenders[render.id] = render
            }
            self.refusedComponentRenders.formUnion(refused)
        }
    }

    private func received(_ pong: PongMessage) {
        // Only the probe currently outstanding counts. A reply to one that was
        // already given up on says the app is alive *now*, but it would also
        // report a round trip measured against the wrong clock.
        guard let pending = pendingProbe, pending.id == pong.pong else { return }
        pendingProbe = nil
        let roundTrip = Date().timeIntervalSince(pending.sentAt)
        DispatchQueue.main.async {
            self.isAppResponsive = true
            self.lastProbeRoundTrip = roundTrip
        }
    }
}

#endif
