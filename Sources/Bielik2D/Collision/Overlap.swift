#if canImport(simd)
import simd
#else
import kvSIMD
#endif

extension Circle {
    public func overlaps(_ o: Circle) -> Bool {
        let r = radius + o.radius
        return simd_distance_squared(center, o.center) <= r * r
    }
    public func overlaps(_ o: AABB) -> Bool {
        simd_distance_squared(center, closestPointOnAABB(center, o)) <= radius * radius
    }
    public func overlaps(_ o: Capsule) -> Bool {
        let cp = closestPointOnSegment(center, o.a, o.b)
        let r = radius + o.radius
        return simd_distance_squared(center, cp) <= r * r
    }
}

extension AABB {
    public func overlaps(_ o: Circle) -> Bool { o.overlaps(self) }
    public func overlaps(_ o: AABB) -> Bool {
        min.x <= o.max.x && max.x >= o.min.x &&
        min.y <= o.max.y && max.y >= o.min.y
    }
    public func overlaps(_ o: Capsule) -> Bool {
        let (cs, ce) = segmentAABBClosest(o.a, o.b, self)
        return simd_distance_squared(cs, ce) <= o.radius * o.radius
    }
}

extension Capsule {
    public func overlaps(_ o: Circle) -> Bool { o.overlaps(self) }
    public func overlaps(_ o: AABB) -> Bool { o.overlaps(self) }
    public func overlaps(_ o: Capsule) -> Bool {
        let (c1, c2) = segmentSegmentClosest(a, b, o.a, o.b)
        let r = radius + o.radius
        return simd_distance_squared(c1, c2) <= r * r
    }
}
