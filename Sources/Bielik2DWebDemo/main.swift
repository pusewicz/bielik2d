#if os(WASI)
import JavaScriptKit
import JavaScriptEventLoop
import Bielik2DWeb

JavaScriptEventLoop.installGlobalExecutor()

// Keep the platform + backend alive after `main` and the bootstrap Task return.
// Otherwise the rAF JSClosure WebPlatform owns gets dealloced and JS calls
// into freed memory on the next frame.
enum DemoState {
    nonisolated(unsafe) static var platform: WebPlatform?
    nonisolated(unsafe) static var backend: WebGPURenderBackend?
}

Task {
    do {
        let platform = try WebPlatform.attach(canvasID: "bielik2d")
        let backend = try await WebGPURenderBackend.create(on: platform)
        DemoState.platform = platform
        DemoState.backend = backend
        let clear = ClearColor(r: 0.10, g: 0.12, b: 0.18, a: 1.0)
        platform.run { _ in
            backend.frame(clear: clear)
        }
    } catch {
        print("bielik2d: error \(error)")
    }
}
#else
import Bielik2DWeb
print("Bielik2DWeb \(Bielik2DWeb.version) — built for non-wasi target; run via scripts/build-web.sh")
#endif
