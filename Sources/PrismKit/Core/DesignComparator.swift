import CoreGraphics
import Foundation

/// How strict the comparison is, and what it looks at.
public struct DesignComparisonOptions: Equatable, Sendable {
    /// Differences at or below this many points are not reported. Scaling a
    /// design onto a slightly different device introduces sub-point error, so
    /// zero would report noise on a perfect screen.
    public var tolerance: CGFloat

    /// Minimum intersection-over-union for the geometric fallback to accept a
    /// pair. Below this the node is reported missing instead of being paired
    /// with something that merely happens to be nearby.
    public var minimumOverlap: CGFloat

    /// Whether wording is compared. Worth turning off against real data: a
    /// design says "$0.00" and the running app says "$1,234.56", which is
    /// correct behaviour reported as a defect.
    public var comparesText: Bool

    public init(
        tolerance: CGFloat = 1,
        minimumOverlap: CGFloat = 0.5,
        comparesText: Bool = true
    ) {
        self.tolerance = tolerance
        self.minimumOverlap = minimumOverlap
        self.comparesText = comparesText
    }

    public static let `default` = DesignComparisonOptions()
}

/// One difference between the design and the screen.
///
/// Fields are flat and optional rather than an enum with associated values:
/// this crosses a JSON boundary to an agent, and a Swift enum with payloads
/// encodes to a shape that breaks every older decoder the moment a case is
/// added.
public struct DesignFinding: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case positionMismatch
        case sizeMismatch
        case paddingMismatch
        case textMismatch
        case missingElement
    }

    public enum Severity: String, Codable, Sendable {
        /// The pairing is certain, so the difference is too.
        case error
        /// The pairing was inferred geometrically — check it before acting.
        case warning
    }

    /// How the design node and the on-screen element were paired. A finding
    /// is only as trustworthy as this.
    public enum MatchBasis: String, Codable, Sendable {
        case identifier
        case text
        case overlap
        case unmatched
    }

    public let kind: Kind
    public let severity: Severity
    public let designNode: String
    public let elementID: String?
    /// "x", "y", "width", "height", "text", or a padding edge.
    public let property: String?
    public let expectedValue: CGFloat?
    public let actualValue: CGFloat?
    public let expectedText: String?
    public let actualText: String?
    /// actual − expected, in points. Negative means the screen sits before
    /// the design (higher, or further left, or smaller).
    public let delta: CGFloat?
    public let matchedBy: MatchBasis
    public let message: String
}

/// A design node paired with the element it was matched to.
public struct DesignMatch: Codable, Equatable, Sendable {
    public let designNode: String
    public let elementID: String
    public let matchedBy: DesignFinding.MatchBasis
    /// Intersection-over-union of the two frames, for geometric pairs.
    public let overlap: CGFloat?
}

/// The result of checking a screen against a design.
public struct DesignDiff: Codable, Equatable, Sendable {
    /// How the design's coordinate space was mapped onto the device. Reported
    /// so a surprising result can be traced to the scaling rather than the app.
    public struct Scale: Codable, Equatable, Sendable {
        public let factor: CGFloat
        public let basis: String
        public let designWidth: CGFloat
        public let screenWidth: CGFloat
    }

    public let source: String?
    public let reference: String?
    public let scale: Scale
    public let matches: [DesignMatch]
    public let findings: [DesignFinding]
    /// Elements on screen that no design node claimed. Not findings: a spec
    /// normally describes a handful of components while the screen exposes
    /// every label, container and system element, so treating these as
    /// defects would bury the real ones. Listed for a caller who wants to look.
    public let unmatchedScreenElements: [String]
}

