// `Font` is a cross-platform value. The native build (SDL3_ttf) opens a real
// TrueType handle and rasterizes through the GPU text engine; the web build
// (Canvas 2D) carries a CSS font family and rasterizes glyphs in the browser.
// Both expose `Font.system(ptSize:)` so demo/scene code never names a platform.

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

    /// Cross-platform entry point used by portable demo/scene code. Resolves to a
    /// reliably-present system TrueType font on native and to a CSS family on web.
    public static func system(ptSize: Float, pixelDensity: Float = Font.ambientPixelDensity) throws -> Font {
        try Font(path: systemFontPath, ptSize: ptSize, pixelDensity: pixelDensity)
    }

    /// A TrueType font that ships with the host OS. Geneva is present on every
    /// supported macOS install; swap here if a bundled face is preferred later.
    static let systemFontPath = "/System/Library/Fonts/Geneva.ttf"

    public func destroy() {
        TTF_CloseFont(handle)
    }
}
#endif

#if os(WASI)
/// Web build of `Font`: a Canvas 2D descriptor. There is no SDL_ttf in the
/// browser, so the font is just a CSS family plus a logical size; the web
/// `TextEngine` turns that into `"<px>px <family>"` shorthand at rasterize time.
public struct Font {
    public let family: String
    public let ptSize: Float
    /// Pixels per logical point. The web text engine multiplies `ptSize` by this
    /// to rasterize at native resolution, then scales quads back by `renderScale`.
    public let pixelDensity: Float
    /// `1 / pixelDensity`; mirrors the native field so drawing code is identical.
    public let renderScale: Float

    /// The current display pixel density, kept in sync with the canvas backing
    /// store so portable code can rely on the same ambient value as native.
    public nonisolated(unsafe) static var ambientPixelDensity: Float = 1.0

    public init(family: String, ptSize: Float, pixelDensity: Float = Font.ambientPixelDensity) {
        let density = max(1, pixelDensity)
        self.family = family
        self.ptSize = ptSize
        self.pixelDensity = density
        self.renderScale = 1.0 / density
    }

    /// Cross-platform entry point used by portable demo/scene code. On web this is
    /// the generic `sans-serif` CSS family, which every browser resolves.
    public static func system(ptSize: Float, pixelDensity: Float = Font.ambientPixelDensity) -> Font {
        Font(family: "sans-serif", ptSize: ptSize, pixelDensity: pixelDensity)
    }

    /// Canvas 2D `font` shorthand rasterized at native resolution.
    public var fontCSS: String {
        "\(Int((ptSize * pixelDensity).rounded()))px \(family)"
    }
}
#endif
