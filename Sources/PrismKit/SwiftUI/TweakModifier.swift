import SwiftUI

extension View {
    /// Offers a number for the companion to change while the app runs.
    ///
    /// The component keeps owning the value. This hands over the binding it
    /// already has, so a change from the Mac goes through the same state the
    /// app itself writes to and re-lays-out exactly as if the code had done
    /// it. Nothing is reached into, and nothing is faked.
    ///
    /// ```swift
    /// @State private var cardPadding: CGFloat = 16
    ///
    /// VStack { … }
    ///     .padding(cardPadding)
    ///     .measureTweak("Card padding", $cardPadding, in: 0...48)
    /// ```
    ///
    /// Give bounds when the value has them — the companion shows a slider —
    /// and leave them off when it does not, which gets a plain field. A slider
    /// with invented limits teaches the wrong thing about what the value can
    /// be.
    ///
    /// Names are the key changes come back under, so they have to be unique in
    /// the app. Debug builds only; in release this returns the view unchanged
    /// and the binding is never read.
    public func measureTweak(
        _ name: String,
        _ value: Binding<CGFloat>,
        in bounds: ClosedRange<CGFloat>? = nil
    ) -> some View {
        #if DEBUG
        return modifier(
            TweakModifier(
                name: name,
                read: { .number(Double(value.wrappedValue)) },
                write: { new in
                    if let number = new.number { value.wrappedValue = CGFloat(number) }
                },
                minimum: bounds.map { Double($0.lowerBound) },
                maximum: bounds.map { Double($0.upperBound) }
            )
        )
        #else
        return self
        #endif
    }

    /// Offers a flag for the companion to change. See ``measureTweak(_:_:in:)``.
    public func measureTweak(_ name: String, _ value: Binding<Bool>) -> some View {
        #if DEBUG
        return modifier(
            TweakModifier(
                name: name,
                read: { .boolean(value.wrappedValue) },
                write: { new in
                    if let flag = new.boolean { value.wrappedValue = flag }
                },
                minimum: nil,
                maximum: nil
            )
        )
        #else
        return self
        #endif
    }

    /// Offers a piece of copy for the companion to change.
    ///
    /// This is the one the removed preview mock pretended to do. The
    /// difference is that the text really changes: the app re-lays-out around
    /// it, so wrapping, truncation and the height of everything below it are
    /// the real answers rather than a picture of a guess.
    public func measureTweak(_ name: String, _ value: Binding<String>) -> some View {
        #if DEBUG
        return modifier(
            TweakModifier(
                name: name,
                read: { .text(value.wrappedValue) },
                write: { new in
                    if let text = new.text { value.wrappedValue = text }
                },
                minimum: nil,
                maximum: nil
            )
        )
        #else
        return self
        #endif
    }
}

#if DEBUG

private struct TweakModifier: ViewModifier {
    @Environment(\.measureScopeIsEnabled) private var isEnabled

    let name: String
    let read: () -> TweakValue
    let write: (TweakValue) -> Void
    let minimum: Double?
    let maximum: Double?

    func body(content: Content) -> some View {
        // Registered as the view updates, like the solo renderers and for the
        // same reason: a binding captured once stops pointing at the state the
        // app is actually using the moment the view is rebuilt.
        if isEnabled {
            TweakRegistry.shared.register(
                Tweak(name: name, value: read(), minimum: minimum, maximum: maximum),
                write: write
            )
        }
        return content
            .onDisappear { TweakRegistry.shared.forget(name) }
    }
}

/// The tweaks the app is currently offering.
///
/// Not an `ObservableObject`: writing to it during a view update to publish a
/// change would invalidate the very views being built. The snapshot reads it
/// when it is assembled, which is often enough — a tweak's value only moves
/// when something else already caused an update.
@MainActor
final class TweakRegistry {
    static let shared = TweakRegistry()

    private var tweaks: [String: Tweak] = [:]
    private var writers: [String: (TweakValue) -> Void] = [:]
    private var order: [String] = []

    /// What each value was the first time it was offered, so a change has a
    /// way back. Recorded once per name and never overwritten — re-registering
    /// on a view update reports the *current* value, and taking that as the
    /// default would quietly redefine "original" as "whatever it is now".
    private var defaults: [String: TweakValue] = [:]

    func register(_ tweak: Tweak, write: @escaping (TweakValue) -> Void) {
        if tweaks[tweak.name] == nil { order.append(tweak.name) }
        if defaults[tweak.name] == nil { defaults[tweak.name] = tweak.value }
        var recorded = tweak
        recorded.defaultValue = defaults[tweak.name]
        tweaks[tweak.name] = recorded
        writers[tweak.name] = write
    }

    func forget(_ name: String) {
        tweaks.removeValue(forKey: name)
        writers.removeValue(forKey: name)
        // The default goes too. A screen that leaves and comes back rebuilds
        // its state from the source, so the value it offers next time is the
        // original again — keeping the old one would pin "default" to a
        // previous screen's edit.
        defaults.removeValue(forKey: name)
        order.removeAll { $0 == name }
    }

    /// In the order the app declared them, which is the order they appear in
    /// the source and so the order that reads as deliberate.
    var current: [Tweak] {
        order.compactMap { tweaks[$0] }
    }

    /// Applies values pushed by the companion. Unknown names are ignored: a
    /// tweak can go while a message about it is in flight, and the app should
    /// not care.
    func apply(_ message: TweakMessage) {
        for (name, value) in message.tweaks {
            writers[name]?(value)
        }
    }
}

#endif
