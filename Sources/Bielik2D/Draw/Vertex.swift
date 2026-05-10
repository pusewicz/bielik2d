import Foundation

/// The unified per-vertex layout that drives both textured sprites and SDF shapes.
/// Mirrors Cute Framework's `CF_Vertex`. Most fields are unused by v0 sprite drawing
/// but the layout is fixed up front so future SDF / shape work doesn't require a rewrite.
public struct Vertex {
    public var pos: SIMD2<Float>
    public var uv: SIMD2<Float>
    public var color: SIMD4<Float>         // RGBA tint (could be packed later)
    public var radius: Float
    public var stroke: Float
    public var aa: Float
    public var type: Float                 // 0 = sprite, others reserved for SDF shapes
    public var alpha: Float
    public var fill: Float                 // 1 = filled, 0 = stroked
    public var posH: SIMD2<Float>          // homogeneous position (reserved)
    public var attributes: SIMD4<Float>    // user-shader payload (reserved)
    public var uvBounds: SIMD4<Float>      // uv clip rect (reserved)

    public init(pos: SIMD2<Float> = .zero,
                uv: SIMD2<Float> = .zero,
                color: SIMD4<Float> = .one,
                radius: Float = 0, stroke: Float = 0, aa: Float = 0, type: Float = 0,
                alpha: Float = 1, fill: Float = 1,
                posH: SIMD2<Float> = .zero,
                attributes: SIMD4<Float> = .zero,
                uvBounds: SIMD4<Float> = .zero) {
        self.pos = pos
        self.uv = uv
        self.color = color
        self.radius = radius
        self.stroke = stroke
        self.aa = aa
        self.type = type
        self.alpha = alpha
        self.fill = fill
        self.posH = posH
        self.attributes = attributes
        self.uvBounds = uvBounds
    }

    public struct NamedAttribute: @unchecked Sendable {
        public let name: String
        public let location: UInt32
        public let format: VertexFormat
        public let keyPath: PartialKeyPath<Vertex>
    }

    /// All attributes, in declaration order. Used by tests and by `bufferLayout`.
    public static let attributeKeyPaths: [NamedAttribute] = [
        NamedAttribute(name: "pos", location: 0, format: .float2, keyPath: \.pos),
        NamedAttribute(name: "uv", location: 1, format: .float2, keyPath: \.uv),
        NamedAttribute(name: "color", location: 2, format: .float4, keyPath: \.color),
        NamedAttribute(name: "radius", location: 3, format: .float, keyPath: \.radius),
        NamedAttribute(name: "stroke", location: 4, format: .float, keyPath: \.stroke),
        NamedAttribute(name: "aa", location: 5, format: .float, keyPath: \.aa),
        NamedAttribute(name: "type", location: 6, format: .float, keyPath: \.type),
        NamedAttribute(name: "alpha", location: 7, format: .float, keyPath: \.alpha),
        NamedAttribute(name: "fill", location: 8, format: .float, keyPath: \.fill),
        NamedAttribute(name: "posH", location: 9, format: .float2, keyPath: \.posH),
        NamedAttribute(name: "attributes", location: 10, format: .float4, keyPath: \.attributes),
        NamedAttribute(name: "uvBounds", location: 11, format: .float4, keyPath: \.uvBounds),
    ]

    public static let bufferLayout: VertexBufferDescriptor = {
        let attrs = attributeKeyPaths.map { named in
            VertexAttribute(
                name: named.name,
                location: named.location,
                format: named.format,
                offset: UInt32(MemoryLayout<Vertex>.offset(of: named.keyPath)!)
            )
        }
        return VertexBufferDescriptor(stride: MemoryLayout<Vertex>.stride, attributes: attrs)
    }()
}
