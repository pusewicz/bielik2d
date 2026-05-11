import Foundation
import Testing
@testable import Bielik2D

@Suite
struct WGSLBundleTests {
    @Test func allShadersAreBundledAsWGSL() throws {
        for name in ["basic.vert", "basic.frag", "sprite.vert", "sprite.frag"] {
            let source = try Bielik2D.loadBuiltinWGSL(named: name)
            #expect(!source.isEmpty, "\(name).wgsl loaded empty")
        }
    }

    @Test func spriteFragmentBindingsAreDistinct() throws {
        let source = try Bielik2D.loadBuiltinWGSL(named: "sprite.frag")
        // Texture and sampler must live at different WebGPU bindings.
        #expect(source.contains("@binding(0) var mainTex"))
        #expect(source.contains("@binding(1) var mainSampler"))
    }
}
