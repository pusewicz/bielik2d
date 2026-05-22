/// Identifies a registered image inside a `SpriteBatch`. A `Sprite` is a thin
/// public handle around one of these; the GPU texture stays hidden in the atlas.
typealias SpriteID = Int

/// Where a registered image ended up once packed: which page, its normalized UV
/// sub-rect, and `uvBounds` carrying that sub-rect's (minU,minV,maxU,maxV). The
/// shader uses `uvBounds` to do pixel-art snapping in the sprite's local space and
/// to clamp sampling (inset by half a texel) so it never leaks into a neighbour.
struct Placement: Equatable {
    let page: Int
    let uvRect: Rect
    let uvBounds: SIMD4<Float>  // (minU, minV, maxU, maxV) of the sub-rect

    /// Computes the placement for an image whose pixels sit at
    /// (slotX + gutter, slotY + gutter) on a `pageW`×`pageH` page.
    static func compute(slotX: Int, slotY: Int, imageW: Int, imageH: Int,
                        pageW: Int, pageH: Int, gutter: Int, page: Int) -> Placement {
        let px = slotX + gutter
        let py = slotY + gutter
        let minU = Float(px) / Float(pageW)
        let minV = Float(py) / Float(pageH)
        let maxU = Float(px + imageW) / Float(pageW)
        let maxV = Float(py + imageH) / Float(pageH)
        return Placement(
            page: page,
            uvRect: Rect(x: minU, y: minV, width: maxU - minU, height: maxV - minV),
            uvBounds: SIMD4(minU, minV, maxU, maxV)
        )
    }
}

/// One deferred sprite draw, captured at `Draw.sprite` time. The corners and tint
/// are already resolved against the current transform/color; only the atlas UV is
/// unknown until the `SpriteBatch` resolves it at flush.
struct SpriteInstance {
    var id: SpriteID
    var p0: SIMD2<Float>
    var p1: SIMD2<Float>
    var p2: SIMD2<Float>
    var p3: SIMD2<Float>
    var color: SIMD4<Float>
    var scaleData: SIMD4<Float>  // (texelW, texelH, scaleMode, 0) — sprite's own size
    var layer: Int
}
