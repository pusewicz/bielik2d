/// The result of advancing a `FlowStep` by one frame's `dt`.
public enum StepResult: Equatable {
    /// Still in progress; call `step` again next frame.
    case running
    /// Finished this frame. `overflow` is the leftover `dt` after the step
    /// completed — a container (`Routine`) hands it to the next step so a fast or
    /// zero-duration step doesn't burn a whole frame (mirrors `Animation.advanced`).
    case done(overflow: Double)
}

/// One unit of frame-stepped game-logic flow: a tween, a wait, a callback, or a
/// container of those. Reference type so the runner can hold and re-run it; a
/// `Routine` restarts its children by calling `reset()`.
public protocol FlowStep: AnyObject {
    /// Advance by `dt` seconds.
    func step(_ dt: Double) -> StepResult
    /// Return to the pre-run state so the step can play again (used by `Repeat`).
    func reset()
}

extension FlowStep {
    public func reset() {}
}

/// Pauses a sequence for `seconds`, then completes.
public final class Wait: FlowStep {
    private let duration: Double
    private var elapsed: Double = 0

    public init(_ seconds: Double) { self.duration = seconds }

    public func step(_ dt: Double) -> StepResult {
        elapsed += dt
        guard elapsed >= duration else { return .running }
        return .done(overflow: elapsed - duration)
    }

    public func reset() { elapsed = 0 }
}

/// Fires a side effect once, then completes the same frame — forwarding the full
/// `dt` so the next step in a routine runs without waiting a frame.
public final class Run: FlowStep {
    private let action: () -> Void
    private var fired = false

    public init(_ action: @escaping () -> Void) { self.action = action }

    public func step(_ dt: Double) -> StepResult {
        if !fired {
            action()
            fired = true
        }
        return .done(overflow: dt)
    }

    public func reset() { fired = false }
}
