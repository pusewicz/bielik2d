import Foundation
import Testing
@testable import Bielik2D

// Pure playback-math tests: no GPU, no registry. A frame's image/size is irrelevant
// here, so synthetic frames just carry a duration.
private func anim(_ count: Int, mode: PlayMode, duration: Double = 1.0) -> Animation {
    let frames = (0..<count).map { Frame(imageID: $0, width: 1, height: 1, duration: duration) }
    return Animation(name: "default", frames: frames, mode: mode)
}

@Test func loopAdvancesToTheNextFrame() {
    let c = anim(3, mode: .loop).advanced(AnimationCursor(), by: 1.0)
    #expect(c.frame == 1)
    #expect(c.elapsed == 0)
}

@Test func loopWrapsPastTheLastFrameToTheFirst() {
    let c = anim(3, mode: .loop).advanced(AnimationCursor(frame: 2), by: 1.0)
    #expect(c.frame == 0)
}

@Test func partialTimeAccumulatesWithoutAdvancing() {
    let c = anim(3, mode: .loop).advanced(AnimationCursor(), by: 0.4)
    #expect(c.frame == 0)
    #expect(c.elapsed == 0.4)
}

@Test func aLargeStepSkipsMultipleFrames() {
    let c = anim(4, mode: .loop).advanced(AnimationCursor(), by: 2.5)
    #expect(c.frame == 2)
    #expect(c.elapsed == 0.5)
}

@Test func onceHoldsOnTheLastFrame() {
    let c = anim(3, mode: .once).advanced(AnimationCursor(frame: 2), by: 5.0)
    #expect(c.frame == 2)
}

@Test func pingPongReversesAtTheEnd() {
    let c = anim(3, mode: .pingPong).advanced(AnimationCursor(frame: 2, forward: true), by: 1.0)
    #expect(c.frame == 1)
    #expect(c.forward == false)
}

@Test func pingPongReversesAtTheStart() {
    let c = anim(3, mode: .pingPong).advanced(AnimationCursor(frame: 0, forward: false), by: 1.0)
    #expect(c.frame == 1)
    #expect(c.forward == true)
}

@Test func aSingleFrameAnimationNeverAdvances() {
    let c = anim(1, mode: .loop).advanced(AnimationCursor(), by: 100)
    #expect(c.frame == 0)
}

@Test func zeroDurationFramesNeverAdvance() {
    let c = anim(3, mode: .loop, duration: 0).advanced(AnimationCursor(), by: 100)
    #expect(c.frame == 0)
}
