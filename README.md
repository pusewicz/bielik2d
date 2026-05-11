# Bielik2D

A 2D engine in pure Swift 6.3 on top of SDL3's modern GPU API. Inspired by [Cute Framework](https://github.com/RandyGaul/cute_framework), reimagined Swift-side.

v0 is functional: sprites, SDF primitives (circle, line), render-to-texture canvases, and text via SDL3_ttf. See [`TODO.md`](TODO.md) for the phased roadmap.

## Requirements

- macOS 15+ on Apple Silicon. Other platforms are unvalidated.
- Swift 6.3 toolchain.
- Homebrew packages:

  ```sh
  brew install sdl3 sdl3_image sdl3_ttf glslang spirv-cross spirv-tools spirv-headers
  ```

- `SDL_shadercross` is vendored under `vendor/` and built locally.

## Build

```sh
git clone --recurse-submodules <repo>
cd bielik2d
./scripts/build-vendor.sh   # builds SDL_shadercross into vendor/.install/
./Shaders/build.sh          # compiles HLSL → SPIR-V
swift build
swift test
swift run Bielik2DDemo
```

The demo opens a window with a spinning pink quad, a blue filled circle, a yellow line, and a "Hello, Bielik!" label.

## Web build (experimental)

The `web` branch ships a parallel WebAssembly + WebGPU target. It does not use SDL3 — the platform layer is JavaScriptKit and the renderer is WebGPU through the browser's JS API.

```sh
swiftly install 6.3 && swiftly use 6.3
swift sdk install \
  https://download.swift.org/swift-6.3-release/wasm-sdk/swift-6.3-RELEASE/swift-6.3-RELEASE_wasm.artifactbundle.tar.gz \
  --checksum 9fa4016ee632c7e9e906608ec3b55cf13dfc4dff44e47574c5af58064dc33fd9
./scripts/build-web.sh
python3 -m http.server -d web/dist
```

Then open `http://localhost:8000` in Chrome or another WebGPU-capable browser. Set `BIELIK2D_WASM_SDK` to override the SDK ID if `swift sdk list` shows a different name.

## Layout

| Path | What's in it |
| --- | --- |
| `Sources/Bielik2D/App/` | `App` lifecycle, window, event loop |
| `Sources/Bielik2D/GPU/` | SDL_GPU wrappers — `GPUDevice`, `CommandBuffer`, `Texture`, `Buffer`, `Sampler`, `TransferBuffer`, `CopyPass`, `RenderPass`, `Shader`, `GraphicsPipeline`, `PipelineCache` |
| `Sources/Bielik2D/Draw/` | `Vertex`, `Batcher`, `Draw` (immediate-mode), `Sprite`, `Canvas`, `Camera`, `Color`, `Primitives` (SDF shapes), `StateStack` |
| `Sources/Bielik2D/Text/` | `Font`, `TextEngine`, `Draw.text(_:font:at:color:)` |
| `Sources/Bielik2D/Math/` | `Mat3x2`, `Rect` |
| `Sources/Bielik2D/Resources/shaders/` | Pre-compiled SPIR-V bytecode (built by `Shaders/build.sh`) |
| `Sources/CSDL3/` | systemLibrary umbrella for SDL3, SDL3_image, SDL3_ttf |
| `Sources/CSDL3Shadercross/` | systemLibrary for the vendored shadercross |
| `Sources/Bielik2DDemo/` | Runnable example (macOS) |
| `Sources/Bielik2DWeb/` | WebGPU/JavaScriptKit web target |
| `Sources/Bielik2DWebDemo/` | Runnable example (web, via `scripts/build-web.sh`) |
| `Shaders/src/` | HLSL sources compiled to SPIR-V at build time |
| `vendor/SDL_shadercross/` | git submodule |
| `Tests/Bielik2DTests/` | Red-green TDD suite |

## Example

```swift
import Bielik2D

let app = try App(title: "Hello", width: 1280, height: 720)
let batcher = Batcher()
let draw = Draw(batcher: batcher)
let camera = Camera(viewportSize: SIMD2(1280, 720))

while app.isRunning {
    app.update()
    guard let window = app.window else { break }

    batcher.reset()
    draw.circleFill(center: SIMD2(640, 360), radius: 100, color: .white)

    let cmd = try app.gpu.acquireCommandBuffer()
    guard let swap = cmd.acquireSwapchainTexture(for: window, device: app.gpu) else {
        cmd.submit(); continue
    }
    cmd.pushVertexUniform(camera.viewProjection)
    cmd.withRenderPass(colorTarget: swap, clear: .black) { _ in
        // bind pipeline, draw — see Bielik2DDemo for the full pattern.
    }
    cmd.submit()
}
app.destroy()
```
