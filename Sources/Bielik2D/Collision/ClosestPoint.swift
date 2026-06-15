#if canImport(simd)
import simd
#else
import kvSIMD
#endif

@inline(__always)
func clamp01(_ v: Float) -> Float { min(max(v, 0), 1) }

/// Closest point on segment `a`→`b` to `p`. Returns `a` for a degenerate segment.
func closestPointOnSegment(_ p: SIMD2<Float>, _ a: SIMD2<Float>, _ b: SIMD2<Float>) -> SIMD2<Float> {
    let ab = b - a
    let denom = simd_dot(ab, ab)
    guard denom > 1e-12 else { return a }
    let t = clamp01(simd_dot(p - a, ab) / denom)
    return a + ab * t
}

/// Closest point on (or inside) the AABB to `p`.
func closestPointOnAABB(_ p: SIMD2<Float>, _ box: AABB) -> SIMD2<Float> {
    SIMD2(
        min(max(p.x, box.min.x), box.max.x),
        min(max(p.y, box.min.y), box.max.y)
    )
}

/// Closest points between segment `p1`→`q1` and segment `p2`→`q2`.
/// Returns `(point on first, point on second)`. (Ericson, Real-Time Collision Detection.)
func segmentSegmentClosest(_ p1: SIMD2<Float>, _ q1: SIMD2<Float>,
                           _ p2: SIMD2<Float>, _ q2: SIMD2<Float>) -> (SIMD2<Float>, SIMD2<Float>) {
    let d1 = q1 - p1
    let d2 = q2 - p2
    let r = p1 - p2
    let a = simd_dot(d1, d1)
    let e = simd_dot(d2, d2)
    let f = simd_dot(d2, r)
    let eps: Float = 1e-12
    var s: Float = 0
    var t: Float = 0
    if a <= eps && e <= eps {
        return (p1, p2)                       // both segments are points
    }
    if a <= eps {
        s = 0
        t = clamp01(f / e)                    // first segment is a point
    } else {
        let c = simd_dot(d1, r)
        if e <= eps {
            t = 0
            s = clamp01(-c / a)               // second segment is a point
        } else {
            let b = simd_dot(d1, d2)
            let denom = a * e - b * b
            s = denom > eps ? clamp01((b * f - c * e) / denom) : 0
            t = (b * s + f) / e
            if t < 0 {
                t = 0
                s = clamp01(-c / a)
            } else if t > 1 {
                t = 1
                s = clamp01((b - c) / a)
            }
        }
    }
    return (p1 + d1 * s, p2 + d2 * t)
}

/// Closest points between segment `a0`→`a1` and the solid AABB.
/// Returns `(point on segment, point on box)`. Distance is 0 when the segment touches/enters the box.
func segmentAABBClosest(_ a0: SIMD2<Float>, _ a1: SIMD2<Float>, _ box: AABB) -> (SIMD2<Float>, SIMD2<Float>) {
    if box.contains(a0) { return (a0, a0) }
    if box.contains(a1) { return (a1, a1) }
    // Segment is outside (or crosses) the box: the nearest approach lies between the
    // segment and one of the four box edges (an interior crossing yields distance 0 there).
    let corners = [
        box.min,
        SIMD2(box.max.x, box.min.y),
        box.max,
        SIMD2(box.min.x, box.max.y),
    ]
    var best = (a0, corners[0])
    var bestDist = Float.greatestFiniteMagnitude
    for i in 0..<4 {
        let (cs, ce) = segmentSegmentClosest(a0, a1, corners[i], corners[(i + 1) % 4])
        let d = simd_distance(cs, ce)
        if d < bestDist {
            bestDist = d
            best = (cs, ce)
        }
    }
    return best
}
