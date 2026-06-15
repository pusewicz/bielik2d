#if canImport(CSDL3)
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
    /// Multiply glyph quad coordinates by this value to recover logical (point)
    /// size after the font was opened at a higher physical resolution.
    /// Equals `1 / pixelDensity`. On a 1× display this is 1.0 (no change).
    public let renderScale: Float

    /// The current display pixel density, installed by `App` at startup so that
    /// bare `Font(path:ptSize:)` calls automatically rasterize at native resolution.
    public nonisolated(unsafe) static var ambientPixelDensity: Float = 1.0

    /// Opens the font rasterized at `ptSize * pixelDensity` so glyphs fill
    /// native pixels on HiDPI displays. `renderScale` is set to `1 / pixelDensity`
    /// so that drawing code can scale quads back to logical point size.
    ///
    /// - Parameters:
    ///   - path: Path to a TrueType or OpenType font file.
    ///   - ptSize: Desired logical size in points.
    ///   - pixelDensity: Pixels per logical point (e.g. 2.0 on a Retina display).
    ///     Defaults to `Font.ambientPixelDensity`, which `App` keeps in sync with
    ///     the current display.
    public init(path: String, ptSize: Float, pixelDensity: Float = Font.ambientPixelDensity) throws {
        try TTFLifecycle.ensureInit()
        let density = max(1, pixelDensity)
        guard let h = TTF_OpenFont(path, ptSize * density) else {
            throw FontError.openFailed(lastSDLError())
        }
        self.handle = h
        self.renderScale = 1.0 / density
    }

    public func destroy() {
        TTF_CloseFont(handle)
    }
}

public struct TextEngine {
    public let handle: OpaquePointer

    public init(on renderer: Renderer) throws {
        try TTFLifecycle.ensureInit()
        guard let h = TTF_CreateGPUTextEngine(renderer.device.handle) else {
            throw FontError.createEngineFailed(lastSDLError())
        }
        self.handle = h
    }

    public func destroy() {
        TTF_DestroyGPUTextEngine(handle)
    }
}
#endif
