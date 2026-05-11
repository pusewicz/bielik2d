#if os(WASI)
import JavaScriptKit

public struct RasterizedText {
    /// HTMLCanvasElement holding the painted glyphs. Usable directly as a
    /// source for `queue.copyExternalImageToTexture`.
    public let canvas: JSObject
    public let width: Int
    public let height: Int
}

public enum WebTextRasterizer {
    /// Paints `text` onto a fresh `<canvas>` sized to its measured bounds.
    /// `fontCSS` follows the Canvas 2D shorthand (e.g. `"32px sans-serif"`).
    /// Returns nil if `measureText` reports a zero-width bounding box.
    public static func rasterize(_ text: String, fontCSS: String, fillStyle: String = "white") -> RasterizedText? {
        guard let document = JSObject.global.document.object else { return nil }
        guard let canvas = document.createElement!("canvas").object else { return nil }
        guard let ctx = canvas.getContext!("2d").object else { return nil }

        ctx["font"] = .string(fontCSS)
        guard let metrics = ctx.measureText!(text).object else { return nil }
        let advance = metrics["width"].number ?? 0
        let ascent = metrics["actualBoundingBoxAscent"].number ?? 0
        let descent = metrics["actualBoundingBoxDescent"].number ?? 0
        let boxLeft = metrics["actualBoundingBoxLeft"].number ?? 0
        let boxRight = metrics["actualBoundingBoxRight"].number ?? 0
        // Pad one CSS pixel on each side to absorb subpixel rounding and any
        // stylistic overshoot the metrics under-count (e.g. accented caps).
        let pad: Double = 1
        let visualWidth = max(advance, boxLeft + boxRight)
        let w = Int(ceil(visualWidth + pad * 2))
        let h = Int(ceil(ascent + descent + pad * 2))
        if w <= 0 || h <= 0 { return nil }

        // Sizing the canvas resets its 2D state, so restore font + colour.
        canvas["width"] = .number(Double(w))
        canvas["height"] = .number(Double(h))
        ctx["font"] = .string(fontCSS)
        ctx["fillStyle"] = .string(fillStyle)
        ctx["textBaseline"] = .string("alphabetic")
        // Draw with the baseline at `ascent + pad`, x offset by `boxLeft + pad`
        // so glyphs that start left of the origin (rare but legal) stay inside
        // the texture.
        _ = ctx.fillText!(text, boxLeft + pad, ascent + pad)

        return RasterizedText(canvas: canvas, width: w, height: h)
    }
}

@inline(__always)
private func ceil(_ x: Double) -> Double { x.rounded(.up) }
#endif
