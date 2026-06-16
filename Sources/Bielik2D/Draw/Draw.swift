/// Immediate-mode 2D draw API. Sits on top of `Batcher` and maintains push/pop
/// stacks for the things callers care about (transform, color, layer). Each
/// push is composed against the current peek so callers think in local space.
public final class Draw {
    let batcher: Batcher
    /// Sprites drawn this frame, captured for deferred atlas resolution at flush
    /// (the native `Renderer` packs and resolves them). Untextured geometry still
    /// goes straight into the `batcher`.
    var spriteInstances: [SpriteInstance] = []
    /// Opaque text engine. SDL3 stores a `TextEngine` here; the web backend
    /// stores a `WebTextRasterizer`. The Text extension casts as needed.
    public let textEngine: Any?
    private var transforms = StateStack(initial: Mat3x2.identity)
    private var colors = StateStack(initial: Color.white)
    private var layers = StateStack(initial: 0)
    private var scaleModes = StateStack(initial: ScaleMode.default)
    private var shapeAAs = StateStack(initial: 1.5 / Draw.ambientPixelDensity)
    private var scissors = StateStack(initial: Rect?.none)
    private var viewports = StateStack(initial: Rect?.none)
    private var blends = StateStack(initial: BlendMode.alpha)

    /// The Draw that `sprite.draw(at:)` queues into — set to the most recently created
    /// Draw. `nonisolated(unsafe)` for the same single-threaded reason as
    /// `Renderer.current`; pass an explicit `Draw` via `draw.sprite(_:at:)` otherwise.
    public static nonisolated(unsafe) var current: Draw?

    /// Current display pixel density (pixels per logical point). `App` keeps this in
    /// sync with the window's display so that SDF primitives whose `aa` defaults to
    /// `1.5 / ambientPixelDensity` always produce a ~1.5-screen-pixel AA band.
    public static nonisolated(unsafe) var ambientPixelDensity: Float = 1.0

    public init(textEngine: Any? = nil) {
        self.batcher = Batcher()
        self.textEngine = textEngine
        Draw.current = self
    }

    /// Internal seam for tests that inspect the queued geometry directly.
    init(batcher: Batcher, textEngine: Any? = nil) {
        self.batcher = batcher
        self.textEngine = textEngine
        Draw.current = self
    }

