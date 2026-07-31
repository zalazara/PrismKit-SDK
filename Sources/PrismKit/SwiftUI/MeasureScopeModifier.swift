import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Visibility of the in-app floating measurement toolbar.
public enum MeasureToolbarVisibility: Sendable {
    /// Show the toolbar unless a companion app is currently receiving the
    /// measurement stream — on-device testing keeps the toolbar, while the
    /// desktop workflow keeps the screen clean automatically.
    case automatic
    /// Always show the floating toolbar.
    case visible
    /// Never show the floating toolbar.
    case hidden
}

extension View {
    /// Enables layout measurement debugging for this view's subtree.
    ///
    /// Instrumented descendants (views using `measure(_:role:metadata:)`)
    /// report their frames, and a visual overlay renders bounds, size labels,
    /// internal padding, grid, safe area, and token validation according to
    /// `configuration`.
    ///
    /// A floating toolbar lets you toggle each overlay layer and selection
    /// mode at runtime. With the default `.automatic` visibility it shows
    /// when testing on device (no companion connected) and steps aside while
    /// the Mac companion is receiving.
    /// The overlay never blocks touches on the app's UI unless selection mode
    /// is active; selection mode lets you tap a measured element to see its
    /// distances to the scope edges, or two elements to compare their spacing.
    /// While something is selected, only the selected components render —
    /// the rest of the overlay gets out of the way.
    ///
    /// When `streaming` is enabled (the default) and the PrismKit companion
    /// app is running on the Mac, measurements are also streamed to it over
    /// the simulator's loopback interface. Without a companion listening this
    /// is a silent no-op.
    ///
    /// Debug builds only. In a release build this modifier compiles down to
    /// the view itself: nothing is collected, no accessibility walk runs, and
    /// no socket is opened. See ``PrismKit/isEnabled``.
    ///
    /// - Parameters:
    ///   - enabled: Whether measurement collection and the overlay are active.
    ///   - configuration: Initial overlay appearance and validation settings.
    ///     The floating toolbar can change them at runtime.
    ///   - selection: Whether selection mode starts enabled. When active, the
    ///     overlay intercepts touches on measured elements.
    ///   - toolbar: Floating toolbar visibility. `.automatic` (the default)
    ///     shows it on device and hides it while a companion is connected.
    ///   - streaming: Whether measurements are streamed to a running
    ///     PrismKit companion app.
    public func measureScope(
        enabled: Bool = true,
        configuration: MeasureConfiguration = .default,
        selection: Bool = false,
        toolbar: MeasureToolbarVisibility = .automatic,
        streaming: Bool = true
    ) -> some View {
        #if DEBUG
        modifier(
            MeasureScopeModifier(
                isEnabled: enabled,
                initialConfiguration: configuration,
                initialSelectionEnabled: selection,
                toolbarVisibility: toolbar,
                isStreamingEnabled: streaming
            )
        )
        #else
        self
        #endif
    }
}

#if DEBUG

/// Caches the accessibility tree between streams: the walk touches every view
/// on screen, so doing it per layout change (60/s during a scroll) burns CPU
/// for data that barely changes. A short max age keeps it fresh.
private final class AccessibilityCollectorCache {
    private var cachedElements: [AccessibilityElementInfo] = []
    private var cachedTree: [AccessibilityTreeNode] = []
    private var lastCollect = Date.distantPast

    func snapshot(maxAge: TimeInterval = 0.5) -> (elements: [AccessibilityElementInfo], tree: [AccessibilityTreeNode]) {
        #if canImport(UIKit)
        if Date().timeIntervalSince(lastCollect) >= maxAge {
            (cachedElements, cachedTree) = AccessibilitySnapshotter.collect()
            lastCollect = Date()
        }
        #endif
        return (cachedElements, cachedTree)
    }

    func invalidate() {
        lastCollect = .distantPast
    }
}

/// Holds the most recent snapshot across body evaluations so deferred
/// re-streams send current data, not the (often empty) first-layout capture.
/// Also remembers the last accessibility state actually sent, so the
/// navigation/scroll poll only re-streams on real changes.
private final class LatestSnapshotBox {
    var snapshot: MeasurementSnapshot?
    var lastSentElements: [AccessibilityElementInfo] = []
    var lastSentTree: [AccessibilityTreeNode] = []
}

private struct MeasureScopeModifier: ViewModifier {
    let isEnabled: Bool
    let initialConfiguration: MeasureConfiguration
    let initialSelectionEnabled: Bool
    let toolbarVisibility: MeasureToolbarVisibility
    let isStreamingEnabled: Bool

    @ObservedObject private var streamState = MeasurementStreamClient.state
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var store = MeasurementStore.shared
    @State private var accessibilityCache = AccessibilityCollectorCache()
    @State private var latestBox = LatestSnapshotBox()

    private var showsToolbar: Bool {
        switch toolbarVisibility {
        case .visible: return true
        case .hidden: return false
        case .automatic:
            return !(isStreamingEnabled && streamState.isCompanionConnected)
        }
    }

    // Runtime overrides set from the floating toolbar; nil falls back to the
    // values passed into `measureScope`.
    @State private var configurationOverride: MeasureConfiguration?
    @State private var selectionEnabledOverride: Bool?
    @State private var selection = MeasurementSelection()

    private var configuration: MeasureConfiguration {
        configurationOverride ?? initialConfiguration
    }

    private var isSelectionEnabled: Bool {
        selectionEnabledOverride ?? initialSelectionEnabled
    }

