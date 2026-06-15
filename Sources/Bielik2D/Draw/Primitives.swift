import Foundation
#if canImport(simd)
import simd
#else
import kvSIMD
#endif

/// Encodes the SDF shape carried in `Vertex.type`. Must stay in sync with the
/// branches in `Shaders/src/sprite.frag.hlsl`.
public enum ShapeType: Float {
    case sprite = 0
    case circle = 1
    case line = 2
    case box = 3
    case capsule = 4
}

extension Draw {
    /// Filled circle in world space, with antialiased edge.
    public func circleFill(center: SIMD2<Float>, radius: Float, color: Color = .white, aa: Float? = nil) {
        let aa = aa ?? currentShapeAA
        // Slightly larger quad to give AA room.
        let pad = aa
        let extent = radius + pad
        let bounds = Rect(x: center.x - extent, y: center.y - extent, width: 2 * extent, height: 2 * extent)
        emitSDFQuad(type: .circle, bounds: bounds, color: color,
                    localExtent: extent, radius: radius, stroke: 0, aa: aa, fill: 1)
    }

    /// Antialiased circle outline of the given `thickness`, centred on the radius.
    public func circle(center: SIMD2<Float>, radius: Float, thickness: Float,
                       color: Color = .white, aa: Float? = nil) {
        let aa = aa ?? currentShapeAA
        // Quad must reach the outer edge of the stroke plus the AA fringe.
        let pad = thickness * 0.5 + aa
        let extent = radius + pad
        let bounds = Rect(x: center.x - extent, y: center.y - extent,
                          width: 2 * extent, height: 2 * extent)
        emitSDFQuad(type: .circle, bounds: bounds, color: color,
                    localExtent: extent, radius: radius, stroke: thickness, aa: aa, fill: 0)
    }

    /// Filled or outlined box. `stroke` 0 means filled; >0 means an outline of that
    /// thickness centred on the rect boundary. `cornerRadius` 0 means sharp corners.
    public func box(_ rect: Rect, stroke: Float = 0, cornerRadius: Float = 0,
                    color: Color = .white, aa: Float? = nil) {
        let aa = aa ?? currentShapeAA
        let halfW = rect.width / 2
        let halfH = rect.height / 2
        // Extend the quad so there is room for the AA fringe (and for the stroke
        // half-width that falls outside the rect boundary when stroke > 0).
        let pad = (stroke > 0 ? stroke / 2 : 0) + aa
        let tint = currentColor
        let modulated = SIMD4<Float>(color.r * tint.r, color.g * tint.g,
                                     color.b * tint.b, color.a * tint.a)
        let t = currentTransform
        let p0 = t.transform(SIMD2(rect.minX - pad, rect.minY - pad))
        let p1 = t.transform(SIMD2(rect.maxX + pad, rect.minY - pad))
        let p2 = t.transform(SIMD2(rect.maxX + pad, rect.maxY + pad))
        let p3 = t.transform(SIMD2(rect.minX - pad, rect.maxY + pad))
        // UVs are box-local coordinates centred at the rect's centre (in world units).
        // uv.x ∈ [−(halfW+pad), +(halfW+pad)] maps 1:1 to the local x axis, so the
        // fragment shader receives the exact local position for the box SDF.
        let uv0 = SIMD2<Float>(-(halfW + pad), -(halfH + pad))
        let uv1 = SIMD2<Float>( (halfW + pad), -(halfH + pad))
        let uv2 = SIMD2<Float>( (halfW + pad),  (halfH + pad))
        let uv3 = SIMD2<Float>(-(halfW + pad),  (halfH + pad))
        // Pass the box half-extents via attributes.xy so the fragment shader can
        // evaluate sdBox(uv, halfExtents) without knowing the quad dimensions.
        emitSDFQuadCorners(
            p0: p0, uv0: uv0, p1: p1, uv1: uv1,
            p2: p2, uv2: uv2, p3: p3, uv3: uv3,
            type: .box, color: modulated,
            radius: cornerRadius, stroke: stroke, aa: aa, fill: stroke <= 0 ? 1 : 0,
            attributes: SIMD4<Float>(halfW, halfH, 0, 0)
        )
    }

