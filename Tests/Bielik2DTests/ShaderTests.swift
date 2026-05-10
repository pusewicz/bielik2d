import AppKit
import Testing
import CSDL3
@testable import Bielik2D

@Suite(.serialized)
@MainActor
struct ShaderTests {
    init() { _ = NSApplication.shared }

    @Test func compileGraphicsShaderFromBuiltinSPIRV() throws {
        let app = try App(title: "shader", width: 64, height: 64)
        defer { app.destroy() }
        let vs = try Shader.builtin(name: "basic.vert", stage: .vertex, on: app.gpu)
        defer { vs.destroy() }
        let fs = try Shader.builtin(name: "basic.frag", stage: .fragment, on: app.gpu)
        defer { fs.destroy() }
    }

    @Test func spritePipelineCompilesWithUnifiedVertex() throws {
        let app = try App(title: "sprite-pipe", width: 64, height: 64)
        defer { app.destroy() }
        let vs = try Shader.builtin(name: "sprite.vert", stage: .vertex, on: app.gpu)
        let fs = try Shader.builtin(name: "sprite.frag", stage: .fragment, on: app.gpu)
        let pipe = try app.gpu.makePipeline(
            vertex: vs, fragment: fs,
            vertexBuffer: Vertex.bufferLayout,
            colorTargetFormat: .bgra8Unorm,
            blendMode: .alpha
        )
        pipe.destroy()
        vs.destroy()
        fs.destroy()
    }

    @Test func createsPipelineFromBasicShaders() throws {
        let app = try App(title: "pipe", width: 64, height: 64)
        defer { app.destroy() }
        let vs = try Shader.builtin(name: "basic.vert", stage: .vertex, on: app.gpu)
        let fs = try Shader.builtin(name: "basic.frag", stage: .fragment, on: app.gpu)
        let layout = VertexBufferDescriptor(stride: 24, attributes: [
            VertexAttribute(location: 0, format: .float2, offset: 0),
            VertexAttribute(location: 1, format: .float4, offset: 8),
        ])
        let pipe = try app.gpu.makePipeline(
            vertex: vs, fragment: fs,
            vertexBuffer: layout,
            colorTargetFormat: .bgra8Unorm,
            blendMode: .alpha
        )
        pipe.destroy()
        vs.destroy()
        fs.destroy()
    }
}
