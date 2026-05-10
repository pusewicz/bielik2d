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
}