    func body(content: Content) -> some View {
        content
            .environment(\.measureScopeIsEnabled, isEnabled)
            // Read from the store rather than collected as preferences: a
            // preference cannot cross out of a `navigationDestination`, so
            // this used to see the first screen and nothing after it.
            .overlay {
                if isEnabled {
                    GeometryReader { proxy in
                        let measurements = resolvedMeasurements(in: proxy)
                        let snapshot = makeSnapshot(measurements: measurements, proxy: proxy)
                        ZStack(alignment: .topLeading) {
                            MeasureOverlayView(
                                measurements: measurements,
                                configuration: configuration,
                                safeAreaInsets: proxy.safeAreaInsets,
                                size: proxy.size,
                                selection: isSelectionEnabled ? $selection : nil
                            )
                            if showsToolbar {
                                toolbar
                            }
                        }
                        .onAppear {
                            stream(snapshot)
                            // The accessibility tree isn't built while the
                            // first frame is still being presented; re-stream
                            // the latest state once after launch so the
                            // companion gets it even without further layout
                            // changes.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                guard let latest = latestBox.snapshot else { return }
                                accessibilityCache.invalidate()
                                stream(latest)
                            }
                        }
                        .onChange(of: snapshot) { stream($0) }
                        // Navigation, tab switches, and scrolling change the
                        // accessibility tree without touching the base
                        // snapshot (with zero instrumentation nothing else
                        // does either) — poll and re-stream when the tree
                        // actually changed, so the companion never keeps a
                        // previous screen's elements.
                        .task {
                            while !Task.isCancelled {
                                try? await Task.sleep(nanoseconds: 1_000_000_000)
                                guard isStreamingEnabled, let latest = latestBox.snapshot else { continue }
                                let fresh = accessibilityCache.snapshot(maxAge: 0.8)
                                if fresh.elements != latestBox.lastSentElements
                                    || fresh.tree != latestBox.lastSentTree {
                                    stream(latest)
                                }
                            }
                        }
                        .onDisappear {
                            // The scope left the hierarchy (e.g. navigation).
                            // Clear remote overlays instead of leaving stale ones.
                            var empty = snapshot
                            empty.measurements = []
                            stream(empty)
                        }
                    }
                }
            }
            // A closed or backgrounded app must stop transmitting: tear the
            // connection down instead of leaving the companion on a live feed.
            .onChange(of: scenePhase) { phase in
                guard isEnabled, isStreamingEnabled else { return }
                if phase == .active {
                    MeasurementStreamClient.shared.resume()
                } else {
                    MeasurementStreamClient.shared.suspend()
                }
            }
    }

    private func stream(_ snapshot: MeasurementSnapshot) {
        guard isStreamingEnabled else { return }
        latestBox.snapshot = snapshot
        var enriched = snapshot
        // Collected outside body evaluation (this runs from onAppear/onChange
        // action context) so the view hierarchy is settled.
        let collected = accessibilityCache.snapshot()
        enriched.accessibilityElements = collected.elements
        enriched.accessibilityTree = collected.tree
        latestBox.lastSentElements = collected.elements
        latestBox.lastSentTree = collected.tree
        MeasurementStreamClient.shared.send(enriched)
    }

    /// The reported frames, expressed in this scope's coordinate space.
    ///
    /// Split out of the view body because the compiler could not type-check it
    /// inline in reasonable time — a `ViewBuilder` closure is an expensive
    /// place to do work, and this is work.
    private func resolvedMeasurements(in proxy: GeometryProxy) -> [ResolvedMeasurement] {
        let scopeFrame = proxy.frame(in: .global)
        let reported: [GlobalMeasurement] = store.reported.values.sorted { $0.id < $1.id }
        return reported.map { item in
            // Global back into the scope's own space, which is what a
            // measurement is expressed in and what the overlay draws with.
            let frame = item.globalFrame.offsetBy(dx: -scopeFrame.minX, dy: -scopeFrame.minY)
            return ResolvedMeasurement(
                group: item.group,
                role: item.role,
                frame: frame,
                metadata: item.metadata,
                callSite: item.callSite
            )
        }
    }

    private func makeSnapshot(
        measurements: [ResolvedMeasurement],
        proxy: GeometryProxy
    ) -> MeasurementSnapshot {
        let insets = proxy.safeAreaInsets
        return MeasurementSnapshot(
            appName: Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? ProcessInfo.processInfo.processName,
            bundleID: Bundle.main.bundleIdentifier ?? "",
            screenSize: Self.screenSize,
            screenScale: Self.screenScale,
            scopeFrame: proxy.frame(in: .global),
            safeAreaInsets: StreamInsets(
                top: insets.top,
                leading: insets.leading,
                bottom: insets.bottom,
                trailing: insets.trailing
            ),
            measurements: measurements,
            // Read as the snapshot is assembled, so the values are the ones
            // the app is showing rather than the ones it was showing when a
            // tweak first registered.
            tweaks: TweakRegistry.shared.current
        )
    }

    private static var screenSize: CGSize {
        #if canImport(UIKit)
        return UIScreen.main.bounds.size
        #else
        return .zero
        #endif
    }

    private static var screenScale: CGFloat {
        #if canImport(UIKit)
        return UIScreen.main.scale
        #else
        return 2
        #endif
    }

    private var toolbar: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                MeasureToolbarView(
                    configuration: Binding(
                        get: { configuration },
                        set: { configurationOverride = $0 }
                    ),
                    isSelectionEnabled: Binding(
                        get: { isSelectionEnabled },
                        set: { selectionEnabledOverride = $0 }
                    ),
                    selection: $selection
                )
            }
        }
        .padding(12)
    }
}

#endif
