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

The same `Bielik2DDemo` — all 11 scenes — runs in the browser on WebAssembly + WebGPU from a single target (no separate web demo). It does not use SDL3: the platform layer is JavaScriptKit and the renderer is WebGPU through the browser's JS API, with a `Web Audio` backend, Canvas2D text, and browser keyboard/mouse/gamepad wired into the engine's `Input`. Pure-Swift bits (`Draw`, `Batcher`, `Vertex`, `Primitives`, `Camera`, `Mat3x2`, scenes) are reused unchanged. All scenes are verified rendering in Chrome with zero WebGPU validation warnings.

It auto-deploys to GitHub Pages via the `deploy-web` workflow (`.github/workflows/deploy-web.yml`) — once deployed, it's served at <https://pusewicz.github.io/bielik2d/>.

One-time setup (installs `swiftly`, the Swift 6.3.1 toolchain, and the wasm SDK; idempotent):

```sh
./scripts/install-wasm-sdk.sh
```

Build and serve in one step:

```sh
./Shaders/build.sh         # compiles HLSL → SPIR-V and emits WGSL via naga
./scripts/start-web.sh     # build-web.sh + python http.server + opens the page
```

Or split the steps for tighter iteration:

```sh
./scripts/build-web.sh --product Bielik2DDemo   # cross-compiles to wasm32 via PackageToJS plugin → web/dist
python3 -m http.server -d web/dist
```

`scripts/start-web.sh` defaults to port 8000 — override with `PORT=9000 ./scripts/start-web.sh`. The demo runs in any WebGPU-capable browser (Chrome / Edge / Safari 18.2+) and is the same 11-scene `Bielik2DDemo` as the native build — switch scenes with the keyboard. Note: audio needs a user gesture (a click or key) before the browser's `AudioContext` produces sound. Override `BIELIK2D_WASM_SDK` if `swift sdk list` reports a different SDK id.

The host HTML uses an import map to resolve the `@bjorn3/browser_wasi_shim` bare specifier the PackageToJS plugin emits — no bundler required, just a static server.

## Layout

| Path | What's in it |
| --- | --- |
| `Sources/Bielik2D/App/` | `App` lifecycle, window, event loop |
| `Sources/Bielik2D/GPU/` | SDL_GPU wrappers — `GPUDevice`, `CommandBuffer`, `Texture`, `Buffer`, `Sampler`, `TransferBuffer`, `CopyPass`, `RenderPass`, `Shader`, `GraphicsPipeline`, `PipelineCache` |
| `Sources/Bielik2D/Draw/` | `Vertex`, `Batcher`, `Draw` (immediate-mode), `Sprite`, `Canvas`, `Camera`, `Color`, `Primitives` (SDF shapes), `StateStack` |
| `Sources/Bielik2D/Text/` | `Font`, `TextEngine`, `Draw.text(_:font:at:color:)` |
| `Sources/Bielik2D/Math/` | `Mat3x2`, `Rect` |
| `Sources/Bielik2D/Backend/` | `SDL3Platform`, `SDL3AssetLoader` — extracted seams so the Web target can stand parallel |
| `Sources/Bielik2D/Resources/shaders/` | Pre-compiled SPIR-V + WGSL (built by `Shaders/build.sh`) |
| `Shaders/wgsl/` | Hand-written WGSL overrides that overlay naga's output |
| `Sources/CSDL3/` | systemLibrary umbrella for SDL3, SDL3_image, SDL3_ttf |
| `Sources/CSDL3Shadercross/` | systemLibrary for the vendored shadercross |
| `Sources/Bielik2DDemo/` | Runnable 11-scene example — native (`swift run Bielik2DDemo`) and web (`./scripts/build-web.sh --product Bielik2DDemo`) |
| `Sources/Bielik2DWeb/` | WebGPU/JavaScriptKit web platform layer (`WebRenderer`, Web Audio, Canvas2D text, input bridge) |
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
