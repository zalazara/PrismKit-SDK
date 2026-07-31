import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// Rendering the screen and putting it on a socket is exactly the kind of thing
// a shipping app must not do, so it lives behind the same wall as the rest.
#if DEBUG

/// Renders the app's own screen, so the companion has a picture that does not
/// come from `simctl`.
///
/// Split into a capture and an encode because they belong on different
/// threads. Reading the view hierarchy has to happen on the main thread;
/// compressing a 3x screen to PNG takes long enough that doing it there too
/// would show up as a stutter in the app being measured — and an instrument
/// that disturbs what it measures is worth less than one that is a frame late.
enum ScreenRenderer {

    #if canImport(UIKit)

    /// Captures the foreground window at the device's own scale.
    ///
    /// Native scale rather than something smaller because capturing at a
    /// reduced scale is not actually cheaper — `drawHierarchy` is at its
    /// fastest at the scale the screen already is, and asking for less trades
    /// fidelity for nothing. It is also the scale the contrast rule needs in
    /// order to read real pixels.
    ///
    /// Must be called on the main thread.
    static func capture() -> (image: UIImage, scale: CGFloat)? {
        guard let window = foregroundWindow else { return nil }
        let bounds = window.bounds
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = window.screen.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)

        let image = renderer.image { _ in
            // `afterScreenUpdates: false` draws what is already on screen
            // instead of forcing a layout pass first. Forcing one from a
            // debugging tool would let the tool change what it is measuring,
            // and a frame that is one commit old is not a problem worth that.
            window.drawHierarchy(in: bounds, afterScreenUpdates: false)
        }
        return (image, format.scale)
    }

    /// Compresses a captured screen. Safe off the main thread.
    static func encode(_ capture: (image: UIImage, scale: CGFloat)) -> ScreenFrame? {
        guard let png = capture.image.pngData() else { return nil }
        return ScreenFrame(
            width: capture.image.size.width,
            height: capture.image.size.height,
            scale: capture.scale,
            png: png
        )
    }

    /// The window actually on screen. `UIApplication.windows` is deprecated and
    /// on a multi-scene app it answers a different question than the one being
    /// asked, which is "the one the person is looking at".
    private static var foregroundWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }

        let windows = (scenes.isEmpty
            ? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            : scenes).flatMap(\.windows)

        return windows.first(where: \.isKeyWindow) ?? windows.first
    }

    #endif
}

#endif
