import Testing
@testable import Bielik2D

private final class Mover {
    var x: Float = 0
}

@Test func flowStepsAJobOnUpdate() {
    let flow = Flow()
    let m = Mover()
    flow.tween(m, \.x, to: 100, over: 1.0)
    flow.update(0.5)
    #expect(m.x == 50)
    #expect(flow.activeCount == 1)
}

@Test func flowDropsCompletedJobs() {
    let flow = Flow()
    let m = Mover()
    let h = flow.tween(m, \.x, to: 100, over: 0.5)
    flow.update(0.5)
    #expect(m.x == 100)
    #expect(h.isDone)
    #expect(flow.activeCount == 0)
}

@Test func flowRunsBuilderSequences() {
    let flow = Flow()
    var log: [String] = []
    flow.run {
        Run { log.append("a") }
        Wait(0.2)
        Run { log.append("b") }
    }
    flow.update(0.1)
    #expect(log == ["a"])
    flow.update(0.2)
    #expect(log == ["a", "b"])
    #expect(flow.activeCount == 0)
}

@Test func cancelStopsAJobBeforeItRuns() {
    let flow = Flow()
    var fired = false
    let h = flow.run {
        Wait(0.5)
        Run { fired = true }
    }
    h.cancel()
    flow.update(1.0)
    #expect(!fired)
    #expect(flow.activeCount == 0)
}

@Test func stopAllClearsEveryJob() {
    let flow = Flow()
    let m = Mover()
    flow.tween(m, \.x, to: 100, over: 1.0)
    flow.tween(m, \.x, to: 50, over: 2.0)
    #expect(flow.activeCount == 2)
    flow.stopAll()
    #expect(flow.activeCount == 0)
}

@Test func updateWithNoJobsIsHarmless() {
    let flow = Flow()
    flow.update(0.016)
    #expect(flow.activeCount == 0)
}

@Test func jobScheduledDuringUpdateRunsTheNextFrame() {
    let flow = Flow()
    var inner = false
    flow.run {
        Run { flow.run { Run { inner = true } } }
    }
    flow.update(0.016)
    #expect(!inner)            // the nested job hasn't been stepped yet
    flow.update(0.016)
    #expect(inner)
}
