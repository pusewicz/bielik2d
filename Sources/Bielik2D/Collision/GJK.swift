#if canImport(simd)
import simd
#else
import kvSIMD
#endif

// GJK / EPA operate on a shape's convex *core* (curved shapes reduced to a point or segment) plus a
// `radius` margin that is applied afterward. A `Support` yields the farthest core point along a
// direction. Halfspace has no finite support and is never represented this way.
struct Support {
    let radius: Float
    let support: (_ dir: SIMD2<Float>) -> SIMD2<Float>
}

extension Circle {
    var support: Support {
        let c = center
        return Support(radius: radius) { _ in c }
    }
}

extension Capsule {
    var support: Support {
        let a = a, b = b
        return Support(radius: radius) { dir in
            simd_dot(a, dir) >= simd_dot(b, dir) ? a : b
        }
    }
}

extension AABB {
    var support: Support {
        let lo = min, hi = max
        return Support(radius: 0) { dir in
            SIMD2(dir.x >= 0 ? hi.x : lo.x, dir.y >= 0 ? hi.y : lo.y)
        }
    }
}

extension Polygon {
    var support: Support {
        let vs = vertices
        return Support(radius: 0) { dir in
            var best = vs[0]
            var bestDot = simd_dot(vs[0], dir)
            for i in 1..<vs.count {
                let d = simd_dot(vs[i], dir)
                if d > bestDot { bestDot = d; best = vs[i] }
            }
            return best
        }
    }
}

/// A Minkowski-difference vertex: the support of A minus the support of B, with both witness
/// points retained so closest/contact points can be recovered via barycentric interpolation.
struct SupportVert {
    var a: SIMD2<Float>
    var b: SIMD2<Float>
    var p: SIMD2<Float>   // a - b
}

@inline(__always)
func minkowskiSupport(_ A: Support, _ B: Support, _ dir: SIMD2<Float>) -> SupportVert {
    let pa = A.support(dir)
    let pb = B.support(-dir)
    return SupportVert(a: pa, b: pb, p: pa - pb)
}

// MARK: - GJK distance

/// Outcome of `gjkDistance`. Distances/witnesses are CORE values (shape radii not yet applied).
enum GJKResult {
    /// Cores are disjoint. `normal` points from A toward B (self→other); `distance = |closest|`.
    case separated(distance: Float, pointA: SIMD2<Float>, pointB: SIMD2<Float>, normal: SIMD2<Float>)
    /// Cores interpenetrate; the terminal triangle encloses the origin (seed for EPA).
    case penetrating(simplex: [SupportVert])
}

private struct Reduction {
    var closest: SIMD2<Float>
    var simplex: [SupportVert]
    var witnessA: SIMD2<Float>
    var witnessB: SIMD2<Float>
    var contains: Bool
}

private func vertexReduction(_ x: SupportVert) -> Reduction {
    Reduction(closest: x.p, simplex: [x], witnessA: x.a, witnessB: x.b, contains: false)
}

private func edgeReduction(_ x: SupportVert, _ y: SupportVert, _ t: Float) -> Reduction {
    Reduction(closest: x.p + (y.p - x.p) * t,
              simplex: [x, y],
              witnessA: x.a + (y.a - x.a) * t,
              witnessB: x.b + (y.b - x.b) * t,
              contains: false)
}

/// Closest point on the simplex (1–3 verts) to the origin, reduced to the minimal supporting
/// feature. For a triangle whose face region contains the origin, `contains` is true.
/// (Voronoi-region test after Ericson, Real-Time Collision Detection.)
private func reduceSimplex(_ s: [SupportVert]) -> Reduction {
    switch s.count {
    case 1:
        return vertexReduction(s[0])
    case 2:
        let a = s[0], b = s[1]
        let ab = b.p - a.p
        let denom = simd_dot(ab, ab)
        guard denom > 1e-12 else { return vertexReduction(a) }
        let t = simd_dot(-a.p, ab) / denom
        if t <= 0 { return vertexReduction(a) }
        if t >= 1 { return vertexReduction(b) }
        return edgeReduction(a, b, t)
    default:
        let A = s[0], B = s[1], C = s[2]
        let a = A.p, b = B.p, c = C.p
        let ab = b - a, ac = c - a
        let d1 = simd_dot(ab, -a), d2 = simd_dot(ac, -a)
        if d1 <= 0 && d2 <= 0 { return vertexReduction(A) }
        let d3 = simd_dot(ab, -b), d4 = simd_dot(ac, -b)
        if d3 >= 0 && d4 <= d3 { return vertexReduction(B) }
        let vc = d1 * d4 - d3 * d2
        if vc <= 0 && d1 >= 0 && d3 <= 0 { return edgeReduction(A, B, d1 / (d1 - d3)) }
        let d5 = simd_dot(ab, -c), d6 = simd_dot(ac, -c)
        if d6 >= 0 && d5 <= d6 { return vertexReduction(C) }
        let vb = d5 * d2 - d1 * d6
        if vb <= 0 && d2 >= 0 && d6 <= 0 { return edgeReduction(A, C, d2 / (d2 - d6)) }
        let va = d3 * d6 - d5 * d4
        if va <= 0 && (d4 - d3) >= 0 && (d5 - d6) >= 0 {
            return edgeReduction(B, C, (d4 - d3) / ((d4 - d3) + (d5 - d6)))
        }
        return Reduction(closest: .zero, simplex: s, witnessA: .zero, witnessB: .zero, contains: true)
    }
}

/// 2D GJK between two convex cores. Returns the closest distance + witness points when disjoint,
/// or a terminal origin-enclosing triangle when the cores overlap.
func gjkDistance(_ A: Support, _ B: Support) -> GJKResult {
    let maxIters = 32
    let epsDir: Float = 1e-12
    let epsProgress: Float = 1e-10

    var simplex = [minkowskiSupport(A, B, SIMD2(1, 0))]
    var reduction = reduceSimplex(simplex)
    var v = reduction.closest
    simplex = reduction.simplex

    for _ in 0..<maxIters {
        if simd_length_squared(v) < epsDir { return .penetrating(simplex: simplex) }
        let dir = -v
        let w = minkowskiSupport(A, B, dir)
        // No measurable progress toward the origin -> converged on the closest feature.
        if simd_length_squared(v) - simd_dot(w.p, v) < epsProgress {
            break
        }
        simplex.append(w)
        reduction = reduceSimplex(simplex)
        if reduction.contains { return .penetrating(simplex: simplex) }
        v = reduction.closest
        simplex = reduction.simplex
    }

    let dist = simd_length(v)
    let normal = dist > epsDir ? -v / dist : SIMD2<Float>(1, 0)
    return .separated(distance: dist, pointA: reduction.witnessA, pointB: reduction.witnessB, normal: normal)
}
