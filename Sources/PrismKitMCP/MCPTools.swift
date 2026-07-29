import CoreGraphics
import Foundation
import PrismKit

/// The MCP tool surface: live measurements, distances, alignment analysis,
/// simulator listing, and screenshots — everything an agent needs to verify
/// a screen is pixel perfect.
enum MCPTools {
    static let definitions: [[String: Any]] = [
        [
            "name": "get_measurements",
            "description": "Latest layout measurements streamed from the app running in the simulator: instrumented elements (id, group, semantic role, frame in points, frame in screen coordinates, per-component internal padding with spacing-token validation) plus automaticElements derived from the accessibility tree with zero instrumentation (frames and what VoiceOver reads). Requires the app to have an active measureScope.",
            "inputSchema": ["type": "object", "properties": [String: Any]()],
        ],
        [
            "name": "measure_distance",
            "description": "Distances between two measured elements by id (ids come from get_measurements, e.g. 'primaryButton#container'): per-axis gaps (zero when overlapping) and the deltas between their leading/trailing/top/bottom edges and centers.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "first_id": ["type": "string", "description": "First measurement id"],
                    "second_id": ["type": "string", "description": "Second measurement id"],
                ],
                "required": ["first_id", "second_id"],
            ],
        ],
        [
            "name": "check_alignment",
            "description": "Pixel-perfect audit of the current screen: which edges align exactly, near-miss alignments within a tolerance, paddings that are not design-system spacing tokens, and off-token gaps between neighboring components.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "tolerance": ["type": "number", "description": "Near-miss tolerance in points (default 2)"],
                ],
            ],
        ],
        [
            "name": "compare_to_design",
            "description": """
                Checks the screen currently running in the simulator against a design and returns the \
                differences as numbers: position, size and wording per element, plus anything the design \
                specifies that is not on screen.

                PrismKit does not talk to Figma, Pencil or any other tool — you do. Read the node with \
                whichever design MCP you have connected, then translate it into the `design` argument. \
                That is why any design source works without PrismKit knowing about it.

                Two things decide whether the result is trustworthy. First, set `match` on every node you \
                can: it pairs the node with a `.measure()` group or an accessibilityIdentifier instead of \
                guessing. Without it the tool falls back to identical text, then to geometric overlap, and \
                marks those findings as warnings with `matchedBy` so you can tell them apart. Second, node \
                frames must be relative to the design frame's top-left, in design points — the tool scales \
                them onto the device by width and reports the factor it used.

                A partial design is fine and expected: describe the components that matter. Elements on \
                screen that no node claims are listed separately, not reported as defects.
                """,
            "inputSchema": [
                "type": "object",
                "properties": [
                    "design": [
                        "type": "object",
                        "description": "The design to check against.",
                        "properties": [
                            "source": ["type": "string", "description": "Where it came from: 'figma', 'pencil', … Free-form, carried into the report."],
                            "reference": ["type": "string", "description": "Node URL or id, so a finding can be traced back to the original."],
                            "frame": [
                                "type": "object",
                                "description": "The design frame's own size in design points. Its width sets the scale onto the device.",
                                "properties": [
                                    "width": ["type": "number"],
                                    "height": ["type": "number"],
                                ],
                                "required": ["width", "height"],
                            ],
                            "nodes": [
                                "type": "array",
                                "description": "The elements to check. Only id and frame are required per node.",
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "id": ["type": "string", "description": "Stable id in the source document."],
                                        "name": ["type": "string", "description": "Readable name; also used for pairing when it matches a .measure() group or an accessibilityIdentifier."],
                                        "match": ["type": "string", "description": "Explicit pairing: the measurement id, .measure() group, or accessibilityIdentifier this node is. Set it whenever you can."],
                                        "frame": [
                                            "type": "object",
                                            "description": "Relative to the design frame's top-left, in design points.",
                                            "properties": [
                                                "x": ["type": "number"],
                                                "y": ["type": "number"],
                                                "width": ["type": "number"],
                                                "height": ["type": "number"],
                                            ],
                                            "required": ["x", "y", "width", "height"],
                                        ],
                                        "text": ["type": "string", "description": "The copy this node renders, if any."],
                                    ],
                                    "required": ["id", "frame"],
                                ],
                            ],
                        ],
                        "required": ["frame", "nodes"],
                    ],
                    "tolerance": ["type": "number", "description": "Differences at or below this many points are not reported (default 1). Scaling introduces sub-point error, so 0 reports noise."],
                    "compare_text": ["type": "boolean", "description": "Whether wording is compared (default true). Turn it off against real data, where the design says '$0.00' and the app correctly says '$1,234.56'."],
                    "minimum_overlap": ["type": "number", "description": "How much two frames must overlap (0–1) for the geometric fallback to pair them (default 0.5). Below it the node is reported missing, naming the closest rejected element."],
                ],
                "required": ["design"],
            ],
        ],
        [
            "name": "list_simulators",
            "description": "Lists booted iOS simulators (name, UDID, runtime) available for launching and screenshotting.",
            "inputSchema": ["type": "object", "properties": [String: Any]()],
        ],
        [
            "name": "capture_screenshot",
            "description": "Captures a PNG screenshot of a booted simulator's screen.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "udid": ["type": "string", "description": "Simulator UDID; defaults to the booted device"],
                ],
            ],
        ],
    ]

    static func call(
        name: String,
        arguments: [String: Any],
        snapshot: MeasurementSnapshot?,
        listenFailure: String?
    ) -> [String: Any] {
        switch name {
        case "get_measurements":
            guard let snapshot else { return noSnapshot(listenFailure) }
            return text(json(measurementsPayload(snapshot)))
        case "measure_distance":
            guard let snapshot else { return noSnapshot(listenFailure) }
            let elements = snapshot.allMeasurements
            guard let firstID = arguments["first_id"] as? String,
                  let secondID = arguments["second_id"] as? String,
                  let first = elements.first(where: { $0.id == firstID }),
                  let second = elements.first(where: { $0.id == secondID }) else {
                return error("Unknown measurement id. Call get_measurements for valid ids.")
            }
            return text(json(distancePayload(first, second)))
        case "check_alignment":
            guard let snapshot else { return noSnapshot(listenFailure) }
            let tolerance = (arguments["tolerance"] as? NSNumber)?.doubleValue ?? 2
            let report = AlignmentChecker.report(
                measurements: snapshot.measurements,
                tolerance: CGFloat(tolerance)
            )
            return text(encodable(report))
        case "compare_to_design":
            guard let snapshot else { return noSnapshot(listenFailure) }
            guard let raw = arguments["design"] else {
                return error("Missing \"design\". Pass the design as { \"frame\": {\"width\": …, \"height\": …}, \"nodes\": [{ \"id\": …, \"frame\": {\"x\": …, \"y\": …, \"width\": …, \"height\": …} }] }.")
            }
            let spec: DesignSpec
            do {
                let data = try JSONSerialization.data(withJSONObject: raw)
                spec = try JSONDecoder().decode(DesignSpec.self, from: data)
            } catch {
                return self.error("Could not read \"design\": \(error.localizedDescription). Node frames must be relative to the design frame's top-left, and each node needs an id and a frame.")
            }
            guard !spec.nodes.isEmpty else {
                return error("\"design\" has no nodes to check.")
            }
            var options = DesignComparisonOptions.default
            if let tolerance = (arguments["tolerance"] as? NSNumber)?.doubleValue {
                options.tolerance = CGFloat(tolerance)
            }
            if let comparesText = arguments["compare_text"] as? Bool {
                options.comparesText = comparesText
            }
            if let minimumOverlap = (arguments["minimum_overlap"] as? NSNumber)?.doubleValue {
                options.minimumOverlap = CGFloat(minimumOverlap)
            }
            return text(
                encodable(
                    DesignComparator.compare(design: spec, snapshot: snapshot, options: options)
                )
            )
        case "list_simulators":
            return text(listSimulators())
        case "capture_screenshot":
            return captureScreenshot(udid: arguments["udid"] as? String)
        default:
            return error("Unknown tool: \(name)")
        }
    }

    // MARK: - Payloads

    private static func measurementsPayload(_ snapshot: MeasurementSnapshot) -> [String: Any] {
        let groups = MeasurementGroup.groups(from: snapshot.measurements).map { group -> [String: Any] in
            var payload: [String: Any] = ["name": group.name]
            if let container = group.container {
                payload["containerSize"] = ["width": Int(container.frame.width.rounded()), "height": Int(container.frame.height.rounded())]
            }
            if let padding = group.contentPadding?.rounded() {
                payload["internalPadding"] = [
                    "top": paddingEdge(padding.top),
                    "leading": paddingEdge(padding.leading),
                    "bottom": paddingEdge(padding.bottom),
                    "trailing": paddingEdge(padding.trailing),
                ]
            }
            return payload
        }
        return [
            "appName": snapshot.appName,
            "bundleID": snapshot.bundleID,
            "screenSizePoints": ["width": snapshot.screenSize.width, "height": snapshot.screenSize.height],
            "measurements": snapshot.measurements.map { measurement in
                let global = snapshot.globalFrame(for: measurement)
                return [
                    "id": measurement.id,
                    "group": measurement.group,
                    "role": measurement.role.label,
                    "frame": rect(measurement.frame),
                    "screenFrame": rect(global),
                    "metadata": measurement.metadata,
                ] as [String: Any]
            },
            // Zero-instrumentation elements derived from the accessibility
            // tree — measurable by id like any instrumented element, and
            // carrying what VoiceOver would read.
            "automaticElements": snapshot.automaticMeasurements.map { measurement in
                let global = snapshot.globalFrame(for: measurement)
                return [
                    "id": measurement.id,
                    "frame": rect(measurement.frame),
                    "screenFrame": rect(global),
                    "metadata": measurement.metadata,
                ] as [String: Any]
            },
            "groups": groups,
        ]
    }

    private static func paddingEdge(_ value: CGFloat) -> [String: Any] {
        let validation = SpacingTokenValidator.validate(value, tokens: MeasureConfiguration.default.spacingTokens)
        var payload: [String: Any] = ["points": Int(value), "isToken": validation.isValid]
        if let nearest = validation.nearestToken, !validation.isValid {
            payload["nearestToken"] = Int(nearest)
        }
        return payload
    }

    private static func distancePayload(
        _ first: ResolvedMeasurement,
        _ second: ResolvedMeasurement
    ) -> [String: Any] {
        let spacing = ExternalSpacing.between(first.frame, second.frame).rounded()
        let a = first.frame
        let b = second.frame
        return [
            "first": first.id,
            "second": second.id,
            "gap": ["horizontal": spacing.horizontal, "vertical": spacing.vertical],
            "edgeDeltas": [
                "leading": b.minX - a.minX,
                "trailing": b.maxX - a.maxX,
                "top": b.minY - a.minY,
                "bottom": b.maxY - a.maxY,
                "centerX": b.midX - a.midX,
                "centerY": b.midY - a.midY,
            ],
        ]
    }

    private static func rect(_ value: CGRect) -> [String: Any] {
        ["x": value.minX, "y": value.minY, "width": value.width, "height": value.height]
    }

    // MARK: - simctl

    private static func listSimulators() -> String {
        let output = runSimctl(["list", "devices", "--json"])
        guard output.success, let data = output.stdout,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = root["devices"] as? [String: [[String: Any]]] else {
            return #"{"error": "simctl failed"}"#
        }
        let booted = devices.flatMap { runtime, list in
            list.compactMap { device -> [String: Any]? in
                guard device["state"] as? String == "Booted" else { return nil }
                return [
                    "name": device["name"] ?? "",
                    "udid": device["udid"] ?? "",
                    "runtime": runtime.components(separatedBy: "SimRuntime.").last ?? runtime,
                ]
            }
        }
        return json(["bootedSimulators": booted])
    }

    private static func captureScreenshot(udid: String?) -> [String: Any] {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("prismkit-mcp-screen.png")
        let output = runSimctl(["io", udid ?? "booted", "screenshot", "--type=png", url.path])
        guard output.success, let data = try? Data(contentsOf: url) else {
            return error("Screenshot failed — is a simulator booted?")
        }
        return [
            "content": [[
                "type": "image",
                "data": data.base64EncodedString(),
                "mimeType": "image/png",
            ]],
        ]
    }

    private static func runSimctl(_ arguments: [String]) -> (success: Bool, stdout: Data?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl"] + arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus == 0, data)
        } catch {
            return (false, nil)
        }
    }

    // MARK: - MCP result envelopes

    private static func noSnapshot(_ listenFailure: String?) -> [String: Any] {
        if let listenFailure {
            return error("\(listenFailure). Quit the companion app (it uses the same port) or set PRISMKIT_PORT to a free port and relaunch the app with SIMCTL_CHILD_PRISMKIT_PORT.")
        }
        return error("No measurements received yet. Launch an app instrumented with PrismKit (measureScope enabled, streaming on) in the simulator, then retry.")
    }

    private static func text(_ value: String) -> [String: Any] {
        ["content": [["type": "text", "text": value]]]
    }

    private static func error(_ message: String) -> [String: Any] {
        ["content": [["type": "text", "text": message]], "isError": true]
    }

    private static func json(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private static func encodable<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
