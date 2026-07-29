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
            "name": "get_design_tokens",
            "description": """
                The spacing scale every judgement in this server uses — off-token paddings and gaps in \
                get_measurements and check_alignment are measured against it. Also reports where it came \
                from: a .prismkit.json in the project, this Mac's settings, or PrismKit's built-in scale. \
                Check this before trusting an off-token warning: the built-in scale is a guess at a design \
                system, not the team's.
                """,
            "inputSchema": ["type": "object", "properties": [String: Any]()],
        ],
        [
            "name": "set_design_tokens",
            "description": """
                Sets the spacing scale used to judge paddings and gaps.

                Pass `project_path` to write a `.prismkit.json` there: committed alongside the code, it \
                makes the whole team, this server, the Prism Inspector app, and CI judge spacing by the \
                same numbers. Without it the scale is saved for this Mac only.
                """,
            "inputSchema": [
                "type": "object",
                "properties": [
                    "spacing_tokens": [
                        "type": "array",
                        "items": ["type": "number"],
                        "description": "Valid spacing values in points, e.g. [4, 8, 12, 16, 24, 32].",
                    ],
                    "grid_size": ["type": "number", "description": "Alignment grid cell size in points (default 8)."],
                    "project_path": ["type": "string", "description": "Directory to write .prismkit.json into, so the scale is versioned with the code."],
                ],
                "required": ["spacing_tokens"],
            ],
        ],
        [
            "name": "attach_design",
            "description": """
                Keeps a design attached to the session, so `compare_to_design` can be called repeatedly \
                without resending it while you navigate and fix things.

                The attachment is also what the Prism Inspector app reads: attach here and the person at \
                the Mac sees the same design drawn over the live screen, with the differences marked. The \
                server and the app cannot run at once (both use port 9294), so this is how the two halves \
                of the workflow meet.

                Takes the same `design` shape as `compare_to_design`.
                """,
            "inputSchema": [
                "type": "object",
                "properties": [
                    "design": ["type": "object", "description": "The design to attach; same shape as compare_to_design's design argument."],
                ],
                "required": ["design"],
            ],
        ],
        [
            "name": "detach_design",
            "description": "Forgets the attached design. The companion stops drawing it too.",
            "inputSchema": ["type": "object", "properties": [String: Any]()],
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
            return text(json(measurementsPayload(snapshot, tokens: resolvedTokens().tokens)))
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
            let resolved = resolvedTokens()
            let report = AlignmentChecker.report(
                measurements: snapshot.measurements,
                configuration: resolved.tokens.applied(to: .default),
                tolerance: CGFloat(tolerance)
            )
            return text(encodable(report))
        case "get_design_tokens":
            let resolved = resolvedTokens()
            return text(
                json([
                    "spacingTokens": resolved.tokens.spacingTokens.map { Double($0) },
                    "gridSize": Double(resolved.tokens.gridSize),
                    "source": resolved.origin.describedForTooling,
                    "isTeamScale": resolved.origin != .builtIn,
                ])
            )
        case "set_design_tokens":
            guard let raw = arguments["spacing_tokens"] as? [Any] else {
                return error("Missing \"spacing_tokens\". Pass the scale in points, e.g. [4, 8, 12, 16, 24, 32].")
            }
            let values = raw.compactMap { ($0 as? NSNumber)?.doubleValue }.filter { $0 > 0 }
            guard !values.isEmpty else {
                return error("\"spacing_tokens\" has no positive numbers in it.")
            }
            var tokens = DesignTokens(spacingTokens: values.map { CGFloat($0) })
            if let gridSize = (arguments["grid_size"] as? NSNumber)?.doubleValue, gridSize > 0 {
                tokens.gridSize = CGFloat(gridSize)
            }
            var payload: [String: Any] = [
                "spacingTokens": tokens.spacingTokens.map { Double($0) },
                "gridSize": Double(tokens.gridSize),
            ]
            if let projectPath = arguments["project_path"] as? String, !projectPath.isEmpty {
                guard let url = DesignTokensStore.writeProjectFile(tokens, in: projectPath) else {
                    return error("Could not write \(DesignTokensStore.projectFileName) into \(projectPath).")
                }
                payload["writtenTo"] = url.path
                payload["note"] = "Commit this file so the team, the app and CI share the scale."
            } else {
                guard DesignTokensStore.saveForMachine(tokens) else {
                    return error("Could not save the tokens for this Mac.")
                }
                payload["writtenTo"] = DesignTokensStore.machineURL.path
                payload["note"] = "Saved for this Mac only. Pass project_path to version it with the code."
            }
            return text(json(payload))
        case "attach_design":
            guard let raw = arguments["design"] else {
                return error("Missing \"design\".")
            }
            do {
                let spec = try decodeSpec(raw)
                guard !spec.nodes.isEmpty else { return error("\"design\" has no nodes.") }
                let attachment = AttachedDesignStore.Attachment(
                    design: spec,
                    attachedAt: Date().timeIntervalSince1970
                )
                guard AttachedDesignStore.save(attachment) else {
                    return error("Could not write the attachment to \(AttachedDesignStore.url.path).")
                }
                return text(
                    json([
                        "attached": true,
                        "nodes": spec.nodes.count,
                        "source": spec.source ?? "",
                        "note": "Prism Inspector will draw this over the live screen when it is running.",
                    ])
                )
            } catch {
                return self.error(specError(error))
            }
        case "detach_design":
            AttachedDesignStore.clear()
            return text(json(["attached": false]))
        case "compare_to_design":
            guard let snapshot else { return noSnapshot(listenFailure) }
            let spec: DesignSpec
            if let raw = arguments["design"] {
                do {
                    spec = try decodeSpec(raw)
                } catch {
                    return self.error(specError(error))
                }
            } else if let attached = AttachedDesignStore.load()?.design {
                spec = attached
            } else {
                return error("No design given and none attached. Pass \"design\", or call attach_design first.")
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

    // MARK: - Design tokens

    /// The scale every judgement in this server uses. Resolved per call so a
    /// token file edited mid-session takes effect without a restart.
    private static func resolvedTokens() -> DesignTokensStore.Resolved {
        DesignTokensStore.resolve(projectDirectory: FileManager.default.currentDirectoryPath)
    }

    // MARK: - Design specs

    private static func decodeSpec(_ raw: Any) throws -> DesignSpec {
        let data = try JSONSerialization.data(withJSONObject: raw)
        return try JSONDecoder().decode(DesignSpec.self, from: data)
    }

    private static func specError(_ error: Error) -> String {
        "Could not read \"design\": \(error.localizedDescription). Each node needs an id and a frame, and node frames must be relative to the design frame's top-left."
    }

    // MARK: - Payloads

    private static func measurementsPayload(
        _ snapshot: MeasurementSnapshot,
        tokens: DesignTokens
    ) -> [String: Any] {
        let groups = MeasurementGroup.groups(from: snapshot.measurements).map { group -> [String: Any] in
            var payload: [String: Any] = ["name": group.name]
            if let container = group.container {
                payload["containerSize"] = ["width": Int(container.frame.width.rounded()), "height": Int(container.frame.height.rounded())]
            }
            if let padding = group.contentPadding?.rounded() {
                payload["internalPadding"] = [
                    "top": paddingEdge(padding.top, tokens: tokens),
                    "leading": paddingEdge(padding.leading, tokens: tokens),
                    "bottom": paddingEdge(padding.bottom, tokens: tokens),
                    "trailing": paddingEdge(padding.trailing, tokens: tokens),
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

    private static func paddingEdge(_ value: CGFloat, tokens: DesignTokens) -> [String: Any] {
        let validation = SpacingTokenValidator.validate(value, tokens: tokens.spacingTokens)
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
