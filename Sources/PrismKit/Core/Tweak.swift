import CoreGraphics
import Foundation

/// A value the app has offered to let the companion change while it runs.
///
/// Size overrides work from outside because `measure` wraps the view and can
/// impose a frame on it. Nothing else can be reached that way: padding,
/// spacing, a colour and a piece of copy are arguments a component was
/// constructed with, and from outside the process there is no object left to
/// ask. An earlier attempt to fake it — drawing replacement text over the
/// screenshot in the companion — was removed for being a lie about what the
/// app was doing.
///
/// So the component says. It hands over a binding, which is already a getter
/// and a setter, and the companion drives that. What can be changed is then a
/// decision in the app's own code rather than a guess made from outside, and
/// nothing is ever shown as editable that is not.
public struct Tweak: Codable, Equatable, Sendable, Identifiable {
    /// What the app called it — "Card padding", "Row spacing". Also the key
    /// the companion sends changes back under, so it has to be unique within
    /// the app.
    public let name: String

    public var id: String { name }

    /// The value right now, as the app last reported it.
    public var value: TweakValue

    /// Bounds for a number, when the app gave them. The companion uses them
    /// for a slider; without them it shows a field, because a slider with
    /// invented bounds teaches the wrong thing about what the value can be.
    public var minimum: Double?
    public var maximum: Double?

    /// What the value was when the app first offered it — the number written
    /// in the source, before anybody dragged anything.
    ///
    /// Carried so a change can be undone. Without it the only way back to the
    /// original is to remember it yourself and type it in, which is not an
    /// undo, and every other editable thing here has a way back.
    ///
    /// Optional because an app built against an earlier PrismKit does not send
    /// one; the companion simply offers no reset for those.
    public var defaultValue: TweakValue?

    public init(
        name: String,
        value: TweakValue,
        minimum: Double? = nil,
        maximum: Double? = nil,
        defaultValue: TweakValue? = nil
    ) {
        self.name = name
        self.value = value
        self.minimum = minimum
        self.maximum = maximum
        self.defaultValue = defaultValue
    }

    /// Whether this has been moved away from what the app started with.
    public var isChanged: Bool {
        guard let defaultValue else { return false }
        return value != defaultValue
    }
}

/// The kinds of value a component can offer.
///
/// Deliberately few. Each one needs an editor in the companion that is
/// obviously right, and a type whose editor is a guess is worse than a type
/// that is not offered.
public enum TweakValue: Codable, Equatable, Sendable {
    case number(Double)
    case boolean(Bool)
    case text(String)

    public var number: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    public var boolean: Bool? {
        if case .boolean(let value) = self { return value }
        return nil
    }

    public var text: String? {
        if case .text(let value) = self { return value }
        return nil
    }
}

/// Companion → app: new values for tweaks, by name.
///
/// Only the ones that changed. Unlike `OverrideMessage`, which replaces the
/// whole set, an absent name here means "leave it alone" — the companion has
/// no business resetting a value nobody touched.
public struct TweakMessage: Codable, Equatable, Sendable {
    public var tweaks: [String: TweakValue]

    public init(tweaks: [String: TweakValue]) {
        self.tweaks = tweaks
    }
}
