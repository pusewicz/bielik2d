import Testing
@testable import Bielik2D

@Test func pipelineCacheMemoizesEqualDescriptors() {
    var hits = 0
    let cache = PipelineCache<Int> { _ in
        hits += 1
        return hits
    }
    let d1 = PipelineKey(shaderID: 42, colorFormat: .bgra8Unorm, blendMode: .alpha)
    let d2 = PipelineKey(shaderID: 42, colorFormat: .bgra8Unorm, blendMode: .alpha)
    let a = cache.get(d1)
    let b = cache.get(d2)
    #expect(a == b)
    #expect(hits == 1)
}

@Test func pipelineCacheDistinguishesDifferentDescriptors() {
    var hits = 0
    let cache = PipelineCache<Int> { _ in
        hits += 1
        return hits
    }
    let d1 = PipelineKey(shaderID: 1, colorFormat: .bgra8Unorm, blendMode: .alpha)
    let d2 = PipelineKey(shaderID: 2, colorFormat: .bgra8Unorm, blendMode: .alpha)
    _ = cache.get(d1)
    _ = cache.get(d2)
    #expect(hits == 2)
}
