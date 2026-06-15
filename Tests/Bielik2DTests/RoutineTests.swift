import Testing
@testable import Bielik2D

@Test func routineRunsStepsInOrderInOneFrame() {
    var log: [String] = []
    let r = Routine {
        Run { log.append("a") }
        Run { log.append("b") }
        Run { log.append("c") }
    }
    if case .done = r.step(0.016) {} else { Issue.record("expected done") }
    #expect(log == ["a", "b", "c"])
}

@Test func routineWaitsBetweenSteps() {
    var fired = false
    let r = Routine {
        Wait(0.5)
        Run { fired = true }
    }
    #expect(r.step(0.2) == .running)
    #expect(!fired)
    if case .done = r.step(0.4) {} else { Issue.record("expected done") }
    #expect(fired)
}

@Test func routineForwardsOverflowToTheNextStepSameFrame() {
    let r = Routine {
        Wait(0.1)
        Wait(0.1)
    }
    if case let .done(overflow) = r.step(0.25) {
        #expect(abs(overflow - 0.05) < 1e-9)
    } else {
        Issue.record("expected done")
    }
}

@Test func emptyRoutineCompletesImmediately() {
    let r = Routine {}
    #expect(r.step(0.016) == .done(overflow: 0.016))
}

@Test func parallelCompletesOnlyWhenAllChildrenDone() {
    let p = Parallel {
        Wait(0.2)
        Wait(0.5)
    }
    #expect(p.step(0.2) == .running)  // short one done, long one still going
    if case .done = p.step(0.3) {} else { Issue.record("expected done") }
}

@Test func routineCanNestParallel() {
    var done = false
    let r = Routine {
        Parallel {
            Wait(0.1)
            Wait(0.2)
        }
        Run { done = true }
    }
    #expect(r.step(0.1) == .running)
    _ = r.step(0.1)
    #expect(done)
}

@Test func repeatLoopsAFiniteCount() {
    var n = 0
    let r = Repeat(3) {
        Run { n += 1 }
    }
    _ = r.step(0.016)
    _ = r.step(0.016)
    #expect(n == 2)
    if case .done = r.step(0.016) {} else { Issue.record("expected done on 3rd") }
    #expect(n == 3)
}

@Test func repeatConsumesTimeAcrossIterationsInAFatFrame() {
    let r = Repeat(2) {
        Wait(0.1)
    }
    if case let .done(overflow) = r.step(0.25) {
        #expect(abs(overflow - 0.05) < 1e-9)
    } else {
        Issue.record("expected done")
    }
}

@Test func repeatForeverNeverCompletes() {
    var n = 0
    let r = Repeat {
        Run { n += 1 }
    }
    for _ in 0..<5 { #expect(r.step(0.016) == .running) }
    #expect(n == 5)
}

@Test func routineResetReplaysFromTheStart() {
    var n = 0
    let r = Routine {
        Run { n += 1 }
        Wait(0.1)
    }
    _ = r.step(0.2)
    #expect(n == 1)
    r.reset()
    _ = r.step(0.2)
    #expect(n == 2)
}