/// Checks a rendered screen against a design.
///
/// Pure and synchronous: it takes a snapshot and a spec and returns a report,
/// which makes the interesting part — the pairing — testable without a
/// simulator, a design tool, or a network.
public enum DesignComparator {
    public static func compare(
        design: DesignSpec,
        snapshot: MeasurementSnapshot,
        options: DesignComparisonOptions = .default
    ) -> DesignDiff {
        let factor = scaleFactor(design: design, snapshot: snapshot)
        let scale = DesignDiff.Scale(
            factor: factor,
            basis: "width",
            designWidth: design.frame.width,
            screenWidth: snapshot.screenSize.width
        )

        let candidates = candidates(in: snapshot)
        let pairing = pair(design: design, candidates: candidates, factor: factor, options: options)

        var findings: [DesignFinding] = []
        for node in design.nodes {
            guard let match = pairing.byNodeID[node.id] else {
                findings.append(
                    missing(
                        node,
                        nearest: nearestUnclaimed(
                            to: node,
                            candidates: candidates,
                            claimed: Set(pairing.byNodeID.values.map(\.index)),
                            factor: factor
                        )
                    )
                )
                continue
            }
            findings += differences(
                node: node,
                candidate: candidates[match.index],
                basis: match.basis,
                factor: factor,
                options: options
            )
        }

        let claimed = Set(pairing.byNodeID.values.map(\.index))
        let unmatched = candidates.indices.filter { !claimed.contains($0) }.map { candidates[$0].id }

        return DesignDiff(
            source: design.source,
            reference: design.reference,
            scale: scale,
            matches: design.nodes.compactMap { node in
                guard let match = pairing.byNodeID[node.id] else { return nil }
                return DesignMatch(
                    designNode: node.label,
                    elementID: candidates[match.index].id,
                    matchedBy: match.basis,
                    overlap: match.overlap
                )
            },
            findings: sorted(findings),
            unmatchedScreenElements: unmatched
        )
    }

    // MARK: - Scaling

    private static func scaleFactor(design: DesignSpec, snapshot: MeasurementSnapshot) -> CGFloat {
        guard design.frame.width > 0, snapshot.screenSize.width > 0 else { return 1 }
        return snapshot.screenSize.width / design.frame.width
    }

    /// The node's frame placed on the device, in screen points. The design
    /// frame is assumed to map to the whole screen starting at its top-left,
    /// which holds for full-screen mocks — the common case.
    private static func expectedFrame(_ node: DesignNode, factor: CGFloat) -> CGRect {
        CGRect(
            x: node.frame.x * factor,
            y: node.frame.y * factor,
            width: node.frame.width * factor,
            height: node.frame.height * factor
        )
    }

    // MARK: - Candidates

    /// One measurable thing on screen, flattened into what pairing needs.
    private struct Candidate {
        let id: String
        let name: String
        let identifier: String?
        let text: String?
        let frame: CGRect
    }

    private static func candidates(in snapshot: MeasurementSnapshot) -> [Candidate] {
        var result: [Candidate] = []

        for measurement in snapshot.measurements {
            result.append(
                Candidate(
                    id: measurement.id,
                    name: measurement.group,
                    identifier: measurement.metadata["identifier"],
                    text: nil,
                    frame: snapshot.globalFrame(for: measurement)
                )
            )
        }

        // Accessibility-derived elements keep their index alignment with
        // `accessibilityElements`, so the raw label and identifier are still
        // reachable — the flattened metadata only carries the spoken form.
        for (index, measurement) in snapshot.automaticMeasurements.enumerated() {
            let element = snapshot.accessibilityElements.indices.contains(index)
                ? snapshot.accessibilityElements[index]
                : nil
            result.append(
                Candidate(
                    id: measurement.id,
                    name: measurement.group,
                    identifier: element?.identifier?.isEmpty == false ? element?.identifier : nil,
                    text: element?.label?.isEmpty == false ? element?.label : nil,
                    frame: snapshot.globalFrame(for: measurement)
                )
            )
        }

        for measurement in snapshot.treeMeasurements {
            result.append(
                Candidate(
                    id: measurement.id,
                    name: measurement.group,
                    identifier: nil,
                    text: nil,
                    frame: snapshot.globalFrame(for: measurement)
                )
            )
        }

        return result
    }

