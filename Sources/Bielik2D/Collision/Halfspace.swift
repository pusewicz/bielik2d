#if canImport(simd)
import simd
#else
import kvSIMD
#endif

// Closed-form Halfspace queries (a half-space has no finite support, so it never enters GJK).
// The other shapes are reduced to their `Support` (core + radius): a shape overlaps the solid side
// when its deepest core point toward `-normal`, pushed out by its radius, crosses the boundary.

@inline(__always)
private func flipHS(_ m: Manifold?) -> Manifold? {
    guard let m else { return nil }
    return Manifold(normal: -m.normal, depth: m.depth, contact: m.contact)
}

extension Halfspace {
    /// Signed distance of the shape's nearest surface point to the boundary (negative = inside solid).
    private func nearestSigned(_ s: Support) -> (signed: Float, surface: SIMD2<Float>) {
        let deepestCore = s.support(-normal)
        let signed = simd_dot(normal, deepestCore - point) - s.radius
        return (signed, deepestCore - normal * s.radius)
    }

    private func hsOverlap(_ s: Support) -> Bool { nearestSigned(s).signed <= 0 }

    private func hsManifold(_ s: Support) -> Manifold? {
        let (signed, surface) = nearestSigned(s)
        guard signed <= 0 else { return nil }
        // normal = self.normal (self→other); separate the other shape by moving it +normal*depth.
        return Manifold(normal: normal, depth: -signed, contact: surface)
    }

    public func overlaps(_ o: Circle) -> Bool { hsOverlap(o.support) }
    public func overlaps(_ o: AABB) -> Bool { hsOverlap(o.support) }
    public func overlaps(_ o: Capsule) -> Bool { hsOverlap(o.support) }
    public func overlaps(_ o: Polygon) -> Bool { hsOverlap(o.support) }

    public func manifold(with o: Circle) -> Manifold? { hsManifold(o.support) }
    public func manifold(with o: AABB) -> Manifold? { hsManifold(o.support) }
    public func manifold(with o: Capsule) -> Manifold? { hsManifold(o.support) }
    public func manifold(with o: Polygon) -> Manifold? { hsManifold(o.support) }
}

extension Circle {
    public func overlaps(_ o: Halfspace) -> Bool { o.overlaps(self) }
    public func manifold(with o: Halfspace) -> Manifold? { flipHS(o.manifold(with: self)) }
}
extension AABB {
    public func overlaps(_ o: Halfspace) -> Bool { o.overlaps(self) }
    public func manifold(with o: Halfspace) -> Manifold? { flipHS(o.manifold(with: self)) }
}
extension Capsule {
    public func overlaps(_ o: Halfspace) -> Bool { o.overlaps(self) }
    public func manifold(with o: Halfspace) -> Manifold? { flipHS(o.manifold(with: self)) }
}
extension Polygon {
    public func overlaps(_ o: Halfspace) -> Bool { o.overlaps(self) }
    public func manifold(with o: Halfspace) -> Manifold? { flipHS(o.manifold(with: self)) }
}

extension Ray {
    /// Ray vs the half-space boundary line. The hit normal faces back toward the ray origin.
    public func cast(against h: Halfspace) -> Raycast? {
        let denom = simd_dot(h.normal, direction)
        if abs(denom) < 1e-8 { return nil }                  // parallel to the boundary
        let t = simd_dot(h.normal, h.point - origin) / denom
        if t < 0 || t > length { return nil }
        let n = denom < 0 ? h.normal : -h.normal
        return Raycast(t: t, point: origin + direction * t, normal: n)
    }
}
