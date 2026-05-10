import CSDL3

public enum GPUError: Error, CustomStringConvertible {
    case createDevice(String)
    case claimWindow(String)
    case acquireCommandBuffer(String)
    case createTexture(String)
    case createBuffer(String)
    case createSampler(String)
    case createTransferBuffer(String)
    case mapTransferBuffer(String)
    case beginRenderPass(String)

    public var description: String {
        switch self {
        case .createDevice(let m): "SDL_CreateGPUDevice failed: \(m)"
        case .claimWindow(let m): "SDL_ClaimWindowForGPUDevice failed: \(m)"
        case .acquireCommandBuffer(let m): "SDL_AcquireGPUCommandBuffer failed: \(m)"
        case .createTexture(let m): "SDL_CreateGPUTexture failed: \(m)"
        case .createBuffer(let m): "SDL_CreateGPUBuffer failed: \(m)"
        case .createSampler(let m): "SDL_CreateGPUSampler failed: \(m)"
        case .createTransferBuffer(let m): "SDL_CreateGPUTransferBuffer failed: \(m)"
        case .mapTransferBuffer(let m): "SDL_MapGPUTransferBuffer failed: \(m)"
        case .beginRenderPass(let m): "SDL_BeginGPURenderPass failed: \(m)"
        }
    }
}

public final class GPUDevice {
    public let handle: OpaquePointer
    private(set) weak var claimedWindow: AnyObject?

    public init(debug: Bool = false) throws {
        // For v0 we declare support for every shader format we might ever ship;
        // shadercross (added in Phase 4) translates HLSL→SPIRV→MSL etc. at runtime.
        // Until then SDL will only pick a backend whose native format matches what
        // we'll feed it, so for macOS dev we list MSL/METALLIB alongside SPIRV.
        let formats: SDL_GPUShaderFormat =
            SDL_GPU_SHADERFORMAT_SPIRV
            | SDL_GPU_SHADERFORMAT_MSL
            | SDL_GPU_SHADERFORMAT_METALLIB
            | SDL_GPU_SHADERFORMAT_DXIL
        guard let dev = SDL_CreateGPUDevice(formats, debug, nil) else {
            throw GPUError.createDevice(lastSDLError())
        }
        self.handle = dev
    }

    public func claim(window: OpaquePointer) throws {
        guard SDL_ClaimWindowForGPUDevice(handle, window) else {
            throw GPUError.claimWindow(lastSDLError())
        }
    }

    public func release(window: OpaquePointer) {
        SDL_ReleaseWindowFromGPUDevice(handle, window)
    }

    public var driverName: String {
        guard let cstr = SDL_GetGPUDeviceDriver(handle) else { return "" }
        return String(cString: cstr)
    }

    public func destroy() {
        SDL_DestroyGPUDevice(handle)
    }
}

@inline(__always)
func lastSDLError() -> String {
    guard let cstr = SDL_GetError() else { return "(no error message)" }
    return String(cString: cstr)
}
