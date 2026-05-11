// Browser-side surface of Bielik2D. The pure-Swift bits (Math, Draw, Vertex,
// Batcher, Camera, Primitives) come from the `Bielik2D` module. This target
// adds the platform shell (`WebPlatform`) and the WebGPU backend
// (`WebGPURenderBackend`) glued together via JavaScriptKit.

public enum Bielik2DWeb {
    public static let version = "0.0.1"
}
