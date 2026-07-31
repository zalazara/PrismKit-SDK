import CoreGraphics
import Combine
import SwiftUI

#if DEBUG

/// Where measured views report themselves, instead of handing their frames up
/// the view tree as preferences.
///
/// Preferences travel from a child to an ancestor, but not out of a
/// `navigationDestination`: a screen pushed onto a `NavigationStack` cannot
/// hand anything to a scope above the stack. Navigate anywhere and every
/// measurement vanished — no overlay, nothing selectable, and an empty screen
/// for the companion, the design check and the accessibility rules alike. Only
/// the first screen ever worked.
///
/// It survived because the test meant to catch it launched straight into the
/// pushed screen with `-autopush`, so the screen never crossed the boundary.
/// Arriving somewhere and navigating there are not the same thing.
///
/// A store has no such rule: a measured view reports where it is and the scope
/// reads it, however deep either sits in a navigation stack.
@MainActor
final class MeasurementStore: ObservableObject {
    static let shared = MeasurementStore()

    /// Frames in global (screen) coordinates. The scope converts them into its
    /// own space, which is the one measurements are expressed in.
    @Published private(set) var reported: [String: GlobalMeasurement] = [:]

    /// Reports pending publication. Writes arrive during layout, and
    /// publishing then would be modifying state while the view that caused it
    /// is still being built.
    private var pending: [String: GlobalMeasurement?] = [:]
    private var isFlushScheduled = false

    private init() {}

    func report(_ measurement: GlobalMeasurement) {
        // Unchanged frames are the common case — a view reports on every
        // layout pass — and publishing them would redraw the overlay for
        // nothing.
        if reported[measurement.id] == measurement, pending[measurement.id] == nil { return }
        pending[measurement.id] = measurement
        scheduleFlush()
    }

    func forget(_ id: String) {
        guard reported[id] != nil || pending[id] != nil else { return }
        pending[id] = .some(nil)
        scheduleFlush()
    }

    /// Coalesced to one publication per runloop turn. A screen appearing
    /// reports thirty views at once, and thirty redraws of the same overlay is
    /// twenty-nine too many.
    private func scheduleFlush() {
        guard !isFlushScheduled else { return }
        isFlushScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isFlushScheduled = false
            guard !self.pending.isEmpty else { return }
            var next = self.reported
            for (id, value) in self.pending {
                if let value { next[id] = value } else { next.removeValue(forKey: id) }
            }
            self.pending.removeAll()
            if next != self.reported { self.reported = next }
        }
    }
}

/// One measured view, as it reported itself: everything a `ResolvedMeasurement`
/// needs except the coordinate space, which only the scope knows.
struct GlobalMeasurement: Equatable {
    let group: String
    let role: MeasurementRole
    let metadata: [String: String]
    let callSite: CallSite
    /// In screen coordinates.
    let globalFrame: CGRect

    var id: String { "\(group)#\(role.label)" }
}

#endif
