#if os(WASI)
import JavaScriptKit

/// Browser counterpart of `SDL3Platform`. Owns the `<canvas>`, drives a
/// `requestAnimationFrame` tick, and feeds a minimal `keyJustPressed` set
/// from a `keydown` listener.
public final class WebPlatform {
    public let canvas: JSObject
    public private(set) var size: SIMD2<Int>
    public private(set) var shouldQuit: Bool = false
    private var keysJustPressed: Set<String> = []
    private var keysPending: Set<String> = []
    private var rafClosure: JSClosure?
    private var keyDownClosure: JSClosure?

    private init(canvas: JSObject, size: SIMD2<Int>) {
        self.canvas = canvas
        self.size = size
        installKeyListeners()
    }

    public static func attach(canvasID: String) throws -> WebPlatform {
        let document = JSObject.global.document
        let lookup = document.getElementById!(canvasID)
        guard let canvas = lookup.object else {
            throw WebPlatformError.canvasNotFound(canvasID)
        }
        let dpr = JSObject.global.devicePixelRatio.number ?? 1.0
        let rect = canvas.getBoundingClientRect!()
        let cssW = rect.width.number ?? 0
        let cssH = rect.height.number ?? 0
        let w = Int((cssW * dpr).rounded())
        let h = Int((cssH * dpr).rounded())
        var mutCanvas = canvas
        mutCanvas["width"] = .number(Double(w))
        mutCanvas["height"] = .number(Double(h))
        return WebPlatform(canvas: mutCanvas, size: SIMD2(w, h))
    }

    /// Drives `body` once per `requestAnimationFrame`. The closure receives
    /// the time delta in seconds since the previous frame.
    public func run(_ body: @escaping (Double) -> Void) {
        var lastTime: Double = 0
        let requestFrame = JSObject.global.requestAnimationFrame.function!

        let tick = JSClosure { [weak self] args in
            guard let self else { return .undefined }
            let now = args.first?.number ?? 0
            let dt = lastTime == 0 ? 0 : (now - lastTime) / 1000.0
            lastTime = now
            self.beginFrame()
            body(dt)
            if !self.shouldQuit, let next = self.rafClosure {
                _ = requestFrame(next)
            }
            return .undefined
        }
        self.rafClosure = tick
        _ = requestFrame(tick)
    }

    public func keyJustPressed(_ code: String) -> Bool {
        keysJustPressed.contains(code)
    }

    public func requestQuit() {
        shouldQuit = true
    }

    private func beginFrame() {
        keysJustPressed = keysPending
        keysPending.removeAll(keepingCapacity: true)
    }

    private func installKeyListeners() {
        let onKeyDown = JSClosure { [weak self] args in
            guard let self, let event = args.first?.object else { return .undefined }
            if event["repeat"].boolean == true { return .undefined }
            if let code = event["code"].string {
                self.keysPending.insert(code)
            }
            return .undefined
        }
        self.keyDownClosure = onKeyDown
        _ = JSObject.global.addEventListener!("keydown", onKeyDown)
    }
}

public enum WebPlatformError: Error, CustomStringConvertible {
    case canvasNotFound(String)

    public var description: String {
        switch self {
        case .canvasNotFound(let id): "canvas element '#\(id)' not found in DOM"
        }
    }
}
#endif
