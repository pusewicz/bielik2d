import Testing
@testable import Bielik2D

@Test func floatLerp() {
    #expect(Float.lerp(0, 10, 0) == 0)
    #expect(Float.lerp(0, 10, 1) == 10)
    #expect(Float.lerp(0, 10, 0.5) == 5)
    #expect(Float.lerp(2, 4, 0.25) == 2.5)
}

@Test func doubleLerp() {
    #expect(Double.lerp(0, 10, 0.5) == 5)
    #expect(Double.lerp(-1, 1, 0.5) == 0)
}

@Test func simd2Lerp() {
    let a = SIMD2<Float>(0, 0)
    let b = SIMD2<Float>(10, 20)
    #expect(SIMD2<Float>.lerp(a, b, 0.5) == SIMD2<Float>(5, 10))
    #expect(SIMD2<Float>.lerp(a, b, 0) == a)
    #expect(SIMD2<Float>.lerp(a, b, 1) == b)
}

@Test func colorLerp() {
    let mid = Color.lerp(.black, .white, 0.5)
    #expect(mid.r == 0.5 && mid.g == 0.5 && mid.b == 0.5 && mid.a == 1.0)
    let fade = Color.lerp(.white, .clear, 0.5)
    #expect(fade.a == 0.5)
}

@Test func rectLerp() {
    let a = Rect(x: 0, y: 0, width: 10, height: 10)
    let b = Rect(x: 10, y: 20, width: 30, height: 50)
    let mid = Rect.lerp(a, b, 0.5)
    #expect(mid == Rect(x: 5, y: 10, width: 20, height: 30))
}
