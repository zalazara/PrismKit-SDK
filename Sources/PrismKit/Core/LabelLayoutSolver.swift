import CoreGraphics

/// A label that wants to be placed at a preferred rect in overlay space.
public struct LabelCandidate: Equatable, Sendable {
    public let id: String
    public let rect: CGRect

    public init(id: String, rect: CGRect) {
        self.id = id
        self.rect = rect
    }
}

/// Resolves overlapping overlay labels by pushing later labels downward.
///
/// Labels are processed top-to-bottom (then leading-to-trailing), so the
/// upper label keeps its preferred position and lower ones stack below it.
public enum LabelLayoutSolver {
    /// Returns the resolved center position for each candidate, keyed by id.
    /// Candidates that do not collide keep their preferred position.
    public static func resolve(
        _ candidates: [LabelCandidate],
        spacing: CGFloat = 2
    ) -> [String: CGPoint] {
        var placedRects: [CGRect] = []
        var positions: [String: CGPoint] = [:]
        let ordered = candidates.sorted { lhs, rhs in
            (lhs.rect.minY, lhs.rect.minX) < (rhs.rect.minY, rhs.rect.minX)
        }
        for candidate in ordered {
            var rect = candidate.rect
            var attempts = 0
            while attempts < 64,
                  let blocking = placedRects.first(where: { $0.intersects(rect) }) {
                rect.origin.y = blocking.maxY + spacing
                attempts += 1
            }
            placedRects.append(rect)
            positions[candidate.id] = CGPoint(x: rect.midX, y: rect.midY)
        }
        return positions
    }
}
