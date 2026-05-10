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

    @Test func transferBufferMapsAndStoresBytes() throws {
        let app = try App(title: "xfer", width: 64, height: 64)
        defer { app.destroy() }
        let bytes: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8]
        let xfer = try app.gpu.makeTransferBuffer(size: bytes.count, usage: .upload)
        defer { xfer.destroy() }
        xfer.withMappedMemory { ptr in
            ptr.copyMemory(from: bytes, byteCount: bytes.count)
        }
        // map again to verify the write is observable
        xfer.withMappedMemory { ptr in
            let readback = Array(UnsafeBufferPointer(start: ptr.assumingMemoryBound(to: UInt8.self), count: bytes.count))
            #expect(readback == bytes)
        }
    }
}
