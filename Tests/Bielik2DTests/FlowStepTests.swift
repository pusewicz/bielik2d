import Testing
@testable import Bielik2D

@Test func waitIsRunningUntilItsDurationElapses() {
    let w = Wait(0.3)
    #expect(w.step(0.1) == .running)
    #expect(w.step(0.1) == .running)
    // 0.3 reached; finishes with ~no leftover (float dust aside).
    if case let .done(overflow) = w.step(0.1) {
        #expect(abs(overflow) < 1e-9)
    } else {
        Issue.record("expected done")
    }
}

@Test func waitForwardsOverflowPastItsDuration() {
    let w = Wait(0.3)
    if case let .done(overflow) = w.step(0.5) {
        #expect(abs(overflow - 0.2) < 1e-9)
    } else {
        Issue.record("expected done")
    }
}

@Test func zeroDurationWaitFinishesImmediately() {
    let w = Wait(0)
    #expect(w.step(0.016) == .done(overflow: 0.016))
}

@Test func waitResetReplaysFromZero() {
    let w = Wait(0.2)
    _ = w.step(0.2)
    w.reset()
    #expect(w.step(0.1) == .running)
}

@Test func runFiresOnceAndForwardsFullDt() {
    var count = 0
    let r = Run { count += 1 }
    #expect(r.step(0.016) == .done(overflow: 0.016))
    #expect(count == 1)
}

@Test func runResetReArmsTheAction() {
    var count = 0
    let r = Run { count += 1 }
    _ = r.step(0.01)
    r.reset()
    _ = r.step(0.01)
    #expect(count == 2)
}
