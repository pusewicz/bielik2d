#if canImport(simd)
import simd
#else
import kvSIMD
#endif

// Manifold `normal` points from the query shape (`self`) toward the other shape.
// Separate by moving `self` by `-normal * depth`. Reverse pairs delegate and negate.

@inline(__always)
private func flip(_ m: Manifold?) -> Manifold? {
    guard let m else { return nil }
    return Manifold(normal: -m.normal, depth: m.depth, contact: m.contact)
}

extension Circle {
    public func manifold(with o: Circle) -> Manifold? {
        let delta = o.center - center
        let dist = simd_length(delta)
        let r = radius + o.radius
        guard dist <= r else { return nil }
        let normal = dist > 1e-6 ? delta / dist : SIMD2<Float>(0, 1)
        return Manifold(normal: normal, depth: r - dist, contact: center + normal * radius)
    }

    public func manifold(with o: AABB) -> Manifold? {
        let cp = closestPointOnAABB(center, o)
        let delta = cp - center
        let distSq = simd_length_squared(delta)
        guard distSq <= radius * radius else {
            // Centre may be inside the box (closest point == centre); handle below.
            if o.contains(center) { return manifoldFromInsideAABB(o) }
            return nil
        }
        if distSq > 1e-12 {
            let dist = sqrt(distSq)
            let normal = delta / dist
            return Manifold(normal: normal, depth: radius - dist, contact: center + normal * radius)
        }
        return manifoldFromInsideAABB(o)
    }

    /// Circle centre is inside the box: push out along the nearest face.
    private func manifoldFromInsideAABB(_ o: AABB) -> Manifold {
        let toMinX = center.x - o.min.x, toMaxX = o.max.x - center.x
        let toMinY = center.y - o.min.y, toMaxY = o.max.y - center.y
        let m = min(min(toMinX, toMaxX), min(toMinY, toMaxY))
        let normal: SIMD2<Float>
        if m == toMinX { normal = SIMD2(-1, 0) }
        else if m == toMaxX { normal = SIMD2(1, 0) }
        else if m == toMinY { normal = SIMD2(0, -1) }
        else { normal = SIMD2(0, 1) }
        return Manifold(normal: normal, depth: radius + m, contact: center + normal * radius)
    }

    public func manifold(with o: Capsule) -> Manifold? {
        let cp = closestPointOnSegment(center, o.a, o.b)
        let delta = cp - center
        let dist = simd_length(delta)
        let r = radius + o.radius
        guard dist <= r else { return nil }
        let normal = dist > 1e-6 ? delta / dist : SIMD2<Float>(0, 1)
        return Manifold(normal: normal, depth: r - dist, contact: center + normal * radius)
    }
}

extension AABB {
    public func manifold(with o: Circle) -> Manifold? { flip(o.manifold(with: self)) }

    public func manifold(with o: AABB) -> Manifold? {
        let overlapX = Swift.min(max.x, o.max.x) - Swift.max(min.x, o.min.x)
        let overlapY = Swift.min(max.y, o.max.y) - Swift.max(min.y, o.min.y)
        guard overlapX >= 0 && overlapY >= 0 else { return nil }
        let ca = (min + max) * 0.5
        let cb = (o.min + o.max) * 0.5
        if overlapX < overlapY {
            let sign: Float = cb.x >= ca.x ? 1 : -1
            let contactX = sign > 0 ? max.x : min.x
            let contactY = (Swift.max(min.y, o.min.y) + Swift.min(max.y, o.max.y)) * 0.5
            return Manifold(normal: SIMD2(sign, 0), depth: overlapX, contact: SIMD2(contactX, contactY))
        } else {
            let sign: Float = cb.y >= ca.y ? 1 : -1
            let contactY = sign > 0 ? max.y : min.y
            let contactX = (Swift.max(min.x, o.min.x) + Swift.min(max.x, o.max.x)) * 0.5
            return Manifold(normal: SIMD2(0, sign), depth: overlapY, contact: SIMD2(contactX, contactY))
        }
    }

    public func manifold(with o: Capsule) -> Manifold? {
        let (onSeg, onBox) = segmentAABBClosest(o.a, o.b, self)
        let delta = onSeg - onBox            // from box toward the capsule's spine
        let dist = simd_length(delta)
        guard dist <= o.radius else { return nil }
        // Deep penetration (spine inside the box) gives a near-zero delta; fall back to the
        // box-vs-segment-midpoint direction so the normal stays well defined.
        let normal: SIMD2<Float>
        if dist > 1e-6 {
            normal = delta / dist
        } else {
            let mid = (o.a + o.b) * 0.5
            let c = (min + max) * 0.5
            let d = mid - c
            normal = simd_length(d) > 1e-6 ? simd_normalize(d) : SIMD2(0, 1)
        }
        return Manifold(normal: normal, depth: o.radius - dist, contact: onBox)
    }
}

extension Capsule {
    public func manifold(with o: Circle) -> Manifold? { flip(o.manifold(with: self)) }
    public func manifold(with o: AABB) -> Manifold? { flip(o.manifold(with: self)) }

    public func manifold(with o: Capsule) -> Manifold? {
        let (c1, c2) = segmentSegmentClosest(a, b, o.a, o.b)
        let delta = c2 - c1
        let dist = simd_length(delta)
        let r = radius + o.radius
        guard dist <= r else { return nil }
        let normal = dist > 1e-6 ? delta / dist : SIMD2<Float>(0, 1)
        return Manifold(normal: normal, depth: r - dist, contact: c1 + normal * radius)
    }
}
