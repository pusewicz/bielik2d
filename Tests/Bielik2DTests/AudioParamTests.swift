import Testing
@testable import Bielik2D

// Pan/pitch clamping shared by the native and web audio backends. Pure math,
// no device — pitch never reaches 0 because web `playbackRate` must be > 0.

@Test func clampPanFloorsAtNegativeOne() {
    #expect(AudioMath.clampPan(-2) == -1)
}

@Test func clampPanCeilsAtPositiveOne() {
    #expect(AudioMath.clampPan(2) == 1)
}

@Test func clampPanPassesThroughInRange() {
    #expect(AudioMath.clampPan(0) == 0)
    #expect(AudioMath.clampPan(0.5) == 0.5)
}

@Test func clampPitchNeverReachesZero() {
    #expect(AudioMath.clampPitch(0) == 0.0001)
    #expect(AudioMath.clampPitch(-3) == 0.0001)
}

@Test func clampPitchPassesThroughPositive() {
    #expect(AudioMath.clampPitch(1) == 1)
    #expect(AudioMath.clampPitch(2.5) == 2.5)
}
