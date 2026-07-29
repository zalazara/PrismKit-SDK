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

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }

            // Snapshots arrive as newline-delimited JSON.
            while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let line = buffer[buffer.startIndex..<newlineIndex]
                buffer.removeSubrange(buffer.startIndex...newlineIndex)
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
    }
}

#endif
