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

extension Circle {
    /// Swept time-of-impact: sweep `self` by `delta` against `target` (optionally moving by
    /// `targetDelta`). `ToI.t` is the fraction of `delta` at first contact. `nil` = clean miss.
    public func sweep(by delta: SIMD2<Float>, against target: Circle,
                      movedBy targetDelta: SIMD2<Float> = .zero) -> ToI? {
        sweptTOIConvex(mover: support, target: target.support, relDelta: delta - targetDelta)
    }
}
