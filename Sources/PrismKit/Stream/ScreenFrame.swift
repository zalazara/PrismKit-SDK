import CoreGraphics
import Foundation

/// A rendered picture of the app's screen, sent app → companion.
///
/// The companion normally asks `simctl` for a picture, which works exactly as
/// long as the thing being measured is a simulator. There is no `simctl` for a
/// phone on a cable, so the app rendering its own screen is what makes the
/// canvas independent of how the app is run.
///
/// Lossless on purpose: the contrast rule reads the colours actually drawn, so
/// a lossy frame would change the reported ratio and with it whether a finding
/// exists. A frame is large and rare; a wrong accessibility verdict is not.
public struct ScreenFrame: Codable, Equatable, Sendable {
    /// Size in points.
    public let width: CGFloat
    public let height: CGFloat

    /// The device's scale, so the companion can map the pixels back to points.
    public let scale: CGFloat

    /// PNG data, base64 in the JSON line. A third more bytes than the file on
    /// disk, in exchange for one framing rule on the whole socket.
    public let png: Data

    public init(width: CGFloat, height: CGFloat, scale: CGFloat, png: Data) {
        self.width = width
        self.height = height
        self.scale = scale
        self.png = png
    }
}

/// Companion → app: "render your screen and send it".
///
/// Pulled rather than pushed. Rendering the screen costs the app real time on
/// its main thread, and only the Mac knows whether anyone is looking — whether
/// the window is visible, whether the preview is paused, whether a saved
/// session is open instead. An app deciding on its own to render at some fixed
/// rate would burn that time whether or not it was wanted, which is the
/// mistake that made the companion's earlier capture loop heat the machine up.
public struct FrameRequestMessage: Codable, Equatable, Sendable {
    /// Identifies the request so a frame can be matched to it.
    public let requestFrame: String

    public init(requestFrame: String) {
        self.requestFrame = requestFrame
    }
}

/// App → companion: the frame that was asked for.
public struct ScreenFrameMessage: Codable, Equatable, Sendable {
    /// Echoes the request's id.
    public let id: String
    public let frame: ScreenFrame

    public init(id: String, frame: ScreenFrame) {
        self.id = id
        self.frame = frame
    }
}
