import Combine
import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if DEBUG
import Network
#endif

/// Observable companion-connection state, driving the in-app toolbar's
/// `.automatic` visibility: the toolbar shows on device (no companion) and
/// steps aside while a companion is receiving.
///
/// In release builds nothing ever connects, so this stays `false`.
public final class StreamClientState: ObservableObject {
    @Published public fileprivate(set) var isCompanionConnected = false
}

// Everything below opens a socket and transmits what is on screen, so it is
// debug-only: release builds carry no networking code at all.
#if DEBUG

/// Streams measurement snapshots to a PrismKit companion listening on the
/// host's loopback interface (the iOS Simulator shares it with the Mac).
///
/// Fire-and-forget by design: if no companion is listening, sends are dropped
/// silently and reconnection attempts are rate-limited, so leaving streaming
/// enabled costs nothing during normal development. The latest snapshot is
/// retried periodically, so a companion started after the app still receives
/// the current state without requiring a layout change.
final class MeasurementStreamClient {
    static let shared = MeasurementStreamClient()

    /// Shared observable state for SwiftUI (see `StreamClientState`).
    static let state = StreamClientState()

    private let queue = DispatchQueue(label: "PrismKit.StreamClient")
    private let encoder = JSONEncoder()
    private var connection: NWConnection?
    #if !targetEnvironment(simulator)
    /// Only on a device, where this side is the one being reached.
    private var listener: NWListener?
    #endif
    private var isConnectionReady = false
    private var isSuspended = false
    private var lastConnectionAttempt = Date.distantPast
    private var lastSend = Date.distantPast
    private var latest: MeasurementSnapshot?
    private var flushScheduled = false
    private var retryTimer: DispatchSourceTimer?

    /// Minimum interval between sends; intermediate snapshots are coalesced.
    private let throttleInterval: TimeInterval = 0.1
    /// Minimum interval between reconnection attempts.
    private let reconnectCooldown: TimeInterval = 3

    func send(_ snapshot: MeasurementSnapshot) {
        queue.async { self.enqueue(snapshot) }
    }

    /// Tears the connection down and stops retrying, e.g. when the app moves
    /// to the background — a closed or hidden app must not keep transmitting.
    /// The latest snapshot is kept for `resume()`.
    func suspend() {
        queue.async {
            self.isSuspended = true
            self.retryTimer?.cancel()
            self.retryTimer = nil
            #if !targetEnvironment(simulator)
            // A backgrounded app must stop being reachable too, not merely
            // stop talking: leaving the port open would let a companion attach
            // to an app that has been told to stop transmitting.
            self.listener?.cancel()
            self.listener = nil
            #endif
            self.resetConnection()
        }
    }

    /// Reconnects (rate limits reset) and re-delivers the latest snapshot.
    func resume() {
        queue.async {
            guard self.isSuspended else { return }
            self.isSuspended = false
            self.lastConnectionAttempt = .distantPast
            self.startRetryTimerIfNeeded()
            self.flushLatest()
        }
    }

    private func enqueue(_ snapshot: MeasurementSnapshot) {
        latest = snapshot
        guard !isSuspended else { return }
        startRetryTimerIfNeeded()
        let elapsed = Date().timeIntervalSince(lastSend)
        if elapsed >= throttleInterval {
            flushLatest()
        } else if !flushScheduled {
            flushScheduled = true
            queue.asyncAfter(deadline: .now() + throttleInterval) {
                self.flushScheduled = false
                self.flushLatest()
            }
        }
    }

