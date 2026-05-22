#if canImport(CSDL3)

/// One atlas texture plus the packer that tracks free space on it. Sprites are
/// uploaded into sub-regions of `texture`; `packer` hands out their slots.
struct AtlasPage {
    let texture: Texture
    let width: Int
    let height: Int
    var packer: SkylinePacker

    init(texture: Texture, width: Int, height: Int) {
        self.texture = texture
        self.width = width
        self.height = height
        self.packer = SkylinePacker(width: width, height: height)
    }
}
#endif
