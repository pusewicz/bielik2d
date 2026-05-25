import Testing
@testable import Bielik2D

// Pure audio math: no mixer, no device.

@Test func panCenterIsFullOnBothChannels() {
    let g = AudioMath.panGains(0)
    #expect(g.left == 1)
    #expect(g.right == 1)
}

@Test func panHardLeftSilencesTheRightChannel() {
    let g = AudioMath.panGains(-1)
    #expect(g.left == 1)
    #expect(g.right == 0)
}

@Test func panHardRightSilencesTheLeftChannel() {
    let g = AudioMath.panGains(1)
    #expect(g.left == 0)
    #expect(g.right == 1)
}

@Test func panClampsBeyondRange() {
    #expect(AudioMath.panGains(-2).right == 0)
    #expect(AudioMath.panGains(2).left == 0)
}

@Test func effectiveGainScalesByMasterAndFloorsAtZero() {
    #expect(AudioMath.effectiveGain(volume: 0.5, master: 0.5) == 0.25)
    #expect(AudioMath.effectiveGain(volume: -1, master: 1) == 0)
    #expect(AudioMath.effectiveGain(volume: 1, master: -1) == 0)
}
