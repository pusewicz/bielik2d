#if os(WASI)
import JavaScriptKit
import JavaScriptEventLoop
import Bielik2DWeb

JavaScriptEventLoop.installGlobalExecutor()

Task {
    do {
        let platform = try WebPlatform.attach(canvasID: "bielik2d")
        let backend = try await WebGPURenderBackend.create(on: platform)
        let clear = ClearColor(r: 0.10, g: 0.12, b: 0.18, a: 1.0)
        platform.run { _ in
            backend.frame(clear: clear)
        }
    } catch {
        _ = JSObject.global.console.error!(String(describing: error))
    }
}
#else
import Bielik2DWeb
print("Bielik2DWeb \(Bielik2DWeb.version) — built for non-wasi target; run via scripts/build-web.sh")
#endif
