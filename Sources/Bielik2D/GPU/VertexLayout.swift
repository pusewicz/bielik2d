public enum VertexFormat: Sendable {
    case float, float2, float3, float4
    case ubyte4Norm
}

public struct VertexAttribute: Sendable {
    public var name: String
    public var location: UInt32
    public var format: VertexFormat
    public var offset: UInt32

    public init(name: String = "", location: UInt32, format: VertexFormat, offset: UInt32) {
        self.name = name
        self.location = location
        self.format = format
        self.offset = offset
    }
}

public struct VertexBufferDescriptor: Sendable {
    public var stride: Int
    public var attributes: [VertexAttribute]

    public init(stride: Int, attributes: [VertexAttribute]) {
        self.stride = stride
        self.attributes = attributes
    }
}
