import CoreGraphics

/// A logical component assembled from measurements that share the same group name.
///
/// For example, `primaryButton#container` and `primaryButton#content` form the
/// group `primaryButton`, from which internal padding can be derived.
public struct MeasurementGroup: Identifiable, Equatable, Sendable {
    /// The shared group name (e.g. "primaryButton").
    public let name: String

    /// All measurements reported for this group, in reporting order.
    public let measurements: [ResolvedMeasurement]

    public var id: String { name }

    public init(name: String, measurements: [ResolvedMeasurement]) {
        self.name = name
        self.measurements = measurements
    }

    /// The measurement with the `container` role, if reported.
    public var container: ResolvedMeasurement? {
        measurements.first { $0.role == .container }
    }

    /// All measurements with the `content` role.
    public var contentMeasurements: [ResolvedMeasurement] {
        measurements.filter { $0.role == .content }
    }

    /// The union of all `content` frames, or `nil` when no content was reported.
    public var contentUnionFrame: CGRect? {
        let frames = contentMeasurements.map(\.frame)
        guard let first = frames.first else { return nil }
        return frames.dropFirst().reduce(first) { $0.union($1) }
    }

    /// The internal padding between the container and the union of content
    /// frames, or `nil` when either side is missing.
    public var contentPadding: InternalPadding? {
        guard let container, let content = contentUnionFrame else { return nil }
        return .between(container: container.frame, content: content)
    }

    /// Groups measurements by their group name, preserving first-seen order.
    public static func groups(from measurements: [ResolvedMeasurement]) -> [MeasurementGroup] {
        var order: [String] = []
        var byName: [String: [ResolvedMeasurement]] = [:]
        for measurement in measurements {
            if byName[measurement.group] == nil {
                order.append(measurement.group)
            }
            byName[measurement.group, default: []].append(measurement)
        }
        return order.map { MeasurementGroup(name: $0, measurements: byName[$0] ?? []) }
    }
}
