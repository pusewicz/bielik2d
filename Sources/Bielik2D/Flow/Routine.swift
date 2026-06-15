/// Result builder that collects the steps inside a `Routine { … }` / `Parallel { … }`
/// / `Repeat { … }` block into a `[FlowStep]`.
@resultBuilder
public enum FlowBuilder {
    public static func buildExpression(_ step: FlowStep) -> [FlowStep] { [step] }
    public static func buildBlock(_ parts: [FlowStep]...) -> [FlowStep] { parts.flatMap { $0 } }
    public static func buildArray(_ parts: [[FlowStep]]) -> [FlowStep] { parts.flatMap { $0 } }
    public static func buildOptional(_ part: [FlowStep]?) -> [FlowStep] { part ?? [] }
    public static func buildEither(first part: [FlowStep]) -> [FlowStep] { part }
    public static func buildEither(second part: [FlowStep]) -> [FlowStep] { part }
}

/// Runs its steps one after another. Leftover `dt` from a finished step flows
/// straight into the next one in the same frame, so a chain of short waits or
/// instant `Run`s doesn't drip across frames.
public final class Routine: FlowStep {
    private let steps: [FlowStep]
    private var index = 0

    public init(_ steps: [FlowStep]) { self.steps = steps }
    public convenience init(@FlowBuilder _ build: () -> [FlowStep]) { self.init(build()) }

    public func step(_ dt: Double) -> StepResult {
        var remaining = dt
        while index < steps.count {
            switch steps[index].step(remaining) {
            case .running:
                return .running
            case .done(let overflow):
                index += 1
                remaining = overflow
            }
        }
        return .done(overflow: remaining)
    }

    public func reset() {
        index = 0
        for s in steps { s.reset() }
    }
}

/// Runs all its steps at once; completes the frame the last one finishes.
public final class Parallel: FlowStep {
    private let steps: [FlowStep]
    private var finished: [Bool]

    public init(_ steps: [FlowStep]) {
        self.steps = steps
        self.finished = Array(repeating: false, count: steps.count)
    }
    public convenience init(@FlowBuilder _ build: () -> [FlowStep]) { self.init(build()) }

    public func step(_ dt: Double) -> StepResult {
        var anyRunning = false
        var anyFinishedNow = false
        var overflow = dt
        for i in steps.indices where !finished[i] {
            switch steps[i].step(dt) {
            case .running:
                anyRunning = true
            case .done(let o):
                finished[i] = true
                anyFinishedNow = true
                overflow = min(overflow, o)  // leftover after the slowest finisher
            }
        }
        if anyRunning { return .running }
        return .done(overflow: anyFinishedNow ? overflow : dt)
    }

    public func reset() {
        for i in finished.indices { finished[i] = false }
        for s in steps { s.reset() }
    }
}

/// Replays a body a fixed number of times, or forever when `count` is nil. A body
/// that consumes no time (e.g. a lone `Run`) advances one iteration per frame so
/// a forever-repeat can't spin the current frame indefinitely.
public final class Repeat: FlowStep {
    private let body: FlowStep
    private let count: Int?
    private var remaining: Int?

    public init(_ count: Int? = nil, @FlowBuilder _ build: () -> [FlowStep]) {
        self.body = Routine(build())
        self.count = count
        self.remaining = count
    }

    public func step(_ dt: Double) -> StepResult {
        var time = dt
        while true {
            switch body.step(time) {
            case .running:
                return .running
            case .done(let overflow):
                if let r = remaining {
                    let next = r - 1
                    if next <= 0 { return .done(overflow: overflow) }
                    remaining = next
                }
                body.reset()
                if overflow >= time { return .running }  // no progress → yield the frame
                time = overflow
            }
        }
    }

    public func reset() {
        remaining = count
        body.reset()
    }
}
