#if canImport(CSDL3)
import CSDL3

extension TextureFormat {
    var sdlValue: SDL_GPUTextureFormat {
        switch self {
        case .rgba8Unorm: SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM
        case .bgra8Unorm: SDL_GPU_TEXTUREFORMAT_B8G8R8A8_UNORM
        }
    }
}

public struct TextureUsage: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let sampler = TextureUsage(rawValue: SDL_GPU_TEXTUREUSAGE_SAMPLER)
    public static let colorTarget = TextureUsage(rawValue: SDL_GPU_TEXTUREUSAGE_COLOR_TARGET)
    public static let depthStencilTarget = TextureUsage(rawValue: SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET)
    public static let graphicsStorageRead = TextureUsage(rawValue: SDL_GPU_TEXTUREUSAGE_GRAPHICS_STORAGE_READ)
}

struct Texture {
    public let handle: OpaquePointer
    public let width: Int
    public let height: Int
    public let format: TextureFormat
    let device: OpaquePointer
    let owned: Bool

    public func destroy() {
        if owned {
            SDL_ReleaseGPUTexture(device, handle)
        }
    }
}

extension GPUDevice {
    public func makeTexture(width: Int, height: Int,
                            format: TextureFormat = .rgba8Unorm,
                            usage: TextureUsage = .sampler) throws -> Texture {
        var info = SDL_GPUTextureCreateInfo()
        info.type = SDL_GPU_TEXTURETYPE_2D
        info.format = format.sdlValue
        info.usage = usage.rawValue
        info.width = UInt32(width)
        info.height = UInt32(height)
        info.layer_count_or_depth = 1
        info.num_levels = 1
        info.sample_count = SDL_GPU_SAMPLECOUNT_1
        guard let tex = SDL_CreateGPUTexture(handle, &info) else {
            throw GPUError.createTexture(lastSDLError())
        }
        return Texture(handle: tex, width: width, height: height, format: format, device: handle, owned: true)
    }
}

extension CopyPass {
    public func upload(from src: TransferBuffer, offset srcOffset: Int = 0,
                       to dst: Texture, cycle: Bool = false) {
        var srcInfo = SDL_GPUTextureTransferInfo()
        srcInfo.transfer_buffer = src.handle
        srcInfo.offset = UInt32(srcOffset)
        srcInfo.pixels_per_row = UInt32(dst.width)
        srcInfo.rows_per_layer = UInt32(dst.height)
        var dstRegion = SDL_GPUTextureRegion()
        dstRegion.texture = dst.handle
        dstRegion.w = UInt32(dst.width)
        dstRegion.h = UInt32(dst.height)
        dstRegion.d = 1
        SDL_UploadToGPUTexture(handle, &srcInfo, &dstRegion, cycle)
    }
}
#endif
