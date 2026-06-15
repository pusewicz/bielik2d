/// Animates a property of a reference-type target from its current value to `to`
/// over `duration` seconds, shaped by an `Easing`. The start value is captured
/// lazily on the first `step`, so a tween created ahead of time begins from
/// wherever the property is when it actually runs. The target is held weakly: if
/// it deallocates mid-tween the tween simply completes.
///
///     flow.run(Tween(player, \.position, to: SIMD2(200, 0), over: 0.5, ease: .outBack))
public final class Tween<Root: AnyObject, Value: Lerpable>: FlowStep {
    private weak var target: Root?
    private let keyPath: ReferenceWritableKeyPath<Root, Value>
    private let to: Value
    private let duration: Double
    private let easing: Easing

    private var from: Value?
    private var elapsed: Double = 0

    public init(
        _ target: Root,
        _ keyPath: ReferenceWritableKeyPath<Root, Value>,
        to: Value,
        over duration: Double,
        ease easing: Easing = .linear
    ) {
        self.target = target
        self.keyPath = keyPath
        self.to = to
        self.duration = duration
        self.easing = easing
    }

    public func step(_ dt: Double) -> StepResult {
        guard let target else { return .done(overflow: dt) }
        if from == nil { from = target[keyPath: keyPath] }
        elapsed += dt

        if duration <= 0 || elapsed >= duration {
            target[keyPath: keyPath] = to  // snap exactly, no float drift
            return .done(overflow: max(0, elapsed - duration))
        }

        let t = easing.value(at: Float(elapsed / duration))
        target[keyPath: keyPath] = Value.lerp(from!, to, t)
        return .running
    }

    public func reset() {
        from = nil
        elapsed = 0
    }
}
