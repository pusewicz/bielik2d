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

    /// Backing storage for `makeCanvas` tokens — each canvas's process-unique
    /// `OpaquePointer` is the address of one of these heap cells, kept alive for
    /// the renderer's lifetime so the registered bind group stays valid.
    private var canvasTokenStorage: [UnsafeMutableRawPointer] = []

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
        uploadFrame(list: list, camera: camera)
        let cc = clearColor(clear)
        let targetW = backend.canvasWidth
        let targetH = backend.canvasHeight
        // Swapchain target: grab the current drawable's view and encode the loop.
        guard let texture = backend.context.getCurrentTexture!().object,
              let view = texture.createView!().object else { return }
        backend.renderPass(into: view, clear: cc) { pass in
            self.encodeCommands(list, into: pass, targetW: targetW, targetH: targetH)
        }
    }

    /// Renders `draw`'s queued geometry into an offscreen `WebCanvas`, then resets
    /// the queue (mirrors the native `Renderer.render(_:to:)`). The canvas texture
    /// can then be sampled back via `Draw.canvas(_:at:)`. `camera` defaults to an
    /// orthographic projection sized to the canvas.
    public func render(_ draw: Draw, to canvas: WebCanvas, clear: Color? = nil, camera: Camera? = nil) {
        let cam = camera ?? Camera(viewportSize: SIMD2(Float(canvas.width), Float(canvas.height)))
        let list = draw.drawList()
        uploadFrame(list: list, camera: cam)
        let cc = clearColor(clear)
        guard let view = canvas.texture.createView!().object else { return }
        backend.renderPass(into: view, clear: cc) { pass in
            self.encodeCommands(list, into: pass, targetW: canvas.width, targetH: canvas.height)
        }
        draw.clearQueue()
    }

    /// Allocates an offscreen render target and registers it under a stable token
    /// so `Draw.canvas(_:at:)` can bind it as a sampled texture. The colour format
    /// matches the swapchain so the shared pipelines render into it unchanged.
    public func makeCanvas(width: Int, height: Int) -> WebCanvas {
        let texture = backend.makeRenderTarget(width: width, height: height)
        let cell = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
        canvasTokenStorage.append(cell)
        let token = OpaquePointer(cell)
        registerTexture(token, texture: texture)
        return WebCanvas(texture: texture, token: token, width: width, height: height)
    }

    // MARK: - Shared frame plumbing

    /// Uploads the camera uniform and the frame's vertices once per render.
    private func uploadFrame(list: DrawList, camera: Camera) {
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
    }

    private func clearColor(_ clear: Color?) -> ClearColor? {
        clear.map { ClearColor(r: Double($0.r), g: Double($0.g), b: Double($0.b), a: Double($0.a)) }
    }

    /// Walks the draw list, switching pipeline / scissor / viewport / texture and
    /// issuing one draw per command — the single command loop shared by the
    /// swapchain and offscreen-canvas paths.
    private func encodeCommands(_ list: DrawList, into pass: JSObject, targetW: Int, targetH: Int) {
        let n = list.vertices.count
        guard n > 0, n <= maxVertexCount else { return }
        _ = pass.setBindGroup!(0, cameraBindGroup)
        _ = pass.setVertexBuffer!(0, vertexBuffer)

        // Mirror native: track last-applied state so redundant pipeline /
        // scissor / viewport switches are skipped within the pass.
        var lastBlend: BlendMode? = nil
        var lastScissorApplied = false
        var lastViewportApplied = false

        for c in list.commands {
            if lastBlend != c.state.blendMode {
                let key = WebPipelineKey(shader: .sprite, blend: c.state.blendMode)
                _ = pass.setPipeline!(cache.pipeline(for: key))
                lastBlend = c.state.blendMode
            }

            // Scissor: nil clears to full target. WebGPU has no "disable", so
            // we reset to the whole target when a command drops its clip.
            if let scissor = c.state.scissor {
                let s = scissorPixelRect(scissor, scale: 1, targetW: targetW, targetH: targetH)
                _ = pass.setScissorRect!(s.x, s.y, s.w, s.h)
                lastScissorApplied = true
            } else if lastScissorApplied {
                _ = pass.setScissorRect!(0, 0, targetW, targetH)
                lastScissorApplied = false
            }

            if let viewport = c.state.viewport {
                let v = viewportPixelRect(viewport, scale: 1, targetW: targetW, targetH: targetH)
                _ = pass.setViewport!(Double(v.x), Double(v.y), Double(v.w), Double(v.h), 0.0, 1.0)
                lastViewportApplied = true
            } else if lastViewportApplied {
                _ = pass.setViewport!(0.0, 0.0, Double(targetW), Double(targetH), 0.0, 1.0)
                lastViewportApplied = false
            }

            // Texture: registered token → its bind group; otherwise the
            // default (white pixel, or the demo's sprite texture).
            let group1: JSObject
            if let token = c.state.texture, let bg = textureBindGroups[UInt(bitPattern: token)] {
                group1 = bg
            } else {
                group1 = defaultTextureBindGroup
            }
            _ = pass.setBindGroup!(1, group1)

            _ = pass.draw!(c.vertexCount, 1, c.vertexStart, 0)
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
