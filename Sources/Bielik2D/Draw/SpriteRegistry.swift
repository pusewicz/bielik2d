#if canImport(CSDL3)
import Foundation

/// Anything that can stash an image's pixels and hand back a `SpriteID`. The atlas
/// (`SpriteBatch`) is the real one; tests substitute a fake so registry logic needs
/// no GPU.
protocol ImageRegistrar: AnyObject {
    func register(_ image: ImageBytes) -> SpriteID
}

extension SpriteBatch: ImageRegistrar {}

/// Loads sprite assets by path and caches them, so asking for the same file twice
/// reuses one asset (one atlas slot, one set of frames). The CF "easy sprite" cache.
/// Pixels are delegated to an `ImageRegistrar`; decoding to an injectable loader.
final class SpriteRegistry {
    private let registrar: ImageRegistrar
    private let load: (String) throws -> ImageBytes
    private var byPath: [String: SpriteAssetID] = [:]
    private var assets: [SpriteAsset] = []   // index == SpriteAssetID

    init(registrar: ImageRegistrar,
         load: @escaping (String) throws -> ImageBytes = SDL3AssetLoader.loadImage) {
        self.registrar = registrar
        self.load = load
    }

    func asset(_ id: SpriteAssetID) -> SpriteAsset { assets[id] }

    /// Builds a one-frame static asset straight from in-memory pixels (no path dedup).
    func makeStaticAsset(_ image: ImageBytes) -> SpriteAssetID {
        let frame = Frame(imageID: registrar.register(image),
                          width: image.width, height: image.height, duration: 0)
        return store(SpriteAsset(name: "", animations: [Animation(name: "default", frames: [frame], mode: .loop)]))
    }

    /// Loads `path` as a one-frame static asset, deduped by path.
    func loadAsset(path: String) throws -> SpriteAssetID {
        if let id = byPath[path] { return id }
        let id = makeStaticAsset(try load(path))
        byPath[path] = id
        return id
    }

    /// Slices `sheet` row-major into `frameWidth`×`frameHeight` cells, registering each
    /// as a frame of one looping `"default"` animation running at `fps`.
    func makeSheetAsset(_ sheet: ImageBytes, frameWidth: Int, frameHeight: Int, fps: Double) -> SpriteAssetID {
        let cols = sheet.width / frameWidth
        let rows = sheet.height / frameHeight
        let duration = fps > 0 ? 1.0 / fps : 0
        var frames: [Frame] = []
        frames.reserveCapacity(cols * rows)
        for row in 0..<rows {
            for col in 0..<cols {
                let cell = sheet.subImage(x: col * frameWidth, y: row * frameHeight,
                                          width: frameWidth, height: frameHeight)
                frames.append(Frame(imageID: registrar.register(cell),
                                    width: frameWidth, height: frameHeight, duration: duration))
            }
        }
        return store(SpriteAsset(name: "", animations: [Animation(name: "default", frames: frames, mode: .loop)]))
    }

    private func store(_ asset: SpriteAsset) -> SpriteAssetID {
        assets.append(asset)
        return assets.count - 1
    }
}
#endif
