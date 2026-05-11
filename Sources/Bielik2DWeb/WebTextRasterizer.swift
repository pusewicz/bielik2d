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
        let w = Int(ceil(metrics["width"].number ?? 0))
        let ascent = metrics["actualBoundingBoxAscent"].number ?? 0
        let descent = metrics["actualBoundingBoxDescent"].number ?? 0
        let h = Int(ceil(ascent + descent))
        if w <= 0 || h <= 0 { return nil }

        // Sizing the canvas resets its 2D state, so restore font + colour.
        canvas["width"] = .number(Double(w))
        canvas["height"] = .number(Double(h))
        ctx["font"] = .string(fontCSS)
        ctx["fillStyle"] = .string(fillStyle)
        ctx["textBaseline"] = .string("top")
        _ = ctx.fillText!(text, 0, 0)

        return RasterizedText(canvas: canvas, width: w, height: h)
    }
}

@inline(__always)
private func ceil(_ x: Double) -> Double { x.rounded(.up) }
#endif
