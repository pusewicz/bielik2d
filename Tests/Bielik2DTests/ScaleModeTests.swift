import Testing
@testable import Bielik2D

@Test func scaleModeShaderValues() {
    // The shader branches on these exact floats; linear must be 0 so that
    // zero-initialised vertices (every existing draw) keep linear behaviour.
    #expect(ScaleMode.linear.shaderValue == 0)
    #expect(ScaleMode.pixelArt.shaderValue == 1)
    #expect(ScaleMode.nearest.shaderValue == 2)
}

@Test func scaleModeDefaultIsLinear() {
    #expect(ScaleMode.default == .linear)
}
