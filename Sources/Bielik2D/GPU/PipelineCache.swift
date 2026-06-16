public enum BlendMode: Hashable, Sendable {
    case none
    case alpha
    case additive
    case premultipliedAlpha
}

/// One WebGPU `GPUBlendComponent`: source/destination factors plus the blend op.
/// Pure data so the BlendMode → WebGPU mapping is testable without a browser.
public struct WebGPUBlendComponent: Equatable, Sendable {
    public var srcFactor: String
    public var dstFactor: String
    public var operation: String

    public init(srcFactor: String, dstFactor: String, operation: String = "add") {
        self.srcFactor = srcFactor
        self.dstFactor = dstFactor
        self.operation = operation
    }
}

/// A WebGPU `GPUBlendState` (separate color + alpha components), or `nil` when
/// blending is disabled. `nil` maps to omitting `blend` from the color target,
/// which is WebGPU's no-blend (opaque write) behaviour — the analogue of
/// SDL's `enable_blend = false`.
public struct WebGPUBlendState: Equatable, Sendable {
    public var color: WebGPUBlendComponent
    public var alpha: WebGPUBlendComponent

    public init(color: WebGPUBlendComponent, alpha: WebGPUBlendComponent) {
        self.color = color
        self.alpha = alpha
    }
}

extension BlendMode {
    /// The WebGPU blend factors for this mode, mirroring the native SDL mapping in
    /// `GraphicsPipeline.swift` exactly. `.none` returns `nil` (no blend state).
    public var webGPUBlendState: WebGPUBlendState? {
        switch self {
        case .none:
            return nil
        case .alpha:
            return WebGPUBlendState(
                color: WebGPUBlendComponent(srcFactor: "src-alpha", dstFactor: "one-minus-src-alpha"),
                alpha: WebGPUBlendComponent(srcFactor: "one", dstFactor: "one-minus-src-alpha"))
        case .premultipliedAlpha:
            return WebGPUBlendState(
                color: WebGPUBlendComponent(srcFactor: "one", dstFactor: "one-minus-src-alpha"),
                alpha: WebGPUBlendComponent(srcFactor: "one", dstFactor: "one-minus-src-alpha"))
        case .additive:
            return WebGPUBlendState(
                color: WebGPUBlendComponent(srcFactor: "one", dstFactor: "one"),
                alpha: WebGPUBlendComponent(srcFactor: "one", dstFactor: "one"))
        }
    }
}

struct PipelineKey: Hashable, Sendable {
    public var shaderID: Int
    public var colorFormat: TextureFormat
    public var blendMode: BlendMode

    public init(shaderID: Int, colorFormat: TextureFormat, blendMode: BlendMode) {
        self.shaderID = shaderID
        self.colorFormat = colorFormat
        self.blendMode = blendMode
    }
}

final class PipelineCache<Value> {
    private var entries: [PipelineKey: Value] = [:]
    private let build: (PipelineKey) -> Value

    public init(_ build: @escaping (PipelineKey) -> Value) {
        self.build = build
    }

    public func get(_ key: PipelineKey) -> Value {
        if let v = entries[key] { return v }
        let v = build(key)
        entries[key] = v
        return v
    }
}

