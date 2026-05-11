import CSDL3

/// Rolling-window FPS / frame-time tracker. Pure data — feed it deltas with
/// `record(deltaSeconds:)` (typically from `Clock.tickSeconds()`) and read
/// `fps` or `averageFrameSeconds`.
public struct FrameTimer {
    public let windowSize: Int
    private var samples: [Double] = []
    private var head: Int = 0
    private var count: Int = 0
    private var sum: Double = 0

    public init(windowSize: Int = 60) {
        self.windowSize = max(1, windowSize)
        self.samples = Array(repeating: 0, count: self.windowSize)
    }

    public mutating func record(deltaSeconds: Double) {
        if count == windowSize {
            sum -= samples[head]
        } else {
            count += 1
        }
        samples[head] = deltaSeconds
        sum += deltaSeconds
        head = (head + 1) % windowSize
    }

    public var averageFrameSeconds: Double {
        guard count > 0 else { return 0 }
        return sum / Double(count)
    }

    public var fps: Double {
        let avg = averageFrameSeconds
        return avg > 0 ? 1.0 / avg : 0
    }
}

/// Wraps `SDL_GetPerformanceCounter` so callers can pull frame deltas in seconds.
public final class Clock {
    private let frequency: UInt64
    private var lastCounter: UInt64

    public init() {
        self.frequency = SDL_GetPerformanceFrequency()
        self.lastCounter = SDL_GetPerformanceCounter()
    }

    @discardableResult
    public func tickSeconds() -> Double {
        let now = SDL_GetPerformanceCounter()
        let delta = Double(now - lastCounter) / Double(frequency)
        lastCounter = now
        return delta
    }
}
