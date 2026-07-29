import CoreGraphics

/// A cluster of measurements sharing the same edge position.
public struct AlignedEdgeGroup: Codable, Equatable, Sendable {
    /// "leading", "trailing", "top", "bottom", "centerX", or "centerY".
    public let edge: String
    public let position: CGFloat
    public let measurementIDs: [String]

    public init(edge: String, position: CGFloat, measurementIDs: [String]) {
        self.edge = edge
        self.position = position
        self.measurementIDs = measurementIDs
    }
}

/// A pixel-perfect problem worth surfacing to a reviewer or an AI agent.
public struct AlignmentIssue: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// Two edges almost align (within tolerance) but not exactly.
        case nearMissAlignment
        /// A container/content padding edge is not a spacing token.
        case invalidPadding
        /// The gap between two side-by-side or stacked elements is not a token.
        case invalidSpacing
    }

    public let kind: Kind
    public let message: String
    public let measurementIDs: [String]
    /// The offending value in points.
    public let value: CGFloat
    /// The suggested value (nearest token, or the position to align to).
    public let suggestion: CGFloat?

    public init(
        kind: Kind,
        message: String,
        measurementIDs: [String],
        value: CGFloat,
        suggestion: CGFloat?
    ) {
        self.kind = kind
        self.message = message
        self.measurementIDs = measurementIDs
        self.value = value
        self.suggestion = suggestion
    }
}

/// The result of analyzing a set of measurements for alignment and
/// design-token compliance.
public struct AlignmentReport: Codable, Equatable, Sendable {
    public let alignedEdges: [AlignedEdgeGroup]
    public let issues: [AlignmentIssue]

    public init(alignedEdges: [AlignedEdgeGroup], issues: [AlignmentIssue]) {
        self.alignedEdges = alignedEdges
        self.issues = issues
    }
}

/// Pure analysis of measurement geometry: which edges line up, which almost
/// line up, and which paddings/gaps violate the spacing tokens.
public enum AlignmentChecker {
    public static func report(
        measurements: [ResolvedMeasurement],
        configuration: MeasureConfiguration = .default,
        tolerance: CGFloat = 2
    ) -> AlignmentReport {
        var aligned: [AlignedEdgeGroup] = []
        var issues: [AlignmentIssue] = []

        let edgeReaders: [(name: String, value: (CGRect) -> CGFloat)] = [
            ("leading", { $0.minX }),
            ("trailing", { $0.maxX }),
            ("top", { $0.minY }),
            ("bottom", { $0.maxY }),
            ("centerX", { $0.midX }),
            ("centerY", { $0.midY }),
        ]

        for (edge, read) in edgeReaders {
            var buckets: [CGFloat: [String]] = [:]
            for measurement in measurements {
                buckets[read(measurement.frame).rounded(), default: []].append(measurement.id)
            }

            for (position, ids) in buckets where ids.count >= 2 {
                aligned.append(AlignedEdgeGroup(edge: edge, position: position, measurementIDs: ids.sorted()))
            }

            // Near misses: adjacent bucket positions closer than the tolerance.
            let positions = buckets.keys.sorted()
            for (a, b) in zip(positions, positions.dropFirst()) {
                let delta = b - a
                if delta > 0, delta <= tolerance {
                    let ids = (buckets[a] ?? []) + (buckets[b] ?? [])
                    issues.append(
                        AlignmentIssue(
                            kind: .nearMissAlignment,
                            message: "\(edge) edges differ by \(Int(delta)) pt — likely meant to align",
                            measurementIDs: ids.sorted(),
                            value: delta,
                            suggestion: a
                        )
                    )
                }
            }
        }

        aligned.sort { ($0.edge, $0.position) < ($1.edge, $1.position) }

        if configuration.validatesTokens {
            issues.append(contentsOf: paddingIssues(measurements, configuration: configuration))
            issues.append(contentsOf: spacingIssues(measurements, configuration: configuration))
        }

        return AlignmentReport(alignedEdges: aligned, issues: issues)
    }

    private static func paddingIssues(
        _ measurements: [ResolvedMeasurement],
        configuration: MeasureConfiguration
    ) -> [AlignmentIssue] {
        var issues: [AlignmentIssue] = []
        for group in MeasurementGroup.groups(from: measurements) {
            guard let padding = group.contentPadding?.rounded() else { continue }
            let edges: [(String, CGFloat)] = [
                ("top", padding.top),
                ("leading", padding.leading),
                ("bottom", padding.bottom),
                ("trailing", padding.trailing),
            ]
            for (edge, value) in edges {
                let validation = SpacingTokenValidator.validate(value, tokens: configuration.spacingTokens)
                if !validation.isValid, let nearest = validation.nearestToken {
                    issues.append(
                        AlignmentIssue(
                            kind: .invalidPadding,
                            message: "\(group.name) \(edge) padding is \(Int(value)) pt; nearest token is \(Int(nearest))",
                            measurementIDs: group.measurements.map(\.id).sorted(),
                            value: value,
                            suggestion: nearest
                        )
                    )
                }
            }
        }
        return issues
    }

    /// Validates gaps between pairs of containers that are side by side
    /// (overlapping vertically) or stacked (overlapping horizontally).
    private static func spacingIssues(
        _ measurements: [ResolvedMeasurement],
        configuration: MeasureConfiguration
    ) -> [AlignmentIssue] {
        var issues: [AlignmentIssue] = []
        let containers = measurements.filter { $0.role == .container }
        for (index, first) in containers.enumerated() {
            for second in containers.dropFirst(index + 1) {
                let spacing = ExternalSpacing.between(first.frame, second.frame).rounded()
                let neighbors = (spacing.horizontal > 0) != (spacing.vertical > 0)
                guard neighbors else { continue }
                let gap = max(spacing.horizontal, spacing.vertical)
                let axis = spacing.horizontal > 0 ? "horizontal" : "vertical"
                let validation = SpacingTokenValidator.validate(gap, tokens: configuration.spacingTokens)
                if !validation.isValid, let nearest = validation.nearestToken {
                    issues.append(
                        AlignmentIssue(
                            kind: .invalidSpacing,
                            message: "\(axis) gap between \(first.group) and \(second.group) is \(Int(gap)) pt; nearest token is \(Int(nearest))",
                            measurementIDs: [first.id, second.id].sorted(),
                            value: gap,
                            suggestion: nearest
                        )
                    )
                }
            }
        }
        return issues
    }
}
