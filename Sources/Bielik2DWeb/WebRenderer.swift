#if os(WASI)
import JavaScriptKit
import Bielik2D

/// Bridges Bielik2D's `Draw` to a `WebGPURenderBackend`. Uploads the queued
/// geometry to its vertex buffer and issues the sprite/SDF batch plus the
/// static label. Composes the low-level `WebGPURenderBackend` (device, context,
/// queue, frame loop) rather than re-implementing WebGPU init.
///
/// This is the single-pipeline renderer the minimal web demo drives. Later
/// phases will extend it: a pipeline cache keyed by (shader, blend mode), and
/// factories such as `makeTextEngine` / `makeCanvas` / sprite helpers so the
/// full 11-scene demo can build on the same type. Those are intentionally NOT
/// implemented here — this task only promotes the existing renderer verbatim.
public final class WebRenderer: RenderBackend {
    public let backend: WebGPURenderBackend
    public let pipeline: JSObject
    public let vertexBuffer: JSObject
    public let maxVertexCount: Int
    public let bindGroup0: JSObject
    public let bindGroup1: JSObject
    public let labelBindGroup: JSObject
    public let labelBuffer: JSObject
    public let labelVertexCount: Int

    public init(backend: WebGPURenderBackend, pipeline: JSObject, vertexBuffer: JSObject, maxVertexCount: Int,
                bindGroup0: JSObject, bindGroup1: JSObject, labelBindGroup: JSObject, labelBuffer: JSObject,
                labelVertexCount: Int) {
        self.backend = backend
        self.pipeline = pipeline
        self.vertexBuffer = vertexBuffer
        self.maxVertexCount = maxVertexCount
        self.bindGroup0 = bindGroup0
        self.bindGroup1 = bindGroup1
        self.labelBindGroup = labelBindGroup
        self.labelBuffer = labelBuffer
        self.labelVertexCount = labelVertexCount
    }

    public func render(_ list: DrawList, camera: Camera, clear: Color?) {
        let n = list.vertices.count
        if n > 0 && n <= maxVertexCount {
            list.vertices.withUnsafeBytes { ptr in
                let bytes = Array(ptr.bindMemory(to: UInt8.self))
                _ = backend.queue.writeBuffer!(vertexBuffer, 0, JSTypedArray<UInt8>(bytes).jsObject)
            }
        }
        let cc = ClearColor(r: Double(clear?.r ?? 0), g: Double(clear?.g ?? 0),
                            b: Double(clear?.b ?? 0), a: Double(clear?.a ?? 1))
        backend.frame(clear: cc) { pass in
            _ = pass.setPipeline!(pipeline)
            _ = pass.setBindGroup!(0, bindGroup0)
            // Sprite + SDF batch.
            _ = pass.setBindGroup!(1, bindGroup1)
            _ = pass.setVertexBuffer!(0, vertexBuffer)
            if n > 0 { _ = pass.draw!(n) }
            // Label.
            _ = pass.setBindGroup!(1, labelBindGroup)
            _ = pass.setVertexBuffer!(0, labelBuffer)
            _ = pass.draw!(labelVertexCount)
        }
    }
}

/// Maps a Bielik2D `VertexFormat` to its WebGPU vertex-format string.
public func wgpuVertexFormat(_ f: VertexFormat) -> String {
    switch f {
    case .float: "float32"
    case .float2: "float32x2"
    case .float3: "float32x3"
    case .float4: "float32x4"
    case .ubyte4Norm: "unorm8x4"
    }
}

// WebGPU GPUBufferUsage / GPUTextureUsage flag constants. The browser exposes
// these as `GPUBufferUsage.VERTEX` etc., but threading them through JSValue
// for every descriptor is noisy — keep them as Swift constants here.
public enum GPUBufferUsage {
    public static let mapRead: Int = 1
    public static let mapWrite: Int = 2
    public static let copySrc: Int = 4
    public static let copyDst: Int = 8
    public static let index: Int = 16
    public static let vertex: Int = 32
    public static let uniform: Int = 64
    public static let storage: Int = 128
    public static let indirect: Int = 256
}

public enum GPUTextureUsage {
    public static let copySrc: Int = 1
    public static let copyDst: Int = 2
    public static let textureBinding: Int = 4
    public static let storageBinding: Int = 8
    public static let renderAttachment: Int = 16
}
#endif
