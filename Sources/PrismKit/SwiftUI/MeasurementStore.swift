import CoreGraphics
import Combine
import SwiftUI

#if DEBUG

/// Where measured views report themselves, instead of handing their frames up
/// the view tree as preferences.
///
/// Preferences travel from a child to an ancestor, and they do not travel out
/// of a `navigationDestination`: a screen pushed onto a `NavigationStack`
/// cannot hand anything to a scope placed above the stack. The consequence was
/// not subtle — navigate anywhere and every measurement vanished, so the
/// overlay drew nothing, nothing could be selected, and the companion, the
/// design check and the accessibility rules all saw an empty screen. Only the
/// first screen ever worked.
///
/// It survived because the test that was meant to catch it launched straight
/// into the pushed screen with `-autopush`, where the screen is present from
/// the start and never has to cross the boundary. Arriving somewhere and
/// navigating there are not the same thing, and only one of them was tried.
///
/// A store is not subject to that rule. A measured view reports where it is
/// and the scope reads it, however deep in a navigation stack either of them
/// happens to be.
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
