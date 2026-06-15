#if canImport(simd)
import simd
#else
import kvSIMD
#endif

// Public overlap/manifold queries for Polygon-involving pairs, backed by the GJK/EPA engine over the
// core+radius model. The existing closed-form primitive pairs are untouched; this file adds new
// overloads only. Manifold `normal` points self→other, matching the rest of the module.

/// Negates a reverse-direction manifold's normal (duplicated locally so `Manifolds.swift` stays
/// untouched; it keeps its own `private` copy).
@inline(__always)
private func flipPoly(_ m: Manifold?) -> Manifold? {
    guard let m else { return nil }
    return Manifold(normal: -m.normal, depth: m.depth, contact: m.contact)
}

/// True if the two cores are within `rA + rB` of each other (i.e. the shapes overlap).
func gjkOverlap(_ a: Support, _ b: Support) -> Bool {
    switch gjkDistance(a, b) {
    case let .separated(distance, _, _, _): return distance <= a.radius + b.radius
    case .penetrating: return true
    }
}

/// Manifold between two shapes via GJK (separated-but-within-margin) or EPA (cores interpenetrate).
/// `a` is the query shape (`self`); the normal points self→other.
func gjkManifold(_ a: Support, _ b: Support) -> Manifold? {
    let margin = a.radius + b.radius
    switch gjkDistance(a, b) {
    case let .separated(distance, pointA, _, normal):
        guard distance <= margin else { return nil }
        let depth = margin - distance
        return Manifold(normal: normal, depth: depth, contact: pointA + normal * a.radius)
    case let .penetrating(simplex):
        let epa = epaPenetration(simplex, a, b)
        let depth = epa.depth + margin
        return Manifold(normal: epa.normal, depth: depth, contact: epa.witnessA + epa.normal * a.radius)
    }
}

extension Polygon {
    public func overlaps(_ o: Polygon) -> Bool { gjkOverlap(support, o.support) }
    public func overlaps(_ o: Circle) -> Bool { gjkOverlap(support, o.support) }
    public func overlaps(_ o: AABB) -> Bool { gjkOverlap(support, o.support) }
    public func overlaps(_ o: Capsule) -> Bool { gjkOverlap(support, o.support) }
    public func manifold(with o: Polygon) -> Manifold? { gjkManifold(support, o.support) }
    public func manifold(with o: Circle) -> Manifold? { gjkManifold(support, o.support) }
    public func manifold(with o: AABB) -> Manifold? { gjkManifold(support, o.support) }
    public func manifold(with o: Capsule) -> Manifold? { gjkManifold(support, o.support) }
}

extension Circle {
    public func overlaps(_ o: Polygon) -> Bool { o.overlaps(self) }
    public func manifold(with o: Polygon) -> Manifold? { flipPoly(o.manifold(with: self)) }
}

extension AABB {
    public func overlaps(_ o: Polygon) -> Bool { o.overlaps(self) }
    public func manifold(with o: Polygon) -> Manifold? { flipPoly(o.manifold(with: self)) }
}

extension Capsule {
    public func overlaps(_ o: Polygon) -> Bool { o.overlaps(self) }
    public func manifold(with o: Polygon) -> Manifold? { flipPoly(o.manifold(with: self)) }
}
