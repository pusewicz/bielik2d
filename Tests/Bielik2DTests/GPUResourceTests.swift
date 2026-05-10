import AppKit
import Testing
import CSDL3
@testable import Bielik2D

@Suite(.serialized)
@MainActor
struct GPUResourceTests {
    init() { _ = NSApplication.shared }

    @Test func commandBufferAcquireAndSubmit() throws {
        let app = try App(title: "cmdbuf", width: 64, height: 64)
        defer { app.destroy() }
        let cmd = try app.gpu.acquireCommandBuffer()
        cmd.submit()
    }
}
