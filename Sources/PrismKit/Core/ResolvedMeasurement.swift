import CoreGraphics

/// A measurement reported by an instrumented view, resolved to a concrete frame
/// in the coordinate space of the enclosing measurement scope.
public struct ResolvedMeasurement: Identifiable, Equatable, Sendable, Codable {
    /// The logical component this measurement belongs to (e.g. "primaryButton").
    /// Measurements sharing the same group are treated as one component.
    public let group: String

    /// The semantic role of the measured area within its group.
    public let role: MeasurementRole

    /// The measured frame, in the scope's coordinate space, in points.
    public let frame: CGRect

    /// Optional free-form metadata attached by the instrumented view.
    public let metadata: [String: String]

    /// Where `measure` was written. Nil when the measurement did not come from
    /// a call site — the accessibility-derived elements have no source to point
    /// at — and when the stream came from an SDK built before this existed.
    public let callSite: CallSite?

    public var id: String { "\(group)#\(role.label)" }

    public init(
        group: String,
        role: MeasurementRole,
        frame: CGRect,
        metadata: [String: String] = [:],
        callSite: CallSite? = nil
    ) {
        self.group = group
        self.role = role
        self.frame = frame
        self.metadata = metadata
        self.callSite = callSite
    }
}