    /// Reserve vertex storage up front so per-frame queueing never reallocates.
    public func reserveVertexCapacity(_ n: Int) {
        batcher.reserveVertexCapacity(n)
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

    public var currentLayer: Int { layers.peek }

    // MARK: - Texture binding (forwards to batcher state)

    /// Binds `token` as the texture for subsequent batched geometry, flushing the
    /// current run if it differs. `nil` reverts to untextured. The token is an
    /// opaque key a render backend maps to a real texture (native: the SDL
    /// texture handle; web: a renderer-registered glyph/canvas texture). Mirrors
    /// the same-module `batcher.setTexture` call the native `Draw.canvas` uses, so
    /// out-of-module code (the web text engine, the web canvas) can bind too.
    public func setBatcherTexture(_ token: OpaquePointer?) {
        batcher.setTexture(token)
    }

    // MARK: - Queue lifecycle

    /// A read-only snapshot of this frame's queued geometry, layer-sorted. Lets a
    /// render backend in another module consume the queue without touching the
    /// internal `Batcher` (the native `Renderer`, same module, reads it directly).
    public func drawList() -> DrawList {
        DrawList(vertices: batcher.vertices,
                 commands: batcher.commandsSortedByLayer,
                 spriteInstances: spriteInstances)
    }

    /// Clears everything queued this frame (immediate geometry + deferred sprites).
    /// A flush calls this after handing the queue to a backend.
    public func clearQueue() {
        batcher.reset()
        spriteInstances.removeAll(keepingCapacity: true)
    }

    // MARK: - Scale mode (ambient filter for textured draws)

    /// Sets the ambient scale mode for subsequent textured draws. A sprite's own
    /// `scaleMode`, or a per-call `scaleMode:` argument, still takes precedence.
    public func pushScaleMode(_ mode: ScaleMode) {
        scaleModes.push(mode)
    }

    public func popScaleMode() {
        _ = scaleModes.pop()
    }

    public var currentScaleMode: ScaleMode { scaleModes.peek }

    // MARK: - Shape anti-aliasing (ambient default for SDF primitives)

    /// Sets the ambient AA band (world units) that SDF primitives use when their
    /// `aa:` argument is omitted. Defaults to `1.5 / ambientPixelDensity`.
    public func pushShapeAA(_ aa: Float) {
        shapeAAs.push(aa)
    }

    public func popShapeAA() {
        _ = shapeAAs.pop()
    }

    public var currentShapeAA: Float { shapeAAs.peek }

    // MARK: - Scissor / viewport / blend (forward to batcher state)

    /// Clip subsequent draws to `rect` (logical points, target-space). Replace semantics.
    public func pushScissor(_ rect: Rect) { scissors.push(rect); batcher.setScissor(rect) }
    public func popScissor() { _ = scissors.pop(); batcher.setScissor(scissors.peek) }
    public var currentScissor: Rect? { scissors.peek }

    /// Render subsequent draws into `rect` (logical points, target-space) of the target.
    public func pushViewport(_ rect: Rect) { viewports.push(rect); batcher.setViewport(rect) }
    public func popViewport() { _ = viewports.pop(); batcher.setViewport(viewports.peek) }
    public var currentViewport: Rect? { viewports.peek }

    /// Blend mode for subsequent draws.
    public func pushBlendState(_ mode: BlendMode) { blends.push(mode); batcher.setBlend(mode) }
    public func popBlendState() { _ = blends.pop(); batcher.setBlend(blends.peek) }
    public var currentBlendState: BlendMode { blends.peek }

    // MARK: - Scoped state

    /// Runs `body` with the given state pushed, popping it again on exit (even if
    /// `body` throws). Any combination of axes can be set in one call; `nil` axes
    /// are left untouched. Auto-popping makes push/pop imbalance impossible.
    ///
    ///     draw.with(scaleMode: .pixelArt) { draw.sprite(player) }
    ///     draw.with(color: .red, scaleMode: .pixelArt) { ... }
    @discardableResult
    public func with<R>(transform: Mat3x2? = nil,
                        color: Color? = nil,
                        layer: Int? = nil,
                        scaleMode: ScaleMode? = nil,
                        shapeAA: Float? = nil,
                        scissor: Rect? = nil,
                        viewport: Rect? = nil,
                        blendState: BlendMode? = nil,
                        _ body: () throws -> R) rethrows -> R {
        if let transform { pushTransform(transform) }
        if let color { pushColor(color) }
        if let layer { pushLayer(layer) }
        if let scaleMode { pushScaleMode(scaleMode) }
        if let shapeAA { pushShapeAA(shapeAA) }
        if let scissor { pushScissor(scissor) }
        if let viewport { pushViewport(viewport) }
        if let blendState { pushBlendState(blendState) }
        defer {
            if blendState != nil { popBlendState() }
            if viewport != nil { popViewport() }
            if scissor != nil { popScissor() }
            if shapeAA != nil { popShapeAA() }
            if scaleMode != nil { popScaleMode() }
            if layer != nil { popLayer() }
            if color != nil { popColor() }
            if transform != nil { popTransform() }
        }
        return try body()
    }

    // MARK: - Primitives

    /// Emits a textured quad in local coordinates. The current transform and
    /// color tint are applied during emit. `scaleMode` (nil = inherit the pushed
    /// ambient mode) + `textureSize` (source texture dimensions in texels) ride
    /// along in the vertex so the fragment shader can do pixel-art / nearest
    /// sampling. Untextured quads leave `textureSize` zero, which the shader
    /// treats as plain sampling regardless of mode.
    public func quad(rect: Rect, uv: Rect, color: SIMD4<Float>,
                     scaleMode: ScaleMode? = nil, textureSize: SIMD2<Float> = .zero) {
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
        let mode = scaleMode ?? scaleModes.peek
        let scaleData = SIMD4<Float>(textureSize.x, textureSize.y, mode.shaderValue, 0)
        batcher.emitQuadCorners(p0: p0, p1: p1, p2: p2, p3: p3, uv: uv, color: c, scaleData: scaleData)
    }
}
