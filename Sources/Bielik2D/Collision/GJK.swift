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
