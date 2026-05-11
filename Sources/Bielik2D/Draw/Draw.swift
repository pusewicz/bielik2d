/// Immediate-mode 2D draw API. Sits on top of `Batcher` and maintains push/pop
/// stacks for the things callers care about (transform, color, layer). Each
/// push is composed against the current peek so callers think in local space.
public final class Draw {
    public let batcher: Batcher
    /// Opaque text engine. SDL3 stores a `TextEngine` here; the web backend
    /// stores a `WebTextRasterizer`. The Text extension casts as needed.
    public let textEngine: Any?
    private var transforms = StateStack(initial: Mat3x2.identity)
    private var colors = StateStack(initial: Color.white)
    private var layers = StateStack(initial: 0)

    public init(batcher: Batcher, textEngine: Any? = nil) {
        self.batcher = batcher
        self.textEngine = textEngine
    }

    // MARK: - Transform

    public func pushTransform(_ m: Mat3x2) {
        transforms.push(transforms.peek * m)
    }

    public func popTransform() {
        _ = transforms.pop()
    }

    public var currentTransform: Mat3x2 { transforms.peek }

    // MARK: - Color tint

    public func pushColor(_ c: Color) {
        colors.push(c)
    }

    public func popColor() {
        _ = colors.pop()
    }

    public var currentColor: Color { colors.peek }

    // MARK: - Layer (forwards to batcher state)

    public func pushLayer(_ layer: Int) {
        layers.push(layer)
        batcher.setLayer(layer)
    }

    public func popLayer() {
        _ = layers.pop()
        batcher.setLayer(layers.peek)
    }

    // MARK: - Primitives

    /// Emits a textured quad in local coordinates. The current transform and
    /// color tint are applied during emit.
    public func quad(rect: Rect, uv: Rect, color: SIMD4<Float>) {
        let t = transforms.peek
        let tint = colors.peek
        let c = SIMD4<Float>(color.x * tint.r,
                             color.y * tint.g,
                             color.z * tint.b,
                             color.w * tint.a)
        let p0 = t.transform(SIMD2(rect.minX, rect.minY))
        let p1 = t.transform(SIMD2(rect.maxX, rect.minY))
        let p2 = t.transform(SIMD2(rect.maxX, rect.maxY))
        let p3 = t.transform(SIMD2(rect.minX, rect.maxY))
        batcher.emitQuadCorners(p0: p0, p1: p1, p2: p2, p3: p3, uv: uv, color: c)
    }
}
