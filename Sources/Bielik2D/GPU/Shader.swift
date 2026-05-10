import CSDL3
import CSDL3Shadercross
import Foundation

public enum ShaderStage {
    case vertex
    case fragment

    var sdlValue: SDL_ShaderCross_ShaderStage {
        switch self {
        case .vertex: SDL_SHADERCROSS_SHADERSTAGE_VERTEX
        case .fragment: SDL_SHADERCROSS_SHADERSTAGE_FRAGMENT
        }
    }
}

public enum ShaderError: Error, CustomStringConvertible {
    case bytecodeNotFound(String)
    case compileFailed(String)

    public var description: String {
        switch self {
        case .bytecodeNotFound(let name): "shader bytecode not found in bundle: \(name)"
        case .compileFailed(let m): "SDL_ShaderCross_CompileGraphicsShaderFromSPIRV failed: \(m)"
        }
    }
}

public struct Shader {
    public let handle: OpaquePointer
    let device: OpaquePointer

    public func destroy() {
        SDL_ReleaseGPUShader(device, handle)
    }
}

private enum ShadercrossLifecycle {
    nonisolated(unsafe) static var initialized = false
    private static let lock = NSLock()

    static func ensureInit() {
        lock.lock()
        defer { lock.unlock() }
        if !initialized {
            _ = SDL_ShaderCross_Init()
            initialized = true
        }
    }
}

extension Shader {
    /// Loads a precompiled SPIR-V resource shipped with Bielik2D and turns it into an SDL_GPUShader.
    public static func builtin(name: String, stage: ShaderStage, on device: GPUDevice) throws -> Shader {
        guard let url = Bundle.module.url(forResource: name, withExtension: "spv", subdirectory: "shaders") else {
            throw ShaderError.bytecodeNotFound(name)
        }
        let bytecode = try Data(contentsOf: url)
        return try Shader.fromSPIRV(bytecode, stage: stage, entryPoint: "main", on: device)
    }

    public static func fromSPIRV(_ bytecode: Data, stage: ShaderStage, entryPoint: String, on device: GPUDevice) throws -> Shader {
        ShadercrossLifecycle.ensureInit()
        return try bytecode.withUnsafeBytes { bytes -> Shader in
            try entryPoint.withCString { entry in
                var info = SDL_ShaderCross_SPIRV_Info()
                info.bytecode = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                info.bytecode_size = bytecode.count
                info.entrypoint = entry
                info.shader_stage = stage.sdlValue
                var resourceInfo = SDL_ShaderCross_GraphicsShaderResourceInfo()
                guard let sh = SDL_ShaderCross_CompileGraphicsShaderFromSPIRV(device.handle, &info, &resourceInfo, 0) else {
                    throw ShaderError.compileFailed(lastSDLError())
                }
                return Shader(handle: sh, device: device.handle)
            }
        }
    }
}
