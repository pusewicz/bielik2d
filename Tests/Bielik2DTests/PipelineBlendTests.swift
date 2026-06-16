import Testing
@testable import Bielik2D

@Test func blendModeDistinguishesPipelineKey() {
    let alpha = PipelineKey(shaderID: 0, colorFormat: .bgra8Unorm, blendMode: .alpha)
    let additive = PipelineKey(shaderID: 0, colorFormat: .bgra8Unorm, blendMode: .additive)
    #expect(alpha != additive)
    #expect(alpha == PipelineKey(shaderID: 0, colorFormat: .bgra8Unorm, blendMode: .alpha))
}
