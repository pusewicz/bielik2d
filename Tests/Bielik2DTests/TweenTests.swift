import Testing
@testable import Bielik2D

private final class Mover {
    var x: Float = 0
    var pos: SIMD2<Float> = .zero
    var tint: Color = .white
}

@Test func linearTweenReachesTargetOverDuration() {
    let m = Mover()
    let tw = Tween(m, \.x, to: 100, over: 1.0)
    #expect(tw.step(0.5) == .running)
    #expect(m.x == 50)
    if case .done = tw.step(0.5) {} else { Issue.record("expected done") }
}

@Test func tweenSnapsExactlyToTargetOnCompletion() {
    let m = Mover()
    let tw = Tween(m, \.x, to: 100, over: 0.3)
    _ = tw.step(0.1)
    _ = tw.step(0.1)
    _ = tw.step(0.1)  // float dust could leave 99.9999; completion must snap
    #expect(m.x == 100)
}

@Test func tweenAppliesTheEasingCurve() {
    let m = Mover()
    let tw = Tween(m, \.x, to: 100, over: 1.0, ease: .inQuad)
    _ = tw.step(0.5)  // inQuad(0.5) == 0.25 → 25
    #expect(abs(m.x - 25) < 1e-4)
}

@Test func tweenForwardsOverflowWhenItCompletes() {
    let m = Mover()
    let tw = Tween(m, \.x, to: 10, over: 0.2)
    if case let .done(overflow) = tw.step(0.5) {
        #expect(abs(overflow - 0.3) < 1e-9)
    } else {
        Issue.record("expected done")
    }
}

@Test func zeroDurationTweenSnapsImmediately() {
    let m = Mover()
    let tw = Tween(m, \.x, to: 42, over: 0)
    if case let .done(overflow) = tw.step(0.016) {
        #expect(overflow == 0.016)
    } else {
        Issue.record("expected done")
    }
    #expect(m.x == 42)
}

@Test func tweenWithADeadTargetCompletesQuietly() {
    var m: Mover? = Mover()
    let tw = Tween(m!, \.x, to: 10, over: 1.0)
    m = nil
    #expect(tw.step(0.5) == .done(overflow: 0.5))
}

@Test func tweenResetRecapturesTheStartValue() {
    let m = Mover()
    let tw = Tween(m, \.x, to: 100, over: 1.0)
    _ = tw.step(1.0)        // m.x == 100
    tw.reset()
    _ = tw.step(0.5)        // now eases 100 → 100, stays put
    #expect(m.x == 100)
    m.x = 0
    tw.reset()
    _ = tw.step(0.5)        // re-captures from 0 → 50
    #expect(m.x == 50)
}

@Test func tweenInterpolatesCompoundValues() {
    let m = Mover()
    m.pos = SIMD2(0, 0)
    m.tint = .white
    let move = Tween(m, \.pos, to: SIMD2(10, 20), over: 1.0)
    let fade = Tween(m, \.tint, to: .clear, over: 1.0)
    _ = move.step(0.5)
    _ = fade.step(0.5)
    #expect(m.pos == SIMD2<Float>(5, 10))
    #expect(m.tint.a == 0.5)
}
