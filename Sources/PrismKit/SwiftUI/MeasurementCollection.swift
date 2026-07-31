import SwiftUI

// The anchor preference this file used to define is gone. Measured views
// report themselves to `MeasurementStore` instead, because a preference cannot
// travel out of a `navigationDestination` and so never reached a scope placed
// above a navigation stack.

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
