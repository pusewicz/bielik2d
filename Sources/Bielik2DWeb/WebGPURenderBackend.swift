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

    private init(device: JSObject, context: JSObject, queue: JSObject, preferredFormat: String) {
        self.device = device
        self.context = context
        self.queue = queue
        self.preferredFormat = preferredFormat
    }

    public static func create(on platform: WebPlatform) async throws -> WebGPURenderBackend {
        let gpu = JSObject.global.navigator.gpu
        if gpu.isUndefined || gpu.isNull {
            throw WebGPUError.unsupported
        }

        let adapterValue: JSValue
        do {
            adapterValue = try await awaitJSPromise(gpu.requestAdapter!())
        } catch {
            throw WebGPUError.adapterRequestFailed
        }
        guard let adapter = adapterValue.object, !adapter.isNull else {
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
        return WebGPURenderBackend(device: device, context: context, queue: queue, preferredFormat: preferredFormat)
    }

    /// Runs a single clear-only frame. Phase 17 expands `body` with bind +
    /// draw calls inside the render pass.
    public func frame(clear: ClearColor) {
        guard let texture = context.getCurrentTexture!().object,
              let view = texture.createView!().object else { return }

        let colorAttachment = newObject([
            "view": .object(view),
            "loadOp": .string("clear"),
            "storeOp": .string("store"),
            "clearValue": .object(newObject([
                "r": .number(clear.r),
                "g": .number(clear.g),
                "b": .number(clear.b),
                "a": .number(clear.a),
            ])),
        ])
        let attachments = JSObject.global.Array.function!.new(colorAttachment)
        let descriptor = newObject([
            "colorAttachments": .object(attachments),
        ])

        guard let encoder = device.createCommandEncoder!().object,
              let pass = encoder.beginRenderPass!(.object(descriptor)).object else { return }
        _ = pass.end!()
        guard let cmd = encoder.finish!().object else { return }
        let submitList = JSObject.global.Array.function!.new(cmd)
        _ = queue.submit!(submitList)
    }
}

@inline(__always)
func newObject(_ pairs: [String: JSValue]) -> JSObject {
    var obj = JSObject.global.Object.function!.new()
    for (k, v) in pairs { obj[k] = v }
    return obj
}

@inline(__always)
private func awaitJSPromise(_ value: JSValue) async throws -> JSValue {
    guard let obj = value.object, let promise = JSPromise(obj) else { return value }
    return try await promise.value
}
#endif
