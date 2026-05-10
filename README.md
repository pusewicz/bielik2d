# Bielik2D

A 2D engine in pure Swift 6.3 on top of SDL3's modern GPU API. Inspired by [Cute Framework](https://github.com/RandyGaul/cute_framework), reimagined Swift-side.

Status: pre-alpha, under active build. See [`TODO.md`](TODO.md) for the phased roadmap.

## Requirements

- macOS 15+ on Apple Silicon (Metal backend). Other platforms unvalidated.
- Swift 6.3 toolchain.
- Homebrew:

  ```sh
  brew install sdl3 sdl3_image sdl3_ttf
  ```

- `SDL_shadercross` is vendored under `vendor/` (built locally, not from Homebrew).

## Build

```sh
git clone --recurse-submodules <repo>
cd bielik2d
./scripts/build-vendor.sh   # builds SDL_shadercross into vendor/.install/
swift build
swift test
swift run Bielik2DDemo
```

`build-vendor.sh` and submodules don't exist yet — they land in Phase 4. Until then, `swift build && swift test` is enough.

## Layout

- `Sources/Bielik2D/` — the engine (App, GPU, Draw, Text, Math, Shaders).
- `Sources/CSDL3*/` — system-library shims (SDL3, SDL3_image, SDL3_ttf, SDL_shadercross).
- `Sources/CBielik2DSupport/` — tiny C helpers for things ergonomically painful in Swift.
- `Sources/Bielik2DDemo/` — the runnable example.
- `Tests/Bielik2DTests/` — unit tests (TDD-first).
- `Shaders/src/` — HLSL sources compiled to SPIR-V at build time.
- `vendor/` — git submodules for `SDL_shadercross` and `SPIRV-Cross`.
