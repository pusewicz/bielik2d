import Testing
import simd
@testable import Bielik2D

private func apply(_ m: simd_float4x4, _ v: SIMD4<Float>) -> SIMD4<Float> {
    m * v
}

@Test func defaultCameraMapsScreenCornersToClipSpace() {
    let cam = Camera(viewportSize: SIMD2(1280, 720))
    let vp = cam.viewProjection
    let topLeft = apply(vp, SIMD4(0, 0, 0, 1))
    #expect(abs(topLeft.x + 1) < 1e-5)
    #expect(abs(topLeft.y + 1) < 1e-5)
    let bottomRight = apply(vp, SIMD4(1280, 720, 0, 1))
    #expect(abs(bottomRight.x - 1) < 1e-5)
    #expect(abs(bottomRight.y - 1) < 1e-5)
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
