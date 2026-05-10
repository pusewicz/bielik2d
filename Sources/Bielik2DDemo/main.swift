import Bielik2D

let app = try App(title: "Bielik2D Demo", width: 1280, height: 720)
print("GPU driver: \(app.gpu.driverName)")

while app.isRunning {
    app.update()
    guard let window = app.window else { break }
    let cmd = try app.gpu.acquireCommandBuffer()
    if let swap = cmd.acquireSwapchainTexture(for: window, device: app.gpu) {
        cmd.withRenderPass(colorTarget: swap, clear: Color(r: 0.10, g: 0.12, b: 0.18, a: 1.0)) { _ in }
    }
    cmd.submit()
}
app.destroy()