    /// Anti-aliased line segment with a given thickness.
    public func line(from a: SIMD2<Float>, to b: SIMD2<Float>, thickness: Float,
                     color: Color = .white, aa: Float? = nil) {
        let aa = aa ?? currentShapeAA
        let dir = b - a
        let len = simd_length(dir)
        guard len > 0 else { return }
        let d = dir / len
        let n = SIMD2<Float>(-d.y, d.x)
        let halfLen = len * 0.5
        let halfBand = thickness * 0.5 + aa
        let tint = currentColor
        let modulated = SIMD4<Float>(color.r * tint.r, color.g * tint.g, color.b * tint.b, color.a * tint.a)
        let t = currentTransform
        // Extend the quad by `aa` past each endpoint so the end caps have room to fade.
        let mid = (a + b) * 0.5
        let tp0 = t.transform(mid - d * (halfLen + aa) + n * halfBand)
        let tp1 = t.transform(mid + d * (halfLen + aa) + n * halfBand)
        let tp2 = t.transform(mid + d * (halfLen + aa) - n * halfBand)
        let tp3 = t.transform(mid - d * (halfLen + aa) - n * halfBand)
        // UVs in line-centred coordinates: x along the segment (0 = midpoint),
        // y perpendicular. Both axes are in world units so sdRoundBox can use them directly.
        let uvTL = SIMD2<Float>(-(halfLen + aa),  halfBand)
        let uvTR = SIMD2<Float>( (halfLen + aa),  halfBand)
        let uvBR = SIMD2<Float>( (halfLen + aa), -halfBand)
        let uvBL = SIMD2<Float>(-(halfLen + aa), -halfBand)
        emitSDFQuadCorners(
            p0: tp0, uv0: uvTL,
            p1: tp1, uv1: uvTR,
            p2: tp2, uv2: uvBR,
            p3: tp3, uv3: uvBL,
            type: .line, color: modulated,
            radius: 0, stroke: thickness, aa: aa, fill: 0,
            attributes: SIMD4<Float>(halfLen, 0, 0, 0)
        )
    }

    /// Filled or outlined capsule: a segment `a`→`b` with rounded ends of `radius`.
    /// `stroke` 0 fills; `> 0` draws an outline of that thickness centred on the boundary.
    public func capsule(from a: SIMD2<Float>, to b: SIMD2<Float>, radius: Float,
                        stroke: Float = 0, color: Color = .white, aa: Float? = nil) {
        let aa = aa ?? currentShapeAA
        let dir = b - a
        let len = simd_length(dir)
        let d = len > 1e-6 ? dir / len : SIMD2<Float>(1, 0)
        let n = SIMD2<Float>(-d.y, d.x)
        let halfLen = len * 0.5
        // Round caps reach `radius` past each endpoint; add `aa` for the fade and the
        // stroke half-width that spills outside the boundary when stroked.
        let pad = radius + (stroke > 0 ? stroke * 0.5 : 0) + aa
        let halfBand = pad
        let tint = currentColor
        let modulated = SIMD4<Float>(color.r * tint.r, color.g * tint.g,
                                     color.b * tint.b, color.a * tint.a)
        let t = currentTransform
        let mid = (a + b) * 0.5
        let tp0 = t.transform(mid - d * (halfLen + pad) + n * halfBand)
        let tp1 = t.transform(mid + d * (halfLen + pad) + n * halfBand)
        let tp2 = t.transform(mid + d * (halfLen + pad) - n * halfBand)
        let tp3 = t.transform(mid - d * (halfLen + pad) - n * halfBand)
        let uvTL = SIMD2<Float>(-(halfLen + pad),  halfBand)
        let uvTR = SIMD2<Float>( (halfLen + pad),  halfBand)
        let uvBR = SIMD2<Float>( (halfLen + pad), -halfBand)
        let uvBL = SIMD2<Float>(-(halfLen + pad), -halfBand)
        emitSDFQuadCorners(
            p0: tp0, uv0: uvTL,
            p1: tp1, uv1: uvTR,
            p2: tp2, uv2: uvBR,
            p3: tp3, uv3: uvBL,
            type: .capsule, color: modulated,
            radius: radius, stroke: stroke, aa: aa, fill: stroke <= 0 ? 1 : 0,
            attributes: SIMD4<Float>(halfLen, 0, 0, 0)
        )
    }

    /// Debug-draw a collision circle as a thin ring. A zero-length stroked capsule is a
    /// ring of the given radius, so it reuses the capsule path (no stroked-circle branch needed).
    public func debug(_ c: Circle, color: Color = Color(r: 0, g: 1, b: 0),
                      stroke: Float = 1) {
        capsule(from: c.center, to: c.center, radius: c.radius, stroke: stroke, color: color)
    }

