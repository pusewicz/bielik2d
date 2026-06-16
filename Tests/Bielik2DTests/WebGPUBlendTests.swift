import Testing
@testable import Bielik2D

// The web pipeline cache derives its WebGPU blend state from `BlendMode`. The
// factors must mirror the native SDL mapping in GraphicsPipeline.swift exactly,
// so the same draw command blends identically on both backends.

@Test func noneBlendDisablesBlending() {
    #expect(BlendMode.none.webGPUBlendState == nil)
}

@Test func alphaBlendMatchesNative() {
    let s = BlendMode.alpha.webGPUBlendState
    #expect(s == WebGPUBlendState(
        color: WebGPUBlendComponent(srcFactor: "src-alpha", dstFactor: "one-minus-src-alpha"),
        alpha: WebGPUBlendComponent(srcFactor: "one", dstFactor: "one-minus-src-alpha")))
}

@Test func additiveBlendMatchesNative() {
    let s = BlendMode.additive.webGPUBlendState
    #expect(s == WebGPUBlendState(
        color: WebGPUBlendComponent(srcFactor: "one", dstFactor: "one"),
        alpha: WebGPUBlendComponent(srcFactor: "one", dstFactor: "one")))
}

@Test func premultipliedAlphaBlendMatchesNative() {
    let s = BlendMode.premultipliedAlpha.webGPUBlendState
    #expect(s == WebGPUBlendState(
        color: WebGPUBlendComponent(srcFactor: "one", dstFactor: "one-minus-src-alpha"),
        alpha: WebGPUBlendComponent(srcFactor: "one", dstFactor: "one-minus-src-alpha")))
}
