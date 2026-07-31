import CoreGraphics
import Foundation

/// A rendered picture of the app's screen, sent app → companion.
///
/// The companion has always had a picture: it asks `simctl` for one. That
/// works precisely as long as the thing being measured is a simulator, which
/// is the assumption this exists to remove — there is no `simctl` for a phone
/// on the end of a cable. Having the app render its own screen makes the
/// canvas independent of how the app is being run.
///
/// Lossless on purpose. The contrast rule reads the colours of the pixels that
/// were actually drawn, so a lossy frame would not merely look worse, it would
/// change the reported contrast ratio and with it whether a finding exists.
/// A frame is large and rare; a wrong accessibility verdict is neither.
public struct ScreenFrame: Codable, Equatable, Sendable {
    /// Size in points.
    public let width: CGFloat
    public let height: CGFloat

    /// The device's scale, so the companion can map the pixels back to points.
    public let scale: CGFloat

    /// PNG data. `Data` travels as base64 in the JSON line, which costs a
    /// third more bytes than the file on disk — worth it to keep one framing
    /// rule for every message on this socket.
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
