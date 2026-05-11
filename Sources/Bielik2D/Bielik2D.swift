import Foundation

public enum Bielik2D {
    public static let version = "0.0.1"

    public enum ShaderResourceError: Error, CustomStringConvertible {
        case notBundled(String)

        public var description: String {
            switch self {
            case .notBundled(let n): "shader resource not bundled: \(n)"
            }
        }
    }

    /// Returns the WGSL source of a built-in shader by base name, e.g. `"sprite.frag"`.
    /// macOS reads from the SwiftPM bundle; web builds serve the same files as
    /// static assets via `scripts/build-web.sh`.
    public static func loadBuiltinWGSL(named name: String) throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "wgsl", subdirectory: "shaders") else {
            throw ShaderResourceError.notBundled("\(name).wgsl")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
