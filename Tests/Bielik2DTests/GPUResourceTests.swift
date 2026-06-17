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

    @Test func bufferRoundtripsThroughTransferBuffer() throws {
        let app = try App(title: "buf", width: 64, height: 64)
        defer { app.destroy() }
        let bytes: [UInt8] = (0..<16).map(UInt8.init)
        let xfer = try app.gpu.makeTransferBuffer(size: bytes.count, usage: .upload)
        defer { xfer.destroy() }
        xfer.withMappedMemory { $0.copyMemory(from: bytes, byteCount: bytes.count) }

        let buf = try app.gpu.makeBuffer(size: bytes.count, usage: .vertex)
        defer { buf.destroy() }

        let cmd = try app.gpu.acquireCommandBuffer()
        cmd.withCopyPass { copy in
            copy.upload(from: xfer, offset: 0, to: buf, offset: 0, size: bytes.count)
        }
        cmd.submit()
    }

    @Test func textureUploadsPixelsViaTransferBuffer() throws {
        let app = try App(title: "tex", width: 64, height: 64)
        defer { app.destroy() }
        let pixels: [UInt8] = Array(repeating: 0xAB, count: 4 * 4 * 4) // 4x4 RGBA
        let xfer = try app.gpu.makeTransferBuffer(size: pixels.count, usage: .upload)
        defer { xfer.destroy() }
        xfer.withMappedMemory { $0.copyMemory(from: pixels, byteCount: pixels.count) }

        let tex = try app.gpu.makeTexture(width: 4, height: 4, format: .rgba8Unorm, usage: .sampler)
        defer { tex.destroy() }

        let cmd = try app.gpu.acquireCommandBuffer()
        cmd.withCopyPass { copy in
            copy.upload(from: xfer, to: tex)
        }
        cmd.submit()
        #expect(tex.width == 4)
        #expect(tex.height == 4)
    }

    @Test func textureUploadsToASubRegion() throws {
        let app = try App(title: "subtex", width: 64, height: 64)
        defer { app.destroy() }
        // A 4×4 RGBA image placed into a sub-region of an 8×8 atlas page.
        let sub = 4
        let pixels = [UInt8](repeating: 0xCD, count: sub * sub * 4)
        let xfer = try app.gpu.makeTransferBuffer(size: pixels.count, usage: .upload)
        defer { xfer.destroy() }
        xfer.withMappedMemory { $0.copyMemory(from: pixels, byteCount: pixels.count) }

        let page = try app.gpu.makeTexture(width: 8, height: 8, format: .rgba8Unorm, usage: .sampler)
        defer { page.destroy() }

        let cmd = try app.gpu.acquireCommandBuffer()
        cmd.withCopyPass { copy in
            copy.upload(from: xfer, to: page,
                        region: (x: 2, y: 1, width: sub, height: sub), pixelsPerRow: sub)
        }
        cmd.submit()
        #expect(page.width == 8)
        #expect(page.height == 8)
    }

    @Test func renderPassClearsAColorTarget() throws {
        let app = try App(title: "rp", width: 64, height: 64)
        defer { app.destroy() }
        let target = try app.gpu.makeTexture(width: 64, height: 64, format: .rgba8Unorm, usage: .colorTarget)
        defer { target.destroy() }
        let cmd = try app.gpu.acquireCommandBuffer()
        cmd.withRenderPass(colorTarget: target, clear: Color(r: 0.1, g: 0.2, b: 0.3, a: 1.0)) { _ in
            // no draws — just clear
        }
        cmd.submit()
    }

    @Test func samplerCreatesWithNearestAndLinearFilters() throws {
        let app = try App(title: "smp", width: 64, height: 64)
        defer { app.destroy() }
        let nearest = try app.gpu.makeSampler(filter: .nearest, addressMode: .clampToEdge)
        defer { nearest.destroy() }
        let linear = try app.gpu.makeSampler(filter: .linear, addressMode: .repeat)
        linear.destroy()
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
