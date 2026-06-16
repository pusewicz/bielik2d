#if os(WASI)
import Bielik2D

/// Web text engine: the Canvas 2D counterpart to native SDL3_ttf. It conforms to
/// the core `TextEngineProtocol` so portable code stores it in `Draw.textEngine`
/// and calls `draw.text(_:font:at:color:)` identically to native.
///
/// Phase 3.3 fills in `drawText`: rasterize the string via `WebTextRasterizer`,
/// upload the resulting canvas as a texture, and emit a textured quad into the
/// batcher (scaled by `font.renderScale`). For now it is a compiling no-op stub
/// so the unified demo and `Bielik2D` core build on web.
public final class WebTextEngine: TextEngineProtocol {
    public init() {}

    public func destroy() {}

    // Phase 3.3 will override `drawText(_:font:at:color:into:)` here.
}
#endif
