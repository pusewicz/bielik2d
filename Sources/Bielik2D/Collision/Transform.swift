#if canImport(simd)
import simd
#else
import kvSIMD
#endif

extension Circle {
    /// A copy translated by `v`.
    public func translated(by v: SIMD2<Float>) -> Circle {
        Circle(center: center + v, radius: radius)
    }
}

extension AABB {
    /// A copy translated by `v`.
    public func translated(by v: SIMD2<Float>) -> AABB {
        AABB(min: min + v, max: max + v)
    }
}

extension Capsule {
    /// A copy translated by `v`.
    public func translated(by v: SIMD2<Float>) -> Capsule {
        Capsule(a: a + v, b: b + v, radius: radius)
    }
}

extension Polygon {
    /// A copy translated by `v`.
    public func translated(by v: SIMD2<Float>) -> Polygon {
        Polygon(vertices: vertices.map { $0 + v })
    }
}
