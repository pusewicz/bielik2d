#if canImport(CSDL3)
import CSDL3

public struct CopyPass {
    public let handle: OpaquePointer

    public func upload(from src: TransferBuffer, offset srcOffset: Int = 0,
                       to dst: Buffer, offset dstOffset: Int = 0,
                       size: Int, cycle: Bool = false) {
        var srcLoc = SDL_GPUTransferBufferLocation()
        srcLoc.transfer_buffer = src.handle
        srcLoc.offset = UInt32(srcOffset)
        var dstRegion = SDL_GPUBufferRegion()
        dstRegion.buffer = dst.handle
        dstRegion.offset = UInt32(dstOffset)
        dstRegion.size = UInt32(size)
        SDL_UploadToGPUBuffer(handle, &srcLoc, &dstRegion, cycle)
    }
}

extension CommandBuffer {
    public func withCopyPass(_ body: (CopyPass) -> Void) {
        let pass = SDL_BeginGPUCopyPass(handle)!
        body(CopyPass(handle: pass))
        SDL_EndGPUCopyPass(pass)
    }
}
#endif
