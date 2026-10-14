import Foundation

public enum ChavitoLoop: Sendable, Hashable {
    case blink
    case bob
    case thinkingTilt
}

/// What Chavito looks like at one instant; the view just draws it.
public struct ChavitoPose: Equatable, Sendable {
    /// 1 = eyes fully open, 0 = shut.
    public var eyeOpenness: Double
    /// Vertical offset in art units, positive is down.
    public var bobOffset: Double
    public var tiltDegrees: Double
    public var scale: Double

    public init(eyeOpenness: Double = 1, bobOffset: Double = 0, tiltDegrees: Double = 0, scale: Double = 1) {
        self.eyeOpenness = eyeOpenness
        self.bobOffset = bobOffset
        self.tiltDegrees = tiltDegrees
        self.scale = scale
    }

    public static let rest = ChavitoPose()
}

/// Pure function of time: no timers, no state. Under Reduce Motion every pose is `.rest`.
public struct ChavitoMotion: Equatable, Sendable {
    public static let blinkPeriod = 4.2
    public static let blinkOffset = 3.6
    public static let blinkDuration = 0.18
    public static let bobPeriod = 3.2
    public static let bobAmplitude = 2.0
    public static let tiltPeriod = 5.0
    public static let tiltMaxDegrees = 3.0
    public static let reactionDuration = 0.4
    public static let reactionPeakScale = 0.06

    public var expression: ChavitoExpression
    public var reduceMotion: Bool

    public init(expression: ChavitoExpression, reduceMotion: Bool) {
        self.expression = expression
        self.reduceMotion = reduceMotion
    }

    public var activeLoops: Set<ChavitoLoop> {
        guard !reduceMotion else { return [] }
        var loops: Set<ChavitoLoop> = [.bob]
        if expression.hasOpenEyes { loops.insert(.blink) }
        if expression == .thinking { loops.insert(.thinkingTilt) }
        return loops
    }

    public var isAnimated: Bool { !activeLoops.isEmpty }

    public static func isReacting(elapsed: TimeInterval) -> Bool {
        elapsed >= 0 && elapsed < reactionDuration
    }

    /// - Parameters:
    ///   - time: seconds since the view appeared.
    ///   - reactionElapsed: seconds since the expression last changed, if a pop reaction is running.
    public func pose(at time: TimeInterval, reactionElapsed: TimeInterval? = nil) -> ChavitoPose {
        guard !reduceMotion else { return .rest }
        let loops = activeLoops
        var pose = ChavitoPose.rest
        if loops.contains(.blink) { pose.eyeOpenness = Self.eyeOpenness(at: time) }
        if loops.contains(.bob) { pose.bobOffset = Self.bobAmplitude * sin(2 * .pi * time / Self.bobPeriod) }
        if loops.contains(.thinkingTilt) {
            pose.tiltDegrees = Self.tiltMaxDegrees * sin(2 * .pi * time / Self.tiltPeriod)
        }
        if let elapsed = reactionElapsed, Self.isReacting(elapsed: elapsed) {
            pose.scale = 1 + Self.reactionPeakScale * sin(.pi * elapsed / Self.reactionDuration)
        }
        return pose
    }

    private static func eyeOpenness(at time: TimeInterval) -> Double {
        let phase = (time - blinkOffset).truncatingRemainder(dividingBy: blinkPeriod)
        let into = phase < 0 ? phase + blinkPeriod : phase
        guard into < blinkDuration else { return 1 }
        return max(0, 1 - sin(.pi * into / blinkDuration))
    }
}
