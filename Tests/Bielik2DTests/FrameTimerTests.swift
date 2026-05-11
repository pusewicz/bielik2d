import Testing
@testable import Bielik2D

@Test func fpsFromSteadySixtyHzSamples() {
    var t = FrameTimer(windowSize: 60)
    for _ in 0..<60 { t.record(deltaSeconds: 1.0 / 60.0) }
    #expect(abs(t.fps - 60) < 0.1)
    #expect(abs(t.averageFrameSeconds - (1.0 / 60.0)) < 1e-6)
}

@Test func fpsAveragesAcrossWindow() {
    var t = FrameTimer(windowSize: 4)
    // 30 fps then 120 fps, average should be the mean delta = (1/30 + 1/120) / 2
    t.record(deltaSeconds: 1.0 / 30.0)
    t.record(deltaSeconds: 1.0 / 120.0)
    let expectedAvg = (1.0 / 30.0 + 1.0 / 120.0) / 2.0
    #expect(abs(t.averageFrameSeconds - expectedAvg) < 1e-6)
    #expect(abs(t.fps - 1.0 / expectedAvg) < 1e-3)
}

@Test func frameTimerWindowsForgetsOldestSamples() {
    var t = FrameTimer(windowSize: 3)
    t.record(deltaSeconds: 1.0)   // would dominate the average if kept
    t.record(deltaSeconds: 0.01)
    t.record(deltaSeconds: 0.01)
    t.record(deltaSeconds: 0.01)  // pushes the 1.0 sample out
    #expect(t.averageFrameSeconds < 0.05)
}

@Test func frameTimerWithNoSamplesReturnsZero() {
    let t = FrameTimer()
    #expect(t.averageFrameSeconds == 0)
    #expect(t.fps == 0)
}
