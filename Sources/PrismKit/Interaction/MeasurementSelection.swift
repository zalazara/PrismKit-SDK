import Foundation

/// Figma-style multi-selection of measurements.
///
/// - `select` replaces the selection with one element (plain click).
/// - `toggle` adds or removes an element (shift-click).
/// - Selection order is preserved; geometry-based ordering for distance
///   readouts is up to the presentation layer.
public struct MeasurementSelection: Equatable, Sendable {
    public private(set) var selectedIDs: [ResolvedMeasurement.ID] = []

    public init() {}

    public var isEmpty: Bool { selectedIDs.isEmpty }

    public var count: Int { selectedIDs.count }

    /// The first-selected element, used as the measuring anchor.
    public var primaryID: ResolvedMeasurement.ID? { selectedIDs.first }

    public func contains(_ id: ResolvedMeasurement.ID) -> Bool {
        selectedIDs.contains(id)
    }

    /// Replaces the whole selection with `id` (plain click).
    public mutating func select(_ id: ResolvedMeasurement.ID) {
        selectedIDs = [id]
    }

    /// Adds `id` to the selection, or removes it if already selected
    /// (shift-click).
    public mutating func toggle(_ id: ResolvedMeasurement.ID) {
        if let index = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: index)
        } else {
            selectedIDs.append(id)
        }
    }

    public mutating func clear() {
        selectedIDs = []
    }
}
