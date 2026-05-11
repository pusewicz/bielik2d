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
}

extension Draw {
    /// Filled circle in world space, with antialiased edge.
    public func circleFill(center: SIMD2<Float>, radius: Float, color: Color = .white, aa: Float = 1.5) {
        // Slightly larger quad to give AA room.
        let pad = aa
        let extent = radius + pad
        let bounds = Rect(x: center.x - extent, y: center.y - extent, width: 2 * extent, height: 2 * extent)
        emitSDFQuad(type: .circle, bounds: bounds, color: color,
                    localExtent: extent, radius: radius, stroke: 0, aa: aa, fill: 1)
    }

    /// Outline (or rounded) box. `stroke` 0 means filled. `corner` 0 means sharp.
    public func box(_ rect: Rect, stroke: Float = 0, cornerRadius: Float = 0,
                    color: Color = .white, aa: Float = 1.5) {
        emitSDFQuad(type: .box, bounds: rect, color: color,
                    localExtent: max(rect.width, rect.height) / 2,
                    radius: cornerRadius, stroke: stroke, aa: aa, fill: stroke <= 0 ? 1 : 0)
    }

    /// Anti-aliased line segment with a given thickness.
    public func line(from a: SIMD2<Float>, to b: SIMD2<Float>, thickness: Float,
                     color: Color = .white, aa: Float = 1.5) {
        // Build a rotated bounding quad around the segment.
        let dir = b - a
        let len = simd_length(dir)
        guard len > 0 else { return }
        let n = SIMD2<Float>(-dir.y, dir.x) / len
        let half = thickness * 0.5 + aa
        let p0 = a + n * half
        let p1 = b + n * half
        let p2 = b - n * half
        let p3 = a - n * half
        let tint = currentColor
        let modulated = SIMD4<Float>(color.r * tint.r, color.g * tint.g, color.b * tint.b, color.a * tint.a)

        let t = currentTransform
        let tp0 = t.transform(p0)
        let tp1 = t.transform(p1)
        let tp2 = t.transform(p2)
        let tp3 = t.transform(p3)

        // UVs encode signed distance from segment along the major and minor axes.
        let uvL = SIMD2<Float>(0, 1)
        let uvR = SIMD2<Float>(0, -1)
        emitSDFQuadCorners(
            p0: tp0, uv0: uvL,
            p1: tp1, uv1: uvL,
            p2: tp2, uv2: uvR,
            p3: tp3, uv3: uvR,
            type: .line, color: modulated,
            radius: 0, stroke: thickness, aa: aa, fill: 0
        )
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
        radius: Float, stroke: Float, aa: Float, fill: Float
    ) {
        // No texture bound for SDF shapes — leave whatever the batcher had.
        // (The fragment shader branches on type so the texture is ignored.)
        func v(_ p: SIMD2<Float>, _ uv: SIMD2<Float>) -> Vertex {
            Vertex(pos: p, uv: uv, color: color,
                   radius: radius, stroke: stroke, aa: aa, type: type.rawValue,
                   alpha: 1, fill: fill)
        }
        batcher.append(v(p0, uv0))
        batcher.append(v(p1, uv1))
        batcher.append(v(p2, uv2))
        batcher.append(v(p0, uv0))
        batcher.append(v(p2, uv2))
        batcher.append(v(p3, uv3))
    }
}
