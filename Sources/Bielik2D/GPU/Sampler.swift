#if canImport(CSDL3)
import CSDL3

public enum SamplerFilter {
    case nearest
    case linear

    var sdlValue: SDL_GPUFilter {
        switch self {
        case .nearest: SDL_GPU_FILTER_NEAREST
        case .linear: SDL_GPU_FILTER_LINEAR
        }
    }

    var sdlMipmapMode: SDL_GPUSamplerMipmapMode {
        switch self {
        case .nearest: SDL_GPU_SAMPLERMIPMAPMODE_NEAREST
        case .linear: SDL_GPU_SAMPLERMIPMAPMODE_LINEAR
        }
    }
}

public enum SamplerAddressMode {
    case `repeat`
    case mirroredRepeat
    case clampToEdge

    var sdlValue: SDL_GPUSamplerAddressMode {
        switch self {
        case .repeat: SDL_GPU_SAMPLERADDRESSMODE_REPEAT
        case .mirroredRepeat: SDL_GPU_SAMPLERADDRESSMODE_MIRRORED_REPEAT
        case .clampToEdge: SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE
        }
    }
}

struct Sampler {
    public let handle: OpaquePointer
    let device: OpaquePointer

    public func destroy() {
        SDL_ReleaseGPUSampler(device, handle)
    }
}

extension GPUDevice {
    public func makeSampler(filter: SamplerFilter = .linear,
                            addressMode: SamplerAddressMode = .clampToEdge) throws -> Sampler {
        var info = SDL_GPUSamplerCreateInfo()
        info.min_filter = filter.sdlValue
        info.mag_filter = filter.sdlValue
        info.mipmap_mode = filter.sdlMipmapMode
        info.address_mode_u = addressMode.sdlValue
        info.address_mode_v = addressMode.sdlValue
        info.address_mode_w = addressMode.sdlValue
        guard let s = SDL_CreateGPUSampler(handle, &info) else {
            throw GPUError.createSampler(lastSDLError())
        }
        return Sampler(handle: s, device: handle)
    }
}
#endif
