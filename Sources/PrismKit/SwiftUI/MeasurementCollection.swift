import SwiftUI

/// A measurement reported by an instrumented view, carrying an unresolved
/// layout anchor. Resolved to a concrete frame by the enclosing scope.
struct MeasurementAnchor {
    let group: String
    let role: MeasurementRole
    let metadata: [String: String]
    let callSite: CallSite
    let bounds: Anchor<CGRect>
}

/// Collects measurement anchors from the instrumented subtree.
struct MeasurementPreferenceKey: PreferenceKey {
    static var defaultValue: [MeasurementAnchor] { [] }

    static func reduce(value: inout [MeasurementAnchor], nextValue: () -> [MeasurementAnchor]) {
        value.append(contentsOf: nextValue())
    }
}

private struct MeasureScopeEnabledKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Whether an enclosing `measureScope` has enabled measurement collection.
    var measureScopeIsEnabled: Bool {
        get { self[MeasureScopeEnabledKey.self] }
        set { self[MeasureScopeEnabledKey.self] = newValue }
    }
}
