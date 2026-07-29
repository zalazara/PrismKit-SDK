import SwiftUI

extension View {
    /// Reports this view's bounds as a measurement when an enclosing
    /// `measureScope` is enabled. Has no effect otherwise.
    ///
    /// Measurements sharing the same `group` are treated as one logical
    /// component, letting the overlay derive internal padding from
    /// container/content pairs:
    ///
    /// ```swift
    /// HStack { icon; label }
    ///     .measure("primaryButton", role: .content)
    ///     .padding(12)
    ///     .background(Capsule().fill(.blue))
    ///     .measure("primaryButton", role: .container)
    /// ```
    ///
    /// Debug builds only. In a release build this modifier compiles down to
    /// the view itself — it never reports, and never applies a size override.
    /// See ``PrismKit/isEnabled``.
    ///
    /// - Parameters:
    ///   - group: The logical component identifier this measurement belongs to.
    ///   - role: The semantic role of the measured area. Defaults to `.container`.
    ///   - metadata: Optional free-form metadata shown alongside the measurement.
    public func measure(
        _ group: String,
        role: MeasurementRole = .container,
        metadata: [String: String] = [:]
    ) -> some View {
        #if DEBUG
        modifier(MeasureModifier(group: group, role: role, metadata: metadata))
        #else
        self
        #endif
    }
}

#if DEBUG

private struct MeasureModifier: ViewModifier {
    @Environment(\.measureScopeIsEnabled) private var isEnabled
    @ObservedObject private var overrides = MeasurementOverrideStore.shared

    // Navigation stacks and tab views keep covered screens mounted, so their
    // anchors would keep reporting. Gate on real visibility instead.
    @State private var isVisible = false

    let group: String
    let role: MeasurementRole
    let metadata: [String: String]

    func body(content: Content) -> some View {
        content
            // Live size tweaks pushed from the companion re-lay-out the real
            // view; a nil dimension leaves that axis untouched. Alignment
            // positions the original content inside the overridden frame.
            .frame(
                width: sizeOverride?.width,
                height: sizeOverride?.height,
                alignment: overrideAlignment
            )
            .transformAnchorPreference(
                key: MeasurementPreferenceKey.self,
                value: .bounds
            ) { value, anchor in
                guard isEnabled, isVisible else { return }
                value.append(
                    MeasurementAnchor(group: group, role: role, metadata: metadata, bounds: anchor)
                )
            }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
    }

    private var sizeOverride: SizeOverride? {
        guard isEnabled else { return nil }
        return overrides.override(for: "\(group)#\(role.label)")
    }

    private var overrideAlignment: Alignment {
        switch sizeOverride?.alignment {
        case "topLeading": return .topLeading
        case "top": return .top
        case "topTrailing": return .topTrailing
        case "leading": return .leading
        case "trailing": return .trailing
        case "bottomLeading": return .bottomLeading
        case "bottom": return .bottom
        case "bottomTrailing": return .bottomTrailing
        default: return .center
        }
    }
}

#endif
