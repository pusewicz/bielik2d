/// A token for a job handed to `Flow.run`. Lets the caller `cancel()` it early or
/// poll `isDone`.
public final class RoutineHandle {
    let step: FlowStep
    private(set) var cancelled = false
    public internal(set) var isDone = false

    init(_ step: FlowStep) { self.step = step }

    public func cancel() { cancelled = true }
}

/// Owns the live tweens and coroutines and advances them each frame. `App`
/// installs one as `Flow.current` and drives it from `App.update`, so game code
/// just calls `app.flow.run { … }` (or the bare `Flow.current`).
public final class Flow {
    /// The ambient runner `App` installs, mirroring `Renderer.current` /
    /// `Audio.current`. `nonisolated(unsafe)` for the same single-threaded reason.
    public static nonisolated(unsafe) var current: Flow?

    private var jobs: [RoutineHandle] = []

    public init() {}

    /// Jobs still running.
    public var activeCount: Int { jobs.count }

    @discardableResult
    public func run(_ step: FlowStep) -> RoutineHandle {
        let h = RoutineHandle(step)
        jobs.append(h)
        return h
    }

    @discardableResult
    public func run(@FlowBuilder _ build: () -> [FlowStep]) -> RoutineHandle {
        run(Routine(build()))
    }

    /// Convenience for the single-tween case.
    @discardableResult
    public func tween<Root: AnyObject, Value: Lerpable>(
        _ target: Root,
        _ keyPath: ReferenceWritableKeyPath<Root, Value>,
        to: Value,
        over duration: Double,
        ease: Easing = .linear
    ) -> RoutineHandle {
        run(Tween(target, keyPath, to: to, over: duration, ease: ease))
    }

    /// Advance every live job by `dt`. Jobs scheduled while stepping run next
    /// frame (they're not in this frame's snapshot); finished and cancelled jobs
    /// are dropped.
    public func update(_ dt: Double) {
        guard !jobs.isEmpty else { return }
        let active = jobs
        for h in active {
            if h.cancelled {
                h.isDone = true
                continue
            }
            if case .done = h.step.step(dt) { h.isDone = true }
        }
        jobs.removeAll { $0.isDone }
    }

    /// Cancel and drop everything.
    public func stopAll() {
        for h in jobs { h.isDone = true }
        jobs.removeAll()
    }
}
