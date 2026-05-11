#if canImport(CSDL3)
import CSDL3

public struct BufferUsage: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let vertex = BufferUsage(rawValue: SDL_GPU_BUFFERUSAGE_VERTEX)
    public static let index = BufferUsage(rawValue: SDL_GPU_BUFFERUSAGE_INDEX)
    public static let indirect = BufferUsage(rawValue: SDL_GPU_BUFFERUSAGE_INDIRECT)
    public static let graphicsStorageRead = BufferUsage(rawValue: SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ)
    public static let computeStorageRead = BufferUsage(rawValue: SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_READ)
    public static let computeStorageWrite = BufferUsage(rawValue: SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_WRITE)
}

public struct Buffer {
    public let handle: OpaquePointer
    public let size: Int
    let device: OpaquePointer

    public func destroy() {
        SDL_ReleaseGPUBuffer(device, handle)
    }
}

extension GPUDevice {
    public func makeBuffer(size: Int, usage: BufferUsage) throws -> Buffer {
        var info = SDL_GPUBufferCreateInfo()
        info.usage = usage.rawValue
        info.size = UInt32(size)
        guard let buf = SDL_CreateGPUBuffer(handle, &info) else {
            throw GPUError.createBuffer(lastSDLError())
        }
        return Buffer(handle: buf, size: size, device: handle)
    }
}
#endif
