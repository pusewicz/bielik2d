import Testing
import simd
@testable import Bielik2D

private func apply(_ m: simd_float4x4, _ v: SIMD4<Float>) -> SIMD4<Float> {
    m * v
}

@Test func defaultCameraMapsScreenCornersToClipSpace() {
    let cam = Camera(viewportSize: SIMD2(1280, 720))
    let vp = cam.viewProjection
    // World top-left (screen-style) → clip top-left in Metal NDC = (-1, +1).
    let topLeft = apply(vp, SIMD4(0, 0, 0, 1))
    #expect(abs(topLeft.x + 1) < 1e-5)
    #expect(abs(topLeft.y - 1) < 1e-5)
    // World bottom-right → clip bottom-right = (+1, -1).
    let bottomRight = apply(vp, SIMD4(1280, 720, 0, 1))
    #expect(abs(bottomRight.x - 1) < 1e-5)
    #expect(abs(bottomRight.y + 1) < 1e-5)
}

@Test func movingCameraShiftsWorldOpposite() {
    // If the camera moves +100 right, the world appears -100 to the left.
    var cam = Camera(viewportSize: SIMD2(1280, 720))
    cam.view = .translation(x: -100, y: 0)  // world is offset by -100, equivalent to camera at +100
    let vp = cam.viewProjection
    let originAfter = apply(vp, SIMD4(0, 0, 0, 1))
    // (0,0) in world is shifted to (-100, 0), which in clip space is leftward of -1.
    #expect(originAfter.x < -1)
}

@Test func screenToWorldIsIdentityForDefaultCamera() {
    let cam = Camera(viewportSize: SIMD2(800, 600))
    let world = cam.screenToWorld(SIMD2<Float>(123, 45))
    #expect(abs(world.x - 123) < 1e-4)
    #expect(abs(world.y - 45) < 1e-4)
}

@Test func screenToWorldRecoversAProjectedWorldPoint() {
    var cam = Camera(viewportSize: SIMD2(1280, 720))
    cam.view = .translation(x: -100, y: -50)
    let world = SIMD2<Float>(640, 360)
    // Project world → clip, then clip → window pixels (the inverse of the viewport map).
    let clip = apply(cam.viewProjection, SIMD4(world.x, world.y, 0, 1))
    let px = (clip.x + 1) / 2 * cam.viewportSize.x
    let py = (1 - clip.y) / 2 * cam.viewportSize.y
    let recovered = cam.screenToWorld(SIMD2(px, py))
    #expect(abs(recovered.x - world.x) < 1e-3)
    #expect(abs(recovered.y - world.y) < 1e-3)
}
