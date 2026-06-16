#if os(WASI)
import JavaScriptKit
import Bielik2D

/// Bridges Bielik2D's `Draw` to a `WebGPURenderBackend`, mirroring the native
/// `Renderer.render`: it owns a `WebPipelineCache` keyed by `(shader, blend)`,
/// uploads the frame's vertices once, then walks `DrawList.commands` — for each
/// command selecting the pipeline for its blend, applying its scissor/viewport,
/// binding the right texture, and issuing a draw for its vertex range.
///
/// Like native, every command runs through the unified `sprite` pipeline (which
/// handles both textured quads and SDF shapes); the cache still supports a
/// `basic` pipeline for future use.
public final class WebRenderer: RenderBackend {
    public let backend: WebGPURenderBackend
    public let cache: WebPipelineCache
    public let vertexBuffer: JSObject
    public let maxVertexCount: Int

    private let sampler: JSObject
    private let uniformBuffer: JSObject
    private let cameraBindGroup: JSObject
    /// Bound for commands whose texture isn't registered — the analogue of the
    /// native renderer substituting its 1×1 white texture for untextured geometry
    /// (SDF shapes sample white and ignore it; the shape branch never reads it).
    private let whiteBindGroup: JSObject

    /// group-1 bind groups keyed by the `DrawCommand`'s texture pointer bit
    /// pattern. The native renderer keys binds by `OpaquePointer`; here the
    /// pointer is a stable token the caller maps to a real WebGPU texture.
    private var textureBindGroups: [UInt: JSObject] = [:]

    /// Bound when a command carries no texture. Defaults to the white pixel;
    /// the minimal demo points it at its sprite PNG so its untextured quad still
    /// samples the image while SDF commands stay unaffected.
    public var defaultTextureBindGroup: JSObject

    public init(backend: WebGPURenderBackend,
                cache: WebPipelineCache,
                vertexBuffer: JSObject,
                maxVertexCount: Int,
                sampler: JSObject,
                uniformBuffer: JSObject,
                whiteTexture: JSObject) {
        self.backend = backend
        self.cache = cache
        self.vertexBuffer = vertexBuffer
        self.maxVertexCount = maxVertexCount
        self.sampler = sampler
        self.uniformBuffer = uniformBuffer

        self.cameraBindGroup = backend.device.createBindGroup!(WebJS.object([
            "layout": .object(cache.cameraBindGroupLayout),
            "entries": .object(WebJS.array([
                WebJS.object([
                    "binding": .number(0),
                    "resource": .object(WebJS.object(["buffer": .object(uniformBuffer)])),
                ]),
            ])),
        ])).object!

        let white = WebRenderer.makeTextureBindGroup(device: backend.device,
                                                     layout: cache.textureBindGroupLayout,
                                                     texture: whiteTexture,
                                                     sampler: sampler)
        self.whiteBindGroup = white
        self.defaultTextureBindGroup = white
    }

    /// Builds a group-1 bind group (texture view + sampler) against the cache's
    /// shared texture layout.
    public static func makeTextureBindGroup(device: JSObject, layout: JSObject,
                                            texture: JSObject, sampler: JSObject) -> JSObject {
        device.createBindGroup!(WebJS.object([
            "layout": .object(layout),
            "entries": .object(WebJS.array([
                WebJS.object([
                    "binding": .number(0),
                    "resource": .object(texture.createView!().object!),
                ]),
                WebJS.object([
                    "binding": .number(1),
                    "resource": .object(sampler),
                ]),
            ])),
        ])).object!
    }

    /// Associates a `DrawCommand`'s texture token with a ready bind group, so the
    /// command loop binds it when it encounters that token in `state.texture`.
    public func registerTexture(_ token: OpaquePointer, bindGroup: JSObject) {
        textureBindGroups[UInt(bitPattern: token)] = bindGroup
    }

    /// Convenience: register a raw WebGPU texture under `token`, building the
    /// group-1 bind group with the renderer's sampler.
    public func registerTexture(_ token: OpaquePointer, texture: JSObject) {
        let bg = WebRenderer.makeTextureBindGroup(device: backend.device,
                                                  layout: cache.textureBindGroupLayout,
                                                  texture: texture, sampler: sampler)
        registerTexture(token, bindGroup: bg)
    }

    public func render(_ list: DrawList, camera: Camera, clear: Color?) {
        // Keep the camera uniform fresh (the demo may pan/zoom between frames).
        var viewProj = camera.viewProjection
        withUnsafeBytes(of: &viewProj) { ptr in
            let bytes = Array(ptr.bindMemory(to: UInt8.self))
            _ = backend.queue.writeBuffer!(uniformBuffer, 0, JSTypedArray<UInt8>(bytes).jsObject)
        }

        let n = list.vertices.count
        if n > 0 && n <= maxVertexCount {
            list.vertices.withUnsafeBytes { ptr in
                let bytes = Array(ptr.bindMemory(to: UInt8.self))
                _ = backend.queue.writeBuffer!(vertexBuffer, 0, JSTypedArray<UInt8>(bytes).jsObject)
            }
        }

        let cc: ClearColor? = clear.map {
            ClearColor(r: Double($0.r), g: Double($0.g), b: Double($0.b), a: Double($0.a))
        }

        let targetW = Float(backend.canvasWidth)
        let targetH = Float(backend.canvasHeight)

        backend.frame(clear: cc) { pass in
            guard n > 0, n <= self.maxVertexCount else { return }
            _ = pass.setBindGroup!(0, self.cameraBindGroup)
            _ = pass.setVertexBuffer!(0, self.vertexBuffer)

            // Mirror native: track last-applied state so redundant pipeline /
            // scissor / viewport switches are skipped within the pass.
            var lastBlend: BlendMode? = nil
            var lastScissorApplied = false
            var lastViewportApplied = false

            for c in list.commands {
                if lastBlend != c.state.blendMode {
                    let key = WebPipelineKey(shader: .sprite, blend: c.state.blendMode)
                    _ = pass.setPipeline!(self.cache.pipeline(for: key))
                    lastBlend = c.state.blendMode
                }

                // Scissor: nil clears to full target. WebGPU has no "disable", so
                // we reset to the whole target when a command drops its clip.
                if let scissor = c.state.scissor {
                    let s = scissorPixelRect(scissor, scale: 1, targetW: Int(targetW), targetH: Int(targetH))
                    _ = pass.setScissorRect!(s.x, s.y, s.w, s.h)
                    lastScissorApplied = true
                } else if lastScissorApplied {
                    _ = pass.setScissorRect!(0, 0, Int(targetW), Int(targetH))
                    lastScissorApplied = false
                }

                if let viewport = c.state.viewport {
                    let v = viewportPixelRect(viewport, scale: 1, targetW: Int(targetW), targetH: Int(targetH))
                    _ = pass.setViewport!(Double(v.x), Double(v.y), Double(v.w), Double(v.h), 0.0, 1.0)
                    lastViewportApplied = true
                } else if lastViewportApplied {
                    _ = pass.setViewport!(0.0, 0.0, Double(targetW), Double(targetH), 0.0, 1.0)
                    lastViewportApplied = false
                }

                // Texture: registered token → its bind group; otherwise the
                // default (white pixel, or the demo's sprite texture).
                let group1: JSObject
                if let token = c.state.texture, let bg = self.textureBindGroups[UInt(bitPattern: token)] {
                    group1 = bg
                } else {
                    group1 = self.defaultTextureBindGroup
                }
                _ = pass.setBindGroup!(1, group1)

                _ = pass.draw!(c.vertexCount, 1, c.vertexStart, 0)
            }
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
