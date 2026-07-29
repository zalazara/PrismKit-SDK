import Combine
import Foundation
import Network

/// Observable companion-connection state, driving the in-app toolbar's
/// `.automatic` visibility: the toolbar shows on device (no companion) and
/// steps aside while a companion is receiving.
public final class StreamClientState: ObservableObject {
    @Published public fileprivate(set) var isCompanionConnected = false
}

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
            openConnection()
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

    /// Receives override messages pushed back by the companion.
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
                }
            }
            if isComplete || error != nil {
                self.queue.async { self.resetConnection() }
            } else {
                self.receiveLoop(on: connection, buffer: buffer)
            }
        }
    }

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
