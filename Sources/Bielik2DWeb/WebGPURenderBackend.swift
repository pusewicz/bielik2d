#if os(WASI)
import JavaScriptKit
import JavaScriptEventLoop

public enum WebGPUError: Error, CustomStringConvertible {
    case unsupported
    case adapterRequestFailed
    case deviceRequestFailed
    case canvasContextMissing

    public var description: String {
        switch self {
        case .unsupported: "this browser does not expose `navigator.gpu`"
        case .adapterRequestFailed: "navigator.gpu.requestAdapter() rejected or returned null"
        case .deviceRequestFailed: "GPUAdapter.requestDevice() rejected"
        case .canvasContextMissing: "canvas.getContext('webgpu') returned null"
        }
    }
}

public struct ClearColor: Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double
    public init(r: Double, g: Double, b: Double, a: Double = 1.0) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }
}

/// Thin wrapper around `navigator.gpu`. Phase 16 only needs the device, the
/// canvas swap context, and a clear-only render pass. Pipelines and buffers
/// land in Phase 17.
public final class WebGPURenderBackend {
    public let device: JSObject
    public let context: JSObject
    public let queue: JSObject
    public let preferredFormat: String
    /// Drawable size in device pixels — the scissor/viewport command loop clamps
    /// against these (the swapchain texture matches the configured canvas).
    public let canvasWidth: Int
    public let canvasHeight: Int

    private init(device: JSObject, context: JSObject, queue: JSObject, preferredFormat: String,
                 canvasWidth: Int, canvasHeight: Int) {
        self.device = device
        self.context = context
        self.queue = queue
        self.preferredFormat = preferredFormat
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
    }

    public static func create(on platform: WebPlatform) async throws -> WebGPURenderBackend {
        guard let navigator = JSObject.global.navigator.object,
              let gpu = navigator.gpu.object else {
            throw WebGPUError.unsupported
        }

        let adapterValue: JSValue
        do {
            adapterValue = try await awaitJSPromise(gpu.requestAdapter!())
        } catch {
            throw WebGPUError.adapterRequestFailed
        }
        guard !adapterValue.isNull, let adapter = adapterValue.object else {
            throw WebGPUError.adapterRequestFailed
        }

        let deviceValue: JSValue
        do {
            deviceValue = try await awaitJSPromise(adapter.requestDevice!())
        } catch {
            throw WebGPUError.deviceRequestFailed
        }
        guard let device = deviceValue.object else {
            throw WebGPUError.deviceRequestFailed
        }

        guard let context = platform.canvas.getContext!("webgpu").object else {
            throw WebGPUError.canvasContextMissing
        }

        let preferredFormat = gpu.getPreferredCanvasFormat!().string ?? "bgra8unorm"

        let configure = newObject([
            "device": .object(device),
            "format": .string(preferredFormat),
            "alphaMode": .string("opaque"),
        ])
        _ = context.configure!(configure)

        guard let queue = device.queue.object else {
            throw WebGPUError.deviceRequestFailed
        }
        return WebGPURenderBackend(device: device, context: context, queue: queue,
                                   preferredFormat: preferredFormat,
                                   canvasWidth: platform.size.x, canvasHeight: platform.size.y)
    }

    /// A 1×1 opaque-white RGBA8 texture, the WebGPU analogue of the native
    /// renderer's white pixel. Bound for untextured / SDF commands so their
    /// shader samples 1.0 (and the shape branch ignores the texture entirely).
    public func makeWhitePixelTexture() -> JSObject {
        let texture = device.createTexture!(WebJS.object([
            "size": .object(WebJS.object([
                "width": .number(1), "height": .number(1), "depthOrArrayLayers": .number(1),
            ])),
            "format": .string("rgba8unorm"),
            "usage": .number(Double(GPUTextureUsage.textureBinding | GPUTextureUsage.copyDst)),
        ])).object!
        let px = JSTypedArray<UInt8>([0xFF, 0xFF, 0xFF, 0xFF])
        _ = queue.writeTexture!(
            WebJS.object(["texture": .object(texture)]),
            px.jsObject,
            WebJS.object(["bytesPerRow": .number(4), "rowsPerImage": .number(1)]),
            WebJS.object(["width": .number(1), "height": .number(1)])
        )
        return texture
    }

    /// Runs a single frame: begins a render pass with the given clear colour,
    /// calls `render` so the caller can bind pipelines, buffers, bind groups
    /// and issue draw calls, then submits the encoded command buffer.
    public func frame(clear: ClearColor?, render: (JSObject) -> Void = { _ in }) {
        guard let texture = context.getCurrentTexture!().object,
              let view = texture.createView!().object else { return }

        // nil clear -> load the existing contents (so a second pass composites
        // over the first this frame), matching the native `clear: nil` path.
        var attachmentPairs: [String: JSValue] = [
            "view": .object(view),
            "loadOp": .string(clear == nil ? "load" : "clear"),
            "storeOp": .string("store"),
        ]
        if let clear {
            attachmentPairs["clearValue"] = .object(newObject([
                "r": .number(clear.r),
                "g": .number(clear.g),
                "b": .number(clear.b),
                "a": .number(clear.a),
            ]))
        }
        let colorAttachment = newObject(attachmentPairs)
        let attachments = JSObject.global.Array.function!.new(colorAttachment)
        let descriptor = newObject([
            "colorAttachments": .object(attachments),
        ])

        guard let encoder = device.createCommandEncoder!().object,
              let pass = encoder.beginRenderPass!(descriptor).object else { return }
        render(pass)
        _ = pass.end!()
        guard let cmd = encoder.finish!().object else { return }
        let submitList = JSObject.global.Array.function!.new(cmd)
        _ = queue.submit!(submitList)
    }

