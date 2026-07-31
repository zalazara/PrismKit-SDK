/// Build-time facts about PrismKit.
public enum PrismKit {
    /// Whether PrismKit collects and streams anything in this build:
    /// `true` in debug builds, `false` in release builds.
    ///
    /// PrismKit is a development tool. Collecting measurements means walking
    /// the accessibility tree, which carries the labels and values of what is
    /// on screen — including text the user typed into fields — and streaming
    /// it over a local socket. None of that belongs in a shipping app, so the
    /// entire collection, overlay, and streaming layer is compiled out of
    /// release builds: `measureScope` and `measure` return the view unchanged,
    /// no socket is opened, and no accessibility walk ever runs.
    ///
    /// You therefore do not need to wrap calls in `#if DEBUG` yourself. This
    /// flag is here for the cases where you want to branch on the tool being
    /// available — showing a QA-only entry point, for instance.
    public static let isEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// Decides whether a component may be drawn on its own for the companion.
    /// Return false to refuse one; nil — the default — allows everything.
    ///
    /// Two reasons to say no, and they are different questions:
    ///
    /// Cost. Drawing a component on its own is a real render on the main
    /// thread, and a screen full of instrumented rows can be asked for at
    /// once. Excluding the ones nobody inspects keeps the app responsive while
    /// the companion is attached.
    ///
    /// Content. A picture of a component leaves the process. A view showing a
    /// card number or somebody's medical record is one your team may not want
    /// travelling to a Mac and sitting in a saved session file, however local
    /// the socket is. The app is the only side that knows which those are.
    ///
    /// Called on the main thread, once per component per request, with the
    /// measurement id ("group#role"). Keep it cheap and keep it pure.
    ///
    /// ```swift
    /// PrismKit.rendersComponent = { id in
    ///     !id.hasPrefix("payment-") && !id.hasPrefix("patient-")
    /// }
    /// ```
    ///
    /// Refusing a component is not hiding it: its frame, size and padding are
    /// still measured and still streamed. This governs the picture only. In
    /// release builds nothing is drawn or streamed at all, so it is moot.
    @MainActor
    public static var rendersComponent: ((String) -> Bool)?
}
