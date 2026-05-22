#if canImport(CSDL3)
import CSDL3

public enum TransferBufferUsage {
    case upload
    case download

    var sdlValue: SDL_GPUTransferBufferUsage {
        switch self {
        case .upload: SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD
        case .download: SDL_GPU_TRANSFERBUFFERUSAGE_DOWNLOAD
        }
    }
}

struct TransferBuffer {
    public let handle: OpaquePointer
    public let size: Int
    let device: OpaquePointer

    public func withMappedMemory<T>(cycle: Bool = false, _ body: (UnsafeMutableRawPointer) -> T) -> T {
        let ptr = SDL_MapGPUTransferBuffer(device, handle, cycle)!
        defer { SDL_UnmapGPUTransferBuffer(device, handle) }
        return body(ptr)
    }

    public func destroy() {
        SDL_ReleaseGPUTransferBuffer(device, handle)
    }
}

extension GPUDevice {
    public func makeTransferBuffer(size: Int, usage: TransferBufferUsage) throws -> TransferBuffer {
        var info = SDL_GPUTransferBufferCreateInfo()
        info.usage = usage.sdlValue
        info.size = UInt32(size)
        guard let buf = SDL_CreateGPUTransferBuffer(handle, &info) else {
            throw GPUError.createTransferBuffer(lastSDLError())
        }
        return TransferBuffer(handle: buf, size: size, device: handle)
    }
}
#endif
