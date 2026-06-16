#if canImport(simd)
import simd
#else
import kvSIMD
#endif

// Scalar math (`sqrt`); `simd` supplies it on Apple but `kvSIMD` does not.
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#endif

extension Ray {
    public func cast(against c: Circle) -> Raycast? {
        let m = origin - c.center
        let b = simd_dot(m, direction)
        let cc = simd_dot(m, m) - c.radius * c.radius
        if cc > 0 && b > 0 { return nil }           // origin outside, pointing away
        let discr = b * b - cc
        if discr < 0 { return nil }                 // ray misses the circle
        var t = -b - sqrt(discr)
        if t < 0 { t = 0 }                          // origin inside the circle
        if t > length { return nil }
        let point = origin + direction * t
        let normal = simd_normalize(point - c.center)
        return Raycast(t: t, point: point, normal: normal)
    }

    public func cast(against box: AABB) -> Raycast? {
        var tmin: Float = 0
        var tmax: Float = length
        var hitNormal = SIMD2<Float>(0, 0)
        for axis in 0..<2 {
            let o = origin[axis], d = direction[axis]
            let lo = box.min[axis], hi = box.max[axis]
            if abs(d) < 1e-8 {
                if o < lo || o > hi { return nil }  // parallel and outside the slab
            } else {
                let inv = 1 / d
                var t1 = (lo - o) * inv
                var t2 = (hi - o) * inv
                var n: SIMD2<Float> = axis == 0 ? SIMD2(-1, 0) : SIMD2(0, -1)
                if t1 > t2 { swap(&t1, &t2); n = -n }
                if t1 > tmin { tmin = t1; hitNormal = n }
                if t2 < tmax { tmax = t2 }
                if tmin > tmax { return nil }
            }
        }
        return Raycast(t: tmin, point: origin + direction * tmin, normal: hitNormal)
    }

    public func cast(against cap: Capsule) -> Raycast? {
        var best: Raycast? = nil
        func consider(_ r: Raycast?) {
            if let r, best == nil || r.t < best!.t { best = r }
        }
        consider(cast(against: Circle(center: cap.a, radius: cap.radius)))
        consider(cast(against: Circle(center: cap.b, radius: cap.radius)))
        let axis = cap.b - cap.a
        let len = simd_length(axis)
        if len > 1e-6 {
            let n = SIMD2<Float>(-axis.y, axis.x) / len
            for s in [Float(1), Float(-1)] {
                let off = n * (cap.radius * s)
                consider(raySegment(cap.a + off, cap.b + off, sideNormal: n * s))
            }
        }
        return best
    }

    /// Ray vs a thin segment `p0`→`p1`. `sideNormal` is the outward normal returned on hit.
    private func raySegment(_ p0: SIMD2<Float>, _ p1: SIMD2<Float>,
                            sideNormal: SIMD2<Float>) -> Raycast? {
        let e = p1 - p0
        let denom = direction.x * e.y - direction.y * e.x   // cross(direction, e)
        if abs(denom) < 1e-8 { return nil }                 // parallel
        let diff = p0 - origin
        let t = (diff.x * e.y - diff.y * e.x) / denom        // distance along the ray
        let u = (diff.x * direction.y - diff.y * direction.x) / denom  // param along segment
        if t < 0 || t > length || u < 0 || u > 1 { return nil }
        return Raycast(t: t, point: origin + direction * t, normal: sideNormal)
    }
}

extension Ray {
    /// Ray vs a convex polygon: the nearest edge crossing within `length`. The hit normal faces
    /// back toward the ray origin. Winding-agnostic (works for CW or CCW vertices).
    public func cast(against poly: Polygon) -> Raycast? {
        let vs = poly.vertices
        guard vs.count >= 2 else { return nil }
        var best: Raycast? = nil
        for i in 0..<vs.count {
            let p0 = vs[i], p1 = vs[(i + 1) % vs.count]
            let e = p1 - p0
            let denom = direction.x * e.y - direction.y * e.x   // cross(direction, e)
            if abs(denom) < 1e-8 { continue }                   // parallel to this edge
            let diff = p0 - origin
            let t = (diff.x * e.y - diff.y * e.x) / denom        // distance along the ray
            let u = (diff.x * direction.y - diff.y * direction.x) / denom  // param along edge
            if t < 0 || t > length || u < 0 || u > 1 { continue }
            var n = simd_normalize(SIMD2(e.y, -e.x))
            if simd_dot(n, direction) > 0 { n = -n }             // face back toward origin
            if best == nil || t < best!.t {
                best = Raycast(t: t, point: origin + direction * t, normal: n)
            }
        }
        return best
    }
}