    // MARK: - Pairing

    private struct Match {
        let index: Int
        let basis: DesignFinding.MatchBasis
        let overlap: CGFloat?
    }

    private struct Pairing {
        var byNodeID: [String: Match] = [:]
        var usedCandidates: Set<Int> = []
    }

    /// Three passes, most reliable first: an explicit or name-based
    /// identifier, then identical copy, then geometry. Each element can be
    /// claimed once, so a confident pair is never stolen by a later guess.
    private static func pair(
        design: DesignSpec,
        candidates: [Candidate],
        factor: CGFloat,
        options: DesignComparisonOptions
    ) -> Pairing {
        var pairing = Pairing()

        // Pass 1 — identifier.
        for node in design.nodes {
            let keys = [node.match, node.name].compactMap { $0 }.filter { !$0.isEmpty }
            guard !keys.isEmpty else { continue }
            let index = candidates.indices.first { index in
                guard !pairing.usedCandidates.contains(index) else { return false }
                let candidate = candidates[index]
                return keys.contains { key in
                    candidate.identifier == key || candidate.name == key || candidate.id == key
                }
            }
            if let index {
                pairing.byNodeID[node.id] = Match(index: index, basis: .identifier, overlap: nil)
                pairing.usedCandidates.insert(index)
            }
        }

        // Pass 2 — identical copy. Pairs on an exact (trimmed) match, so a
        // node paired this way can never also report a text mismatch.
        for node in design.nodes where pairing.byNodeID[node.id] == nil {
            guard let text = node.text?.trimmed, !text.isEmpty else { continue }
            let index = candidates.indices.first { index in
                guard !pairing.usedCandidates.contains(index) else { return false }
                return candidates[index].text?.trimmed == text
            }
            if let index {
                pairing.byNodeID[node.id] = Match(index: index, basis: .text, overlap: nil)
                pairing.usedCandidates.insert(index)
            }
        }

        // Pass 3 — geometry. Scored globally and assigned best-first, so the
        // strongest overlap wins regardless of the order nodes were listed in.
        var scored: [(node: DesignNode, index: Int, overlap: CGFloat)] = []
        for node in design.nodes where pairing.byNodeID[node.id] == nil {
            let expected = expectedFrame(node, factor: factor)
            for index in candidates.indices where !pairing.usedCandidates.contains(index) {
                let score = overlap(expected, candidates[index].frame)
                if score >= options.minimumOverlap {
                    scored.append((node, index, score))
                }
            }
        }
        for entry in scored.sorted(by: { $0.overlap > $1.overlap }) {
            guard pairing.byNodeID[entry.node.id] == nil,
                  !pairing.usedCandidates.contains(entry.index) else { continue }
            pairing.byNodeID[entry.node.id] = Match(
                index: entry.index,
                basis: .overlap,
                overlap: (entry.overlap * 1000).rounded() / 1000
            )
            pairing.usedCandidates.insert(entry.index)
        }

        return pairing
    }

