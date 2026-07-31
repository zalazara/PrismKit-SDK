import Foundation

/// A liveness probe sent companion → app.
///
/// The socket staying open says almost nothing about the app: a process
/// stopped at a breakpoint, wedged on its main thread, or busy in a long
/// synchronous call keeps its TCP connection perfectly alive while nothing on
/// screen will ever change again. From the companion that is indistinguishable
/// from a screen that simply is not moving, and the two call for opposite
/// reactions — wait, or go look at the debugger.
///
/// The probe is answered on the app's main queue, which is what makes it worth
/// sending. A reply from the network queue would prove only that the network
/// queue is running, which was never in doubt.
///
/// Distinct in shape from `OverrideMessage` and `MeasurementSnapshot` so
/// neither side has to guess which message it is holding, and so an older peer
/// that has never heard of probes simply fails to decode one and carries on.
public struct PingMessage: Codable, Equatable, Sendable {
    /// Identifies this probe, so a late reply to an abandoned one is not
    /// mistaken for a prompt reply to the current one.
    public let ping: String

    public init(ping: String) {
        self.ping = ping
    }
}

/// The app's answer, echoing the probe's id.
public struct PongMessage: Codable, Equatable, Sendable {
    public let pong: String

    public init(pong: String) {
        self.pong = pong
    }
}
