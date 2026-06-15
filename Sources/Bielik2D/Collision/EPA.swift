#if canImport(simd)
import simd
#else
import kvSIMD
#endif

/// Penetration data from EPA, in CORE terms (shape radii applied by the caller).
struct EPAResult {
    var normal: SIMD2<Float>   // outward normal of the Minkowski difference (A⊖B); points A→B
    var depth: Float           // core penetration depth
    var witnessA: SIMD2<Float>
    var witnessB: SIMD2<Float>
}

/// 2D Expanding Polytope Algorithm. Grows the terminal origin-enclosing GJK triangle until the
/// closest polytope edge to the origin stops expanding; that edge gives the penetration normal,
/// depth, and (via barycentric projection) the contact witness points.
func epaPenetration(_ simplex: [SupportVert], _ A: Support, _ B: Support) -> EPAResult {
    var poly = simplex
    if signedAreaP(poly) < 0 { poly.reverse() }   // EPA assumes CCW
    let maxIters = 64
    let eps: Float = 1e-6

    func closestEdge() -> (dist: Float, index: Int, normal: SIMD2<Float>) {
        var minDist = Float.greatestFiniteMagnitude
        var minIndex = 0
        var minNormal = SIMD2<Float>(0, 1)
        for i in 0..<poly.count {
            let j = (i + 1) % poly.count
            let e = poly[j].p - poly[i].p
            let lensq = simd_length_squared(e)
            if lensq < 1e-18 { continue }                 // skip degenerate edge
            let n = SIMD2(e.y, -e.x) / lensq.squareRoot() // outward normal for CCW winding
            let d = simd_dot(n, poly[i].p)
            if d < minDist { minDist = d; minIndex = i; minNormal = n }
        }
        return (minDist, minIndex, minNormal)
    }

    func makeResult(_ index: Int, _ normal: SIMD2<Float>, _ depth: Float) -> EPAResult {
        let i = index, j = (index + 1) % poly.count
        let pi = poly[i].p, pj = poly[j].p
        let e = pj - pi
        let denom = simd_dot(e, e)
        let t = denom > 1e-12 ? min(max(simd_dot(-pi, e) / denom, 0), 1) : 0
        let wa = poly[i].a + (poly[j].a - poly[i].a) * t
        let wb = poly[i].b + (poly[j].b - poly[i].b) * t
        return EPAResult(normal: normal, depth: max(depth, 0), witnessA: wa, witnessB: wb)
    }

    for _ in 0..<maxIters {
        let edge = closestEdge()
        let w = minkowskiSupport(A, B, edge.normal)
        if simd_dot(edge.normal, w.p) - edge.dist < eps {
            return makeResult(edge.index, edge.normal, edge.dist)   // converged
        }
        poly.insert(w, at: edge.index + 1)
    }
    let edge = closestEdge()                                        // cap fallback: best so far
    return makeResult(edge.index, edge.normal, edge.dist)
}

/// Signed area (×2) of the polygon formed by the simplex's Minkowski points; > 0 is CCW.
private func signedAreaP(_ verts: [SupportVert]) -> Float {
    var a: Float = 0
    for i in 0..<verts.count {
        let p = verts[i].p, q = verts[(i + 1) % verts.count].p
        a += p.x * q.y - q.x * p.y
    }
    return a
}
