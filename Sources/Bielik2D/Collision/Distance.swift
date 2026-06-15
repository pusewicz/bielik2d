#if canImport(simd)
import simd
#else
import kvSIMD
#endif

/// Result of a closest-points query between two convex shapes. `distance` is the gap between their
/// surfaces (0 when they overlap). `pointA`/`pointB` are the witness points on `self`/`other`.
public struct Distance: Equatable, Sendable {
    public var distance: Float
    public var pointA: SIMD2<Float>
    public var pointB: SIMD2<Float>
    public init(distance: Float, pointA: SIMD2<Float>, pointB: SIMD2<Float>) {
        self.distance = distance
        self.pointA = pointA
        self.pointB = pointB
    }
    /// The same result viewed from the other shape (swaps the witness points).
    var swapped: Distance { Distance(distance: distance, pointA: pointB, pointB: pointA) }
}

/// GJK-backed closest points between two cores, with radius margins applied to push witnesses onto
/// the actual surfaces. `pointA` lies on `a`, `pointB` on `b`.
func gjkDistanceQuery(_ a: Support, _ b: Support) -> Distance {
    switch gjkDistance(a, b) {
    case let .separated(d, pa, pb, normal):
        let surface = max(d - a.radius - b.radius, 0)
        return Distance(distance: surface, pointA: pa + normal * a.radius, pointB: pb - normal * b.radius)
    case let .penetrating(simplex):
        let epa = epaPenetration(simplex, a, b)
        return Distance(distance: 0,
                        pointA: epa.witnessA + epa.normal * a.radius,
                        pointB: epa.witnessB - epa.normal * b.radius)
    }
}

extension Polygon {
    public func distance(to o: Polygon) -> Distance { gjkDistanceQuery(support, o.support) }
    public func distance(to o: Circle) -> Distance { gjkDistanceQuery(support, o.support) }
    public func distance(to o: AABB) -> Distance { gjkDistanceQuery(support, o.support) }
    public func distance(to o: Capsule) -> Distance { gjkDistanceQuery(support, o.support) }
}

extension Circle { public func distance(to o: Polygon) -> Distance { o.distance(to: self).swapped } }
extension AABB { public func distance(to o: Polygon) -> Distance { o.distance(to: self).swapped } }
extension Capsule { public func distance(to o: Polygon) -> Distance { o.distance(to: self).swapped } }
