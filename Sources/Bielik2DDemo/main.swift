import Bielik2D

let app = try App(title: "Bielik2D Demo", width: 1280, height: 720)
print("GPU driver: \(app.gpu.driverName)")
while app.isRunning {
    app.update()
}
app.destroy()
