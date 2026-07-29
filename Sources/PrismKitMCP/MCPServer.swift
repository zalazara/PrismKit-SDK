import Foundation
import PrismKit

/// A minimal Model Context Protocol server over stdio (newline-delimited
/// JSON-RPC 2.0). It embeds a `MeasurementStreamServer`, so while it runs, an
/// AI agent can launch an instrumented app in the simulator and query live
/// layout measurements to verify pixel-perfect screens.
///
/// Note: it binds the same port the companion app uses — run one at a time,
/// or use `PRISMKIT_PORT` (and `SIMCTL_CHILD_PRISMKIT_PORT` when
/// launching the app) to run them side by side on different ports.
final class MCPServer {
    private let stream = MeasurementStreamServer()
    private let stdout = FileHandle.standardOutput
    private let stdoutLock = NSLock()
    private var listenFailure: String?

    func run() {
        let port = MeasureStreamDefaults.resolvedPort
        do {
            try stream.start(port: port)
        } catch {
            listenFailure = "Could not listen on port \(port): \(error.localizedDescription)"
        }

        // Read stdin off the main thread; the main run loop services the
        // stream server's published state.
        Thread.detachNewThread { [weak self] in
            self?.readLoop()
        }
        RunLoop.main.run()
    }

    private func readLoop() {
        while let line = readLine(strippingNewline: true) {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            handle(message)
        }
        exit(0)
    }

    private func handle(_ message: [String: Any]) {
        let method = message["method"] as? String ?? ""
        let id = message["id"]
        let params = message["params"] as? [String: Any] ?? [:]

        // Notifications (no id) need no response.
        guard id != nil else { return }

        switch method {
        case "initialize":
            let requested = params["protocolVersion"] as? String ?? "2024-11-05"
            respond(id: id, result: [
                "protocolVersion": requested,
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": ["name": "prismkit", "version": "0.1.0"],
            ])
        case "ping":
            respond(id: id, result: [String: Any]())
        case "tools/list":
            respond(id: id, result: ["tools": MCPTools.definitions])
        case "tools/call":
            let name = params["name"] as? String ?? ""
            let arguments = params["arguments"] as? [String: Any] ?? [:]
            let result = MCPTools.call(
                name: name,
                arguments: arguments,
                snapshot: currentSnapshot(),
                listenFailure: listenFailure
            )
            respond(id: id, result: result)
        default:
            respondError(id: id, code: -32601, message: "Method not found: \(method)")
        }
    }

    private func currentSnapshot() -> MeasurementSnapshot? {
        // `snapshot` is published on the main thread; hop over to read it.
        if Thread.isMainThread { return stream.snapshot }
        var value: MeasurementSnapshot?
        DispatchQueue.main.sync { value = self.stream.snapshot }
        return value
    }

    // MARK: - JSON-RPC output

    private func respond(id: Any?, result: [String: Any]) {
        write(["jsonrpc": "2.0", "id": id ?? NSNull(), "result": result])
    }

    private func respondError(id: Any?, code: Int, message: String) {
        write(["jsonrpc": "2.0", "id": id ?? NSNull(), "error": ["code": code, "message": message]])
    }

    private func write(_ payload: [String: Any]) {
        guard var data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        data.append(0x0A)
        stdoutLock.lock()
        stdout.write(data)
        stdoutLock.unlock()
    }
}
