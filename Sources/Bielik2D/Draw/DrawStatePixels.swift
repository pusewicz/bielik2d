/// Convert a logical-point scissor rect to clamped target-pixel ints. `nil` → full target.
/// Rounds the rect outward (floor min, ceil max) so a sub-pixel clip never collapses to nothing,
/// then clamps each edge into `[0, target]` (SDL rejects out-of-bounds scissors).
public func scissorPixelRect(_ logical: Rect?, scale: Float, targetW: Int, targetH: Int)
    -> (x: Int, y: Int, w: Int, h: Int) {
    guard let r = logical else { return (0, 0, targetW, targetH) }
    let x0 = max(0, min(targetW, Int((r.minX * scale).rounded(.down))))
    let y0 = max(0, min(targetH, Int((r.minY * scale).rounded(.down))))
    let x1 = max(0, min(targetW, Int((r.maxX * scale).rounded(.up))))
    let y1 = max(0, min(targetH, Int((r.maxY * scale).rounded(.up))))
    return (x0, y0, max(0, x1 - x0), max(0, y1 - y0))
}

/// Convert a logical-point viewport rect to target-pixel floats. `nil` → full target.
public func viewportPixelRect(_ logical: Rect?, scale: Float, targetW: Int, targetH: Int)
    -> (x: Float, y: Float, w: Float, h: Float) {
    guard let r = logical else { return (0, 0, Float(targetW), Float(targetH)) }
    return (r.minX * scale, r.minY * scale, r.width * scale, r.height * scale)
}
