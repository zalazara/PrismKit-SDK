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
    ///   - file: Filled in by the compiler. Do not pass it — except from a
    ///     wrapper, which must declare and forward it. See below.
    ///   - line: Filled in by the compiler. Do not pass it, same caveat.
    ///
    /// ## Wrapping this
    ///
    /// A helper that calls `measure` for you is the normal thing to write, and
    /// it silently ruins the call site unless it forwards one:
    ///
    /// ```swift
    /// func designNode(
    ///     _ name: String,
    ///     file: String = #fileID,
    ///     line: Int = #line
    /// ) -> some View {
    ///     accessibilityIdentifier(name).measure(name, file: file, line: line)
    /// }
    /// ```
    ///
    /// Without those two parameters the compiler fills them in at the helper,
    /// so every view wrapped by it reports the helper's own line — one answer,
    /// the same wrong one, for the whole app. This example's `designNode` got
    /// it wrong first and reported seventy components as living on one line.
    public func measure(
        _ group: String,
        role: MeasurementRole = .container,
        metadata: [String: String] = [:],
        file: String = #fileID,
        line: Int = #line
    ) -> some View {
        #if DEBUG
        // Registered from here, where `self` is the view itself. Inside the
        // modifier the equivalent is `Content`, which is a placeholder that
        // stands for "whatever this modifier was applied to" and resolves only
        // as the modifier is applied — handing it to ImageRenderer produces
        // nothing at all, which is exactly what it did.
        registerSoloRenderer(id: "\(group)#\(role.label)", view: self)
        return modifier(
            MeasureModifier(
                group: group,
                role: role,
                metadata: metadata,
                callSite: CallSite(file: file, line: line)
            )
        )
        #else
        // The arguments are declared in release and ignored, rather than not
        // declared at all. Not declaring them is airtight against literals
        // reaching a shipping binary, and it was the first design — but it
        // makes the wrapper above fail to compile in release, which pushes
        // `#if DEBUG` into every consumer's helper. That trade is not worth
        // it, for two reasons. The optimizer strips an ignored argument
        // anyway: measured across a module boundary in a release build, the
        // file name is in the binary when the callee reads it and absent when
        // it does not. And a wrapper captures `#fileID` in the consumer's own
        // code regardless, so the SDK refusing the parameter moves the
        // question rather than answering it. `#filePath` is the one that would
        // genuinely matter if it leaked, so it is not captured at all.
        self
        #endif
    }

    #if DEBUG
    /// Teaches the registry how to draw this component alone: the same view,
    /// with `prismHidesNestedMeasurements` set so every measured view inside
    /// it takes up its space without drawing.
    ///
    /// The view is drawn out of its context, so it gets the size the
    /// measurement recorded and the default environment rather than the ones
    /// its ancestors would have given it. A component that reads
    /// `\.colorScheme` therefore draws light here even on a dark screen. That
    /// is a known limit of drawing something on its own, not a bug to chase.
    fileprivate func registerSoloRenderer(id: String, view: some View) {
        #if canImport(UIKit)
        guard #available(iOS 16.0, *) else { return }
        let solo = view.environment(\.prismHidesNestedMeasurements, true)
        let scale = UIScreen.main.scale
        SoloRenderRegistry.register(id: id) { size in
            guard #available(iOS 16.0, *) else { return nil }
            return prismRenderOffscreen(solo, size: size, scale: scale)
        }
        #endif
    }
    #endif
}

#if DEBUG

private struct MeasureModifier: ViewModifier {
    @Environment(\.measureScopeIsEnabled) private var isEnabled
    @Environment(\.prismHidesNestedMeasurements) private var hidesNested
    @ObservedObject private var overrides = MeasurementOverrideStore.shared

    // Navigation stacks and tab views keep covered screens mounted, so their
    // anchors would keep reporting. Gate on real visibility instead.
    @State private var isVisible = false

    let group: String
    let role: MeasurementRole
    let metadata: [String: String]
    let callSite: CallSite

    private var id: String { "\(group)#\(role.label)" }

    func body(content: Content) -> some View {
        if hidesNested {
            // An enclosing component is being drawn on its own, and this one
            // is inside it. `hidden()` rather than removing it: the point of
            // the picture is what the container looks like without its
            // contents, and contents that stop taking up space would change
            // the container's layout and so the very thing being drawn.
            content.hidden()
        } else {
            measured(content)
        }
    }

    private func measured(_ content: Content) -> some View {
        content
            // Live size tweaks pushed from the companion re-lay-out the real
            // view; a nil dimension leaves that axis untouched. Alignment
            // positions the original content inside the overridden frame.
            .frame(
                width: sizeOverride?.width,
                height: sizeOverride?.height,
                alignment: overrideAlignment
            )
            // Reported rather than handed up as a preference. A preference
            // cannot leave a `navigationDestination`, so a scope above the
            // navigation stack never heard from any screen but the first —
            // see `MeasurementStore`.
            .background(reporter)
            .onAppear { isVisible = true }
            .onDisappear {
                isVisible = false
                // Both registries: a view that has left the hierarchy must
                // stop being measured and stop offering to draw itself, or the
                // companion is handed the geometry and the picture of a screen
                // the app navigated away from.
                MeasurementStore.shared.forget(id)
                SoloRenderRegistry.forget(id: id)
            }
    }

    /// Watches this view's frame and reports it.
    ///
    /// In the background rather than as an overlay so it cannot intercept a
    /// touch, and `Color.clear` so it cannot be seen. `.global` because the
    /// scope may be an entire navigation stack away and screen coordinates are
    /// the only space both ends agree on.
    private var reporter: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            Color.clear
                .onAppear { report(frame) }
                .onChange(of: frame) { report($0) }
                // A scope switched off mid-session has to take its
                // measurements with it.
                .onChange(of: isEnabled) { _ in report(frame) }
        }
    }

    private func report(_ frame: CGRect) {
        guard isEnabled else {
            MeasurementStore.shared.forget(id)
            return
        }
        MeasurementStore.shared.report(
            GlobalMeasurement(
                group: group,
                role: role,
                metadata: metadata,
                callSite: callSite,
                globalFrame: frame
            )
        )
    }

    private var sizeOverride: SizeOverride? {
        guard isEnabled else { return nil }
        return overrides.override(for: id)
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