    /// Debug-draw a collision AABB as a thin box outline.
    public func debug(_ b: AABB, color: Color = Color(r: 0, g: 1, b: 0),
                      stroke: Float = 1) {
        box(b.rect, stroke: stroke, color: color)
    }

    /// Debug-draw a collision capsule as a thin outline.
    public func debug(_ cap: Capsule, color: Color = Color(r: 0, g: 1, b: 0),
                      stroke: Float = 1) {
        capsule(from: cap.a, to: cap.b, radius: cap.radius, stroke: stroke, color: color)
    }

    /// Debug-draw a collision polygon as a closed outline of line segments (one per edge).
    public func debug(_ poly: Polygon, color: Color = Color(r: 0, g: 1, b: 0),
                      stroke: Float = 1) {
        let vs = poly.vertices
        guard vs.count >= 2 else { return }
        for i in 0..<vs.count {
            line(from: vs[i], to: vs[(i + 1) % vs.count], thickness: stroke, color: color)
        }
    }

    /// Debug-draw a collision half-space as a long line along its boundary (through `point`,
    /// perpendicular to `normal`). `extent` is the half-length of the drawn segment.
    public func debug(_ half: Halfspace, color: Color = Color(r: 0, g: 1, b: 0),
                      stroke: Float = 1, extent: Float = 1000) {
        let tangent = SIMD2<Float>(-half.normal.y, half.normal.x)
        line(from: half.point - tangent * extent, to: half.point + tangent * extent,
             thickness: stroke, color: color)
    }

    // MARK: - Internal SDF emission helpers

    private func emitSDFQuad(type: ShapeType, bounds: Rect, color: Color,
                             localExtent: Float, radius: Float, stroke: Float, aa: Float, fill: Float) {
        let t = currentTransform
        let tint = currentColor
        let modulated = SIMD4<Float>(color.r * tint.r, color.g * tint.g, color.b * tint.b, color.a * tint.a)
        let p0 = t.transform(SIMD2(bounds.minX, bounds.minY))
        let p1 = t.transform(SIMD2(bounds.maxX, bounds.minY))
        let p2 = t.transform(SIMD2(bounds.maxX, bounds.maxY))
        let p3 = t.transform(SIMD2(bounds.minX, bounds.maxY))
        // UVs map the quad to [-localExtent, +localExtent] in both axes — used as SDF input.
        let uv0 = SIMD2<Float>(-localExtent, -localExtent)
        let uv1 = SIMD2<Float>( localExtent, -localExtent)
        let uv2 = SIMD2<Float>( localExtent,  localExtent)
        let uv3 = SIMD2<Float>(-localExtent,  localExtent)
        emitSDFQuadCorners(
            p0: p0, uv0: uv0,
            p1: p1, uv1: uv1,
            p2: p2, uv2: uv2,
            p3: p3, uv3: uv3,
            type: type, color: modulated,
            radius: radius, stroke: stroke, aa: aa, fill: fill
        )
    }

    private func emitSDFQuadCorners(
        p0: SIMD2<Float>, uv0: SIMD2<Float>,
        p1: SIMD2<Float>, uv1: SIMD2<Float>,
        p2: SIMD2<Float>, uv2: SIMD2<Float>,
        p3: SIMD2<Float>, uv3: SIMD2<Float>,
        type: ShapeType, color: SIMD4<Float>,
        radius: Float, stroke: Float, aa: Float, fill: Float,
        attributes: SIMD4<Float> = .zero
    ) {
        // No texture bound for SDF shapes — leave whatever the batcher had.
        // (The fragment shader branches on type so the texture is ignored.)
        func v(_ p: SIMD2<Float>, _ uv: SIMD2<Float>) -> Vertex {
            Vertex(pos: p, uv: uv, color: color,
                   radius: radius, stroke: stroke, aa: aa, type: type.rawValue,
                   alpha: 1, fill: fill, attributes: attributes)
        }
        batcher.append(v(p0, uv0))
        batcher.append(v(p1, uv1))
        batcher.append(v(p2, uv2))
        batcher.append(v(p0, uv0))
        batcher.append(v(p2, uv2))
        batcher.append(v(p3, uv3))
    }
}