    static func overlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let unionArea = a.width * a.height + b.width * b.height - intersectionArea
        guard unionArea > 0 else { return 0 }
        return intersectionArea / unionArea
    }

    // MARK: - Differences

    private static func differences(
        node: DesignNode,
        candidate: Candidate,
        basis: DesignFinding.MatchBasis,
        factor: CGFloat,
        options: DesignComparisonOptions
    ) -> [DesignFinding] {
        let expected = expectedFrame(node, factor: factor)
        let actual = candidate.frame
        // A geometric pair is a guess, so its differences are warnings.
        let severity: DesignFinding.Severity = basis == .overlap ? .warning : .error
        var findings: [DesignFinding] = []

        let geometry: [(String, CGFloat, CGFloat, DesignFinding.Kind)] = [
            ("x", expected.minX, actual.minX, .positionMismatch),
            ("y", expected.minY, actual.minY, .positionMismatch),
            ("width", expected.width, actual.width, .sizeMismatch),
            ("height", expected.height, actual.height, .sizeMismatch),
        ]
        for (property, expectedValue, actualValue, kind) in geometry {
            let delta = actualValue - expectedValue
            guard abs(delta) > options.tolerance else { continue }
            findings.append(
                DesignFinding(
                    kind: kind,
                    severity: severity,
                    designNode: node.label,
                    elementID: candidate.id,
                    property: property,
                    expectedValue: rounded(expectedValue),
                    actualValue: rounded(actualValue),
                    expectedText: nil,
                    actualText: nil,
                    delta: rounded(delta),
                    matchedBy: basis,
                    message: "\(node.label): \(property) is \(format(actualValue)) pt, design says \(format(expectedValue)) pt (\(signed(delta)) pt)."
                )
            )
        }

        if options.comparesText,
           let expectedText = node.text?.trimmed, !expectedText.isEmpty,
           let actualText = candidate.text?.trimmed,
           actualText != expectedText {
            findings.append(
                DesignFinding(
                    kind: .textMismatch,
                    severity: severity,
                    designNode: node.label,
                    elementID: candidate.id,
                    property: "text",
                    expectedValue: nil,
                    actualValue: nil,
                    expectedText: expectedText,
                    actualText: actualText,
                    delta: nil,
                    matchedBy: basis,
                    message: "\(node.label): reads \"\(actualText)\", design says \"\(expectedText)\"."
                )
            )
        }

        return findings
    }

    /// The closest thing on screen that the pairing rejected. Without this, a
    /// component that merely moved too far to pair is reported as "missing",
    /// which sends someone hunting for an element that is plainly on screen.
    private static func nearestUnclaimed(
        to node: DesignNode,
        candidates: [Candidate],
        claimed: Set<Int>,
        factor: CGFloat
    ) -> (id: String, overlap: CGFloat)? {
        let expected = expectedFrame(node, factor: factor)
        var best: (id: String, overlap: CGFloat)?
        for index in candidates.indices where !claimed.contains(index) {
            let score = overlap(expected, candidates[index].frame)
            guard score > 0, score > (best?.overlap ?? 0) else { continue }
            best = (candidates[index].id, score)
        }
        return best
    }

    private static func missing(
        _ node: DesignNode,
        nearest: (id: String, overlap: CGFloat)?
    ) -> DesignFinding {
        var message = "\(node.label) is in the design but nothing on screen matched it."
        if let nearest {
            let percent = Int((nearest.overlap * 100).rounded())
            message += " The closest element is \(nearest.id) at \(percent)% overlap — too far to pair confidently, so check whether it moved rather than disappeared."
        }
        return DesignFinding(
            kind: .missingElement,
            severity: .error,
            designNode: node.label,
            elementID: nearest?.id,
            property: nil,
            expectedValue: nil,
            actualValue: nil,
            expectedText: node.text,
            actualText: nil,
            delta: nil,
            matchedBy: .unmatched,
            message: message
        )
    }

    // MARK: - Presentation

    private static func sorted(_ findings: [DesignFinding]) -> [DesignFinding] {
        findings.sorted { first, second in
            if first.severity != second.severity { return first.severity == .error }
            let firstDelta = abs(first.delta ?? .greatestFiniteMagnitude)
            let secondDelta = abs(second.delta ?? .greatestFiniteMagnitude)
            if firstDelta != secondDelta { return firstDelta > secondDelta }
            return first.designNode < second.designNode
        }
    }

    private static func rounded(_ value: CGFloat) -> CGFloat {
        (value * 100).rounded() / 100
    }

    private static func format(_ value: CGFloat) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? String(Int(rounded))
            : String(format: "%.1f", Double(rounded))
    }

    private static func signed(_ value: CGFloat) -> String {
        value > 0 ? "+\(format(value))" : format(value)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
