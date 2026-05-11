import CSDL3
import Foundation

public enum FontError: Error, CustomStringConvertible {
    case ttfInitFailed(String)
    case openFailed(String)
    case createEngineFailed(String)
    case createTextFailed(String)

    public var description: String {
        switch self {
        case .ttfInitFailed(let m): "TTF_Init failed: \(m)"
        case .openFailed(let m): "TTF_OpenFont failed: \(m)"
        case .createEngineFailed(let m): "TTF_CreateGPUTextEngine failed: \(m)"
        case .createTextFailed(let m): "TTF_CreateText failed: \(m)"
        }
    }
}

enum TTFLifecycle {
    nonisolated(unsafe) static var initialized = false
    private static let lock = NSLock()

    static func ensureInit() throws {
        lock.lock()
        defer { lock.unlock() }
        if !initialized {
            guard TTF_Init() else {
                throw FontError.ttfInitFailed(lastSDLError())
            }
            initialized = true
        }
    }
}

public struct Font {
    public let handle: OpaquePointer

    public init(path: String, ptSize: Float) throws {
        try TTFLifecycle.ensureInit()
        guard let h = TTF_OpenFont(path, ptSize) else {
            throw FontError.openFailed(lastSDLError())
        }
        self.handle = h
    }

    public func destroy() {
        TTF_CloseFont(handle)
    }
}

public struct TextEngine {
    public let handle: OpaquePointer

    public init(on device: GPUDevice) throws {
        try TTFLifecycle.ensureInit()
        guard let h = TTF_CreateGPUTextEngine(device.handle) else {
            throw FontError.createEngineFailed(lastSDLError())
        }
        self.handle = h
    }

    public func destroy() {
        TTF_DestroyGPUTextEngine(handle)
    }
}
