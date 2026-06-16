#if os(WASI)
import JavaScriptKit
import Bielik2D

/// Web text engine: the Canvas 2D counterpart to native SDL3_ttf. It conforms to
/// the core `TextEngineProtocol` so portable code stores it in `Draw.textEngine`
/// and calls `draw.text(_:font:at:color:)` identically to native.
///
/// `drawText` rasterizes the string through `WebTextRasterizer`, uploads the
/// resulting `<canvas>` to a WebGPU texture, registers a stable token → bind
/// group on the renderer, and emits a textured quad into the batcher. The quad
/// is sized to the rasterized pixel box scaled by `font.renderScale` so HiDPI
/// glyphs occupy the same logical area as native (which rasterizes oversized and
/// scales the atlas quads back by the same factor).
///
/// Rasterization is cached by `(string, fontCSS)`: the glyph texture is painted
/// white and tinted per draw via the vertex colour, so the same texture serves
/// every colour and only the string/font identity needs to key the cache. This
/// avoids re-painting a `<canvas>` and re-uploading a texture every frame for
/// static HUD text.
public final class WebTextEngine: TextEngineProtocol {
    /// The renderer that owns the WebGPU device + texture-token registry. The
    /// engine needs it to upload glyph textures and bind them at draw time.
    /// Set after construction (the renderer and engine are created together at
    /// startup, and the demo wires them up before the first frame).
    public weak var renderer: WebRenderer?

    /// One painted glyph texture, kept alive so its registered bind group stays
    /// valid, plus the token the batcher carries to select it.
    private struct CachedGlyphs {
        let token: OpaquePointer
        let texture: JSObject
        let width: Int
        let height: Int
    }

    /// Keyed by `"<fontCSS>\u{0}<string>"`. The null separator can't appear in a
    /// CSS font string and keeps two distinct (font, string) pairs from colliding.
    private var cache: [String: CachedGlyphs] = [:]

    /// Backing storage for the per-texture tokens. Each cache entry allocates a
    /// one-byte heap cell whose address is a process-unique `OpaquePointer` —
    /// the web analogue of native keying binds by the real texture handle.
    private var tokenStorage: [UnsafeMutableRawPointer] = []

    public init(renderer: WebRenderer? = nil) {
        self.renderer = renderer
    }

    public func destroy() {
        for ptr in tokenStorage { ptr.deallocate() }
        tokenStorage.removeAll()
        cache.removeAll()
    }

    public func drawText(_ string: String, font: Font, at origin: SIMD2<Float>, color: Color, into draw: Draw) {
        if string.isEmpty { return }
        guard let renderer else { return }
        guard let glyphs = glyphTexture(for: string, font: font, on: renderer) else { return }

        // Match native: the quad covers the rasterized box scaled back to logical
        // points. `renderScale` (= 1/pixelDensity) undoes the oversized rasterize
        // so HiDPI text occupies the same screen area as a 1× display.
        let scale = font.renderScale
        let w = Float(glyphs.width) * scale
        let h = Float(glyphs.height) * scale

        // Bind the glyph texture for this run, then emit the quad and reset the
        // texture so following geometry doesn't sample the glyphs. `quad` applies
        // the current transform and multiplies in the ambient colour tint itself,
        // so pass the bare glyph `color` — pre-tinting here would double it. The
        // glyph texture is painted white, so `tex * color` yields the requested
        // colour at the glyph's coverage (alpha). Origin is the text's top-left.
        draw.setBatcherTexture(glyphs.token)
        draw.quad(rect: Rect(x: origin.x, y: origin.y, width: w, height: h),
                  uv: Rect(x: 0, y: 0, width: 1, height: 1),
                  color: SIMD4<Float>(color.r, color.g, color.b, color.a))
        draw.setBatcherTexture(nil)
    }

    /// Returns the cached glyph texture for `(string, fontCSS)`, rasterizing and
    /// uploading on first sight and registering its token with the renderer.
    private func glyphTexture(for string: String, font: Font, on renderer: WebRenderer) -> CachedGlyphs? {
        let fontCSS = font.fontCSS
        let key = fontCSS + "\u{0}" + string
        if let hit = cache[key] { return hit }

        guard let raster = WebTextRasterizer.rasterize(string, fontCSS: fontCSS) else { return nil }
        let (texture, w, h) = renderer.backend.makeTexture(from: raster.canvas)

        let cell = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
        tokenStorage.append(cell)
        let token = OpaquePointer(cell)
        renderer.registerTexture(token, texture: texture)

        let entry = CachedGlyphs(token: token, texture: texture, width: w, height: h)
        cache[key] = entry
        return entry
    }
}
#endif
