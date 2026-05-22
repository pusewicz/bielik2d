public enum BlendMode: Hashable, Sendable {
    case none
    case alpha
    case additive
    case premultipliedAlpha
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

