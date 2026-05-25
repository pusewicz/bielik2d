/// Per-frame mouse state. `position` is in window coordinates (origin top-left,
/// +Y down); pair it with `Camera.screenToWorld` for world-space. `delta` and
/// `wheel` accumulate over the frame and reset on the next `beginFrame`.
///
/// As with `Keyboard`, the mutators are internal — the platform's event pump
/// drives them — and game code only queries.
public final class Mouse {
    public private(set) var position: SIMD2<Float> = .zero
    public private(set) var delta: SIMD2<Float> = .zero
    public private(set) var wheel: SIMD2<Float> = .zero
    private var current: Set<MouseButton> = []
    private var previous: Set<MouseButton> = []

    func beginFrame() {
        previous = current
        delta = .zero
        wheel = .zero
    }

    func moved(to point: SIMD2<Float>, relative: SIMD2<Float>) {
        position = point
        delta += relative
    }

    func scrolled(_ amount: SIMD2<Float>) { wheel += amount }
    func press(_ button: MouseButton) { current.insert(button) }
    func release(_ button: MouseButton) { current.remove(button) }

    /// True while the button is held.
    public func down(_ button: MouseButton) -> Bool { current.contains(button) }

    /// True only on the frame the button transitioned up → down.
    public func pressed(_ button: MouseButton) -> Bool {
        current.contains(button) && !previous.contains(button)
    }

    /// True only on the frame the button transitioned down → up.
    public func released(_ button: MouseButton) -> Bool {
        !current.contains(button) && previous.contains(button)
    }
}