    private func flushLatest() {
        guard let snapshot = latest, !isSuspended else { return }
        lastSend = Date()

        if connection == nil {
            guard Date().timeIntervalSince(lastConnectionAttempt) >= reconnectCooldown else { return }
            lastConnectionAttempt = Date()
            #if targetEnvironment(simulator)
            openConnection()
            #else
            // On a device there is nothing to connect *to*: 127.0.0.1 is the
            // phone. The Mac reaches in over the cable instead, so this side
            // waits to be reached. Starting the listener is idempotent and
            // cheap; the guard above keeps it from being attempted in a tight
            // loop while nobody is plugged in.
            startListener()
            #endif
            return
        }
        guard let connection, var data = try? encoder.encode(snapshot) else { return }
        data.append(0x0A)
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if error != nil { self?.resetConnection() }
        })
    }

    /// Retries delivery of the latest snapshot while disconnected, so a
    /// companion launched later still receives the current state.
    private func startRetryTimerIfNeeded() {
        guard retryTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + reconnectCooldown, repeating: reconnectCooldown)
        timer.setEventHandler { [weak self] in
            guard let self, !self.isConnectionReady else { return }
            self.flushLatest()
        }
        timer.resume()
        retryTimer = timer
    }

    /// Receives override messages and liveness probes pushed back by the
    /// companion.
    private func receiveLoop(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }
            while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let line = buffer[buffer.startIndex..<newlineIndex]
                buffer.removeSubrange(buffer.startIndex...newlineIndex)
                if let message = try? JSONDecoder().decode(OverrideMessage.self, from: Data(line)) {
                    DispatchQueue.main.async {
                        MeasurementOverrideStore.shared.apply(message)
                    }
                } else if let ping = try? JSONDecoder().decode(PingMessage.self, from: Data(line)) {
                    self.answer(ping)
                } else if let request = try? JSONDecoder().decode(FrameRequestMessage.self, from: Data(line)) {
                    self.renderFrame(for: request)
                } else if let request = try? JSONDecoder().decode(ComponentRenderRequestMessage.self, from: Data(line)) {
                    self.renderComponents(for: request)
                } else if let message = try? JSONDecoder().decode(TweakMessage.self, from: Data(line)) {
                    Task { @MainActor in TweakRegistry.shared.apply(message) }
                }
            }
            if isComplete || error != nil {
                self.queue.async { self.resetConnection() }
            } else {
                self.receiveLoop(on: connection, buffer: buffer)
            }
        }
    }

    /// Replies to a probe — from the main queue, deliberately.
    ///
    /// Hopping to main before writing is the entire mechanism: while the app
    /// is stopped at a breakpoint or its main thread is blocked, this block
    /// never runs, no reply is written, and the companion learns the thing it
    /// actually wanted to know. Answering from the network queue would always
    /// succeed and would therefore mean nothing.
    private func answer(_ ping: PingMessage) {
        DispatchQueue.main.async {
            self.queue.async {
                guard let connection = self.connection, self.isConnectionReady else { return }
                guard var data = try? self.encoder.encode(PongMessage(pong: ping.ping)) else { return }
                data.append(0x0A)
                connection.send(content: data, completion: .contentProcessed { _ in })
            }
        }
    }

    /// Renders the screen the companion asked for and sends it back.
    ///
    /// The render has to happen on the main thread; the encode and the write
    /// do not, and a PNG of a 3x screen is slow enough that doing it on the
    /// main thread would show up as a stutter in the app being measured. So
    /// only the capture runs there.
    private func renderFrame(for request: FrameRequestMessage) {
        #if canImport(UIKit)
        DispatchQueue.main.async {
            guard let capture = ScreenRenderer.capture() else { return }
            self.queue.async {
                guard let frame = ScreenRenderer.encode(capture) else { return }
                guard let connection = self.connection, self.isConnectionReady else { return }
                let message = ScreenFrameMessage(id: request.requestFrame, frame: frame)
                guard var data = try? self.encoder.encode(message) else { return }
                data.append(0x0A)
                connection.send(content: data, completion: .contentProcessed { _ in })
            }
        }
        #endif
    }

    /// Draws the named components on their own and sends them back.
    ///
    /// Sizes come from the snapshot this client last sent, so the pictures
    /// match the frames the companion is already drawing overlays on. Asking
    /// the companion to supply them instead would let the two disagree about
    /// what a component's size is, which is the one thing this whole tool is
    /// supposed to settle.
    private func renderComponents(for request: ComponentRenderRequestMessage) {
        #if canImport(UIKit)
        // Read on the queue this is already running on. Hopping to main and
        // reaching back with `sync` would be a deadlock waiting for the one
        // day something on this queue waits for main.
        guard let snapshot = latest else { return }
        // `Task { @MainActor in }` rather than `DispatchQueue.main.async`
        // because the renderer is main-actor isolated and this gives the
        // compiler that statically, on every OS this package supports.
        Task { @MainActor in
            var sizes: [String: CGSize] = [:]
            for measurement in snapshot.measurements {
                sizes[measurement.id] = measurement.frame.size
            }
            let scale = UIScreen.main.scale
            let result = SoloRenderRegistry.render(ids: request.ids, sizes: sizes, scale: scale)
            self.queue.async {
                guard let connection = self.connection, self.isConnectionReady else { return }
                let message = ComponentRenderMessage(
                    id: request.requestComponents,
                    components: result.rendered,
                    refused: result.refused
                )
                guard var data = try? self.encoder.encode(message) else { return }
                data.append(0x0A)
                connection.send(content: data, completion: .contentProcessed { _ in })
            }
        }
        #endif
    }

    #if !targetEnvironment(simulator)
    /// Waits for the Mac to reach in over the cable.
    ///
    /// usbmuxd — the daemon that has been forwarding ports to attached devices
    /// since long before this tool — makes a listener on the phone reachable
    /// from the Mac. That is the whole reason the direction flips here: over
    /// USB the Mac is the one that can start a conversation, and on Wi-Fi the
    /// phone has no idea which Mac to call.
    ///
    /// One connection at a time. A second companion attaching would otherwise
    /// silently take over the first one's stream.
    private func startListener() {
        guard listener == nil else { return }
        guard let port = NWEndpoint.Port(rawValue: MeasureStreamDefaults.resolvedPort) else { return }
        guard let listener = try? NWListener(using: .tcp, on: port) else { return }

        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            self.queue.async {
                // Drop the previous one rather than serving both: two
                // companions on one app is not a case worth reasoning about.
                self.connection?.cancel()
                self.connection = connection
                self.isConnectionReady = true
                connection.start(queue: self.queue)
                self.receiveLoop(on: connection, buffer: Data())
                self.flushLatest()
                DispatchQueue.main.async {
                    MeasurementStreamClient.state.isCompanionConnected = true
                }
            }
        }
        listener.stateUpdateHandler = { [weak self] state in
            guard case .failed = state, let self else { return }
            self.queue.async {
                self.listener?.cancel()
                self.listener = nil
            }
        }
        listener.start(queue: queue)
        self.listener = listener
    }
    #endif

    private func openConnection() {
        let connection = NWConnection(
            host: "127.0.0.1",
            port: NWEndpoint.Port(rawValue: MeasureStreamDefaults.resolvedPort)!,
            using: .tcp
        )
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.queue.async {
                    self.isConnectionReady = true
                    // Deliver current state to the freshly connected companion.
                    self.flushLatest()
                }
                DispatchQueue.main.async {
                    MeasurementStreamClient.state.isCompanionConnected = true
                }
            case .waiting, .failed, .cancelled:
                // .waiting means the connect attempt was refused (no companion
                // listening yet). Tear down so the retry timer starts fresh
                // instead of queueing sends on a dead connection.
                self.queue.async { self.resetConnection() }
            default:
                break
            }
        }
        connection.start(queue: queue)
        self.connection = connection
        receiveLoop(on: connection, buffer: Data())
    }

    private func resetConnection() {
        connection?.cancel()
        connection = nil
        isConnectionReady = false
        DispatchQueue.main.async {
            MeasurementStreamClient.state.isCompanionConnected = false
        }
    }
}

#endif
