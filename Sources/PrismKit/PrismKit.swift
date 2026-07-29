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
}
