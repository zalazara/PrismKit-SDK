import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if DEBUG

/// Whether an enclosing measured view is being drawn on its own, in which case
/// this one — being nested inside it — must take up its space without drawing
/// anything.
///
/// The environment and not a flag on a store: the question is "am I inside the
/// view being drawn", and only descendants of the target ever see it set.
struct HidesNestedMeasurementsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var prismHidesNestedMeasurements: Bool {
        get { self[HidesNestedMeasurementsKey.self] }
        set { self[HidesNestedMeasurementsKey.self] = newValue }
    }
}

/// Draws one instrumented component on its own, off screen.
///
/// Off screen matters. Hiding the nested measured views in the live hierarchy,
/// taking a picture and putting them back makes the app visibly flicker while
/// a debugging tool rearranges it. `ImageRenderer` draws without touching what
/// is on screen.
///
/// The cost is that the view is drawn out of its context: it gets the size the
/// measurement recorded rather than the one its parent would have given it.
/// For a picture of what a component looks like alone that is the intent.
/// Isolated to the main actor rather than merely documented as main-thread
/// only. `ImageRenderer` is main-actor isolated itself, and the alternative —
/// asserting isolation at the call site — needs an API that did not exist
/// until iOS 17, while this package supports iOS 15.
@MainActor
enum SoloRenderRegistry {

    /// Renders keyed by measurement id ("group#role").
    ///
    /// Rebuilt as views update rather than captured once, because a view value
    /// captured at `onAppear` stops being what the app is showing the moment
    /// any state changes, and a stale picture in a debugging tool is worse
    /// than an absent one.
    private static var renderers: [String: (CGSize) -> Data?] = [:]

    static func register(id: String, renderer: @escaping (CGSize) -> Data?) {
        renderers[id] = renderer
    }

    static func forget(id: String) {
        renderers.removeValue(forKey: id)
    }

    /// Draws the named components. Silently skips ids it has never seen and
    /// ids whose render fails — the caller falls back to a crop of the screen,
    /// which is a worse picture rather than none.
    /// Returns the components that were drawn, and separately the ones the app
    /// refused. The two are kept apart because they mean different things to
    /// whoever asked: "your app declined this one" is a setting somebody
    ///chose, while a silent absence is a component that has gone, or an OS
    /// that cannot draw off screen.
    static func render(
        ids: [String],
        sizes: [String: CGSize],
        scale: CGFloat
    ) -> (rendered: [ComponentRender], refused: [String]) {
        var rendered: [ComponentRender] = []
        var refused: [String] = []

        for id in ids {
            if let policy = PrismKit.rendersComponent, !policy(id) {
                refused.append(id)
                continue
            }
            guard let renderer = renderers[id], let size = sizes[id] else { continue }
            guard size.width > 0, size.height > 0 else { continue }
            guard let png = renderer(size) else { continue }
            rendered.append(
                ComponentRender(id: id, width: size.width, height: size.height, scale: scale, png: png)
            )
        }
        return (rendered, refused)
    }
}

#if canImport(UIKit)

/// Draws a SwiftUI view to PNG without putting it on screen.
///
/// iOS 16 and up. On iOS 15 there is no way to rasterise a SwiftUI view
/// off screen, and the alternatives all mutate the live hierarchy, so the
/// honest answer there is no solo render — the companion keeps using crops
/// and says so.
@available(iOS 16.0, *)
@MainActor
func prismRenderOffscreen(_ view: some View, size: CGSize, scale: CGFloat) -> Data? {
    let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
    renderer.scale = scale
    // Native scale, matching the screen frame, so the companion never has to
    // reconcile two different pixel densities when it draws them together.
    guard let image = renderer.uiImage else { return nil }
    return image.pngData()
}

#endif

#endif