    /// Runs a single render pass into an arbitrary `targetView` (rather than the
    /// swapchain). Used by render-to-canvas: the offscreen texture's view is the
    /// colour attachment. `nil` clear loads existing contents (composite); a set
    /// clear wipes first. Encoding/submission mirrors `frame(clear:render:)`.
    public func renderPass(into targetView: JSObject, clear: ClearColor?,
                           render: (JSObject) -> Void = { _ in }) {
        var attachmentPairs: [String: JSValue] = [
            "view": .object(targetView),
            "loadOp": .string(clear == nil ? "load" : "clear"),
            "storeOp": .string("store"),
        ]
        if let clear {
            attachmentPairs["clearValue"] = .object(newObject([
                "r": .number(clear.r),
                "g": .number(clear.g),
                "b": .number(clear.b),
                "a": .number(clear.a),
            ]))
        }
        let colorAttachment = newObject(attachmentPairs)
        let attachments = JSObject.global.Array.function!.new(colorAttachment)
        let descriptor = newObject(["colorAttachments": .object(attachments)])

        guard let encoder = device.createCommandEncoder!().object,
              let pass = encoder.beginRenderPass!(descriptor).object else { return }
        render(pass)
        _ = pass.end!()
        guard let cmd = encoder.finish!().object else { return }
        let submitList = JSObject.global.Array.function!.new(cmd)
        _ = queue.submit!(submitList)
    }

    /// Creates an offscreen colour-target texture that can also be sampled.
    /// `format` defaults to the preferred canvas format so a render-to-canvas
    /// target matches the swapchain's pipeline colour format (the pipeline cache
    /// is built for `preferredFormat`).
    public func makeRenderTarget(width: Int, height: Int, format: String? = nil) -> JSObject {
        device.createTexture!(WebJS.object([
            "size": .object(WebJS.object([
                "width": .number(Double(width)),
                "height": .number(Double(height)),
                "depthOrArrayLayers": .number(1),
            ])),
            "format": .string(format ?? preferredFormat),
            "usage": .number(Double(GPUTextureUsage.textureBinding | GPUTextureUsage.renderAttachment | GPUTextureUsage.copySrc | GPUTextureUsage.copyDst)),
        ])).object!
    }

    /// Wraps an already-decoded `ImageBitmap` in a fresh RGBA8 GPU texture.
    /// Uses `queue.copyExternalImageToTexture` for a zero-CPU upload.
    /// Returns `(texture, width, height)`.
    public func makeTexture(from bitmap: JSObject) -> (JSObject, Int, Int) {
        let width = Int(bitmap["width"].number ?? 0)
        let height = Int(bitmap["height"].number ?? 0)
        let texture = device.createTexture!(WebJS.object([
            "size": .object(WebJS.object([
                "width": .number(Double(width)),
                "height": .number(Double(height)),
                "depthOrArrayLayers": .number(1),
            ])),
            "format": .string("rgba8unorm"),
            // RENDER_ATTACHMENT is required by copyExternalImageToTexture.
            "usage": .number(Double(0x04 | 0x02 | 0x10)),
        ])).object!
        _ = queue.copyExternalImageToTexture!(
            WebJS.object(["source": .object(bitmap)]),
            WebJS.object(["texture": .object(texture)]),
            WebJS.object([
                "width": .number(Double(width)),
                "height": .number(Double(height)),
            ])
        )
        return (texture, width, height)
    }

    /// Fetches a WGSL source by relative URL (typically `shaders/<name>.wgsl`)
    /// and turns it into a `GPUShaderModule`.
    public func loadShaderModule(url: String) async throws -> JSObject {
        let resp = try await awaitJSPromise(JSObject.global.fetch.function!(url))
        guard let respObj = resp.object else { throw WebGPUError.canvasContextMissing }
        let textPromise = respObj.text!()
        let textValue = try await awaitJSPromise(textPromise)
        guard let source = textValue.string else { throw WebGPUError.canvasContextMissing }
        guard let module = device.createShaderModule!(newObject(["code": .string(source)])).object else {
            throw WebGPUError.canvasContextMissing
        }
        return module
    }
}

public enum WebJS {
    @inline(__always)
    public static func object(_ pairs: [String: JSValue]) -> JSObject {
        let obj = JSObject.global.Object.function!.new()
        for (k, v) in pairs { obj[k] = v }
        return obj
    }

    public static func array(_ values: [JSObject]) -> JSObject {
        let arr = JSObject.global.Array.function!.new()
        for v in values { _ = arr.push!(v) }
        return arr
    }

    public static func array(_ values: [JSValue]) -> JSObject {
        let arr = JSObject.global.Array.function!.new()
        for v in values { _ = arr.push!(v) }
        return arr
    }

    @inline(__always)
    public static func await_(_ value: JSValue) async throws -> JSValue {
        guard let obj = value.object, let promise = JSPromise(obj) else { return value }
        return try await promise.value
    }
}

@inline(__always)
func newObject(_ pairs: [String: JSValue]) -> JSObject { WebJS.object(pairs) }

@inline(__always)
func awaitJSPromise(_ value: JSValue) async throws -> JSValue { try await WebJS.await_(value) }
#endif
