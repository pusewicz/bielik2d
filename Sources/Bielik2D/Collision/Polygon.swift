#if canImport(simd)
import simd
#else
import kvSIMD
#endif

extension Polygon {
    /// Builds a convex polygon (CCW) as the convex hull of arbitrary points, via Andrew's
    /// monotone chain. Duplicate points are dropped; fully collinear inputs collapse to the two
    /// extreme endpoints; fewer than three distinct points pass through unchanged.
    public init(hull points: [SIMD2<Float>]) {
        self.init(vertices: convexHullCCW(points))
    }
}

/// Convex hull of `points` in counter-clockwise order (Andrew's monotone chain). Collinear points
/// on hull edges are removed. Returns the input (deduplicated) when it has fewer than three points.
func convexHullCCW(_ points: [SIMD2<Float>]) -> [SIMD2<Float>] {
    // Deduplicate near-coincident points.
    var pts: [SIMD2<Float>] = []
    for p in points where !pts.contains(where: { simd_distance_squared($0, p) < 1e-12 }) {
        pts.append(p)
    }
    guard pts.count >= 3 else { return pts }

    pts.sort { $0.x < $1.x || ($0.x == $1.x && $0.y < $1.y) }

    // Cross product of (o->a) x (o->b); > 0 is a left (CCW) turn.
    func cross(_ o: SIMD2<Float>, _ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
    }

    var lower: [SIMD2<Float>] = []
    for p in pts {
        while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 {
            lower.removeLast()
        }
        lower.append(p)
    }
    var upper: [SIMD2<Float>] = []
    for p in pts.reversed() {
        while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 {
            upper.removeLast()
        }
        upper.append(p)
    }
    // Drop each chain's last point (it's the first point of the other chain).
    lower.removeLast()
    upper.removeLast()
    let hull = lower + upper
    // All points collinear: the chains collapse — return the two extreme endpoints.
    return hull.count >= 3 ? hull : [pts.first!, pts.last!]
}
