#if canImport(simd)
import simd
#else
import kvSIMD
#endif

/// A continuous time-of-impact result for a swept shape.
/// `t` is the fraction of the sweep displacement at first contact (0...1);
/// `point` is the contact point; `normal` is the surface normal facing back toward the mover.
public struct ToI: Equatable, Sendable {
    public var t: Float
    public var point: SIMD2<Float>
    public var normal: SIMD2<Float>
    public init(t: Float, point: SIMD2<Float>, normal: SIMD2<Float>) {
        self.t = t
        self.point = point
        self.normal = normal
    }
}

extension Support {
    /// The same convex core rigidly translated by `o` (used to advance the mover during a sweep).
    func offset(by o: SIMD2<Float>) -> Support {
        let base = support
        return Support(radius: radius) { dir in base(dir) + o }
    }
}

/// Conservative advancement between two convex cores. `relDelta` is the mover's displacement
/// relative to the (static) target over the step; `t` in the result is the fraction of `relDelta`
/// consumed at first contact. Returns `nil` when the cores never touch within the sweep.
/// `gjkDistance`'s separated case carries the core distance and the mover->target normal directly.
func sweptTOIConvex(mover: Support, target: Support, relDelta: SIMD2<Float>) -> ToI? {
    let tol: Float = 1e-4
    let combined = mover.radius + target.radius
    if simd_length_squared(relDelta) < 1e-24 { return nil }   // no motion
    var t: Float = 0
    let maxIters = 32
    for _ in 0..<maxIters {
        let m = mover.offset(by: relDelta * t)
        switch gjkDistance(m, target) {
        case .penetrating(let simplex):
            let epa = epaPenetration(simplex, m, target)        // already overlapping at this t
            let contact = epa.witnessB - epa.normal * target.radius
            return ToI(t: t, point: contact, normal: -epa.normal)
        case .separated(let distance, _, let pb, let normal):
            let gap = distance - combined                       // true gap after applying radii
            if gap <= tol {
                let contact = pb - normal * target.radius
                return ToI(t: t, point: contact, normal: -normal)
            }
            let closing = simd_dot(relDelta, normal)            // closing speed along the normal
            if closing <= 1e-8 { return nil }                   // not approaching
            t += gap / closing
            if t > 1 { return nil }
        }
    }
    return nil                                                  // failed to converge -> treat as miss
}

/// Swept TOI of a convex `mover` against a `Halfspace`. The mover's nearest extent toward the
/// solid side (`support(-normal)`) closes against the plane at `-dot(relDelta, normal)`.
func sweptTOIHalfspace(mover: Support, plane: Halfspace, relDelta: SIMD2<Float>) -> ToI? {
    let tol: Float = 1e-4
    let n = plane.normal                                    // outward; solid side is -n
    let extent = mover.support(-n)                          // nearest core point toward the plane
    let gap = simd_dot(extent - plane.point, n) - mover.radius
    let closing = -simd_dot(relDelta, n)                    // >0 means moving toward the solid side
    if closing <= 1e-8 {                                    // parallel or receding
        guard gap <= tol else { return nil }
        return ToI(t: 0, point: extent - n * mover.radius, normal: n)
    }
    let t = gap / closing
    if t > 1 { return nil }
    let tt = max(t, 0)
    let contactExtent = extent + relDelta * tt
    return ToI(t: tt, point: contactExtent - n * mover.radius, normal: n)
}

/// Sweep a convex `mover` (already reduced to its `Support`) by `delta` against any collider,
/// with the target optionally moving by `targetDelta`. Convex targets go through GJK conservative
/// advancement; `Halfspace` uses the closed-form path (added in Task 4). Unsupported colliders
/// return `nil`. The core works in the target's rest frame, so the contact point is translated
/// back to world space here.
func sweepConvex(_ mover: Support, by delta: SIMD2<Float>, movedBy targetDelta: SIMD2<Float>,
                 against target: CollisionShape) -> ToI? {
    let relDelta = delta - targetDelta
    let result: ToI?
    switch target {
    case let c as Circle:   result = sweptTOIConvex(mover: mover, target: c.support, relDelta: relDelta)
    case let a as AABB:     result = sweptTOIConvex(mover: mover, target: a.support, relDelta: relDelta)
    case let c as Capsule:  result = sweptTOIConvex(mover: mover, target: c.support, relDelta: relDelta)
    case let p as Polygon:  result = sweptTOIConvex(mover: mover, target: p.support, relDelta: relDelta)
    case let h as Halfspace: result = sweptTOIHalfspace(mover: mover, plane: h, relDelta: relDelta)
    default:                result = nil
    }
    guard var toi = result else { return nil }
    toi.point += targetDelta * toi.t   // rest-frame contact -> world (no-op when targetDelta == .zero)
    return toi
}

extension Circle {
    /// Swept time-of-impact against any collider. `ToI.t` is the fraction of `delta` at first contact.
    public func sweep(by delta: SIMD2<Float>, against target: CollisionShape,
                      movedBy targetDelta: SIMD2<Float> = .zero) -> ToI? {
        sweepConvex(support, by: delta, movedBy: targetDelta, against: target)
    }
}

extension AABB {
    public func sweep(by delta: SIMD2<Float>, against target: CollisionShape,
                      movedBy targetDelta: SIMD2<Float> = .zero) -> ToI? {
        sweepConvex(support, by: delta, movedBy: targetDelta, against: target)
    }
}

extension Capsule {
    public func sweep(by delta: SIMD2<Float>, against target: CollisionShape,
                      movedBy targetDelta: SIMD2<Float> = .zero) -> ToI? {
        sweepConvex(support, by: delta, movedBy: targetDelta, against: target)
    }
}

extension Polygon {
    public func sweep(by delta: SIMD2<Float>, against target: CollisionShape,
                      movedBy targetDelta: SIMD2<Float> = .zero) -> ToI? {
        sweepConvex(support, by: delta, movedBy: targetDelta, against: target)
    }
}
