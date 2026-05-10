import Testing
@testable import Bielik2D

@Test func vertexLayoutOffsetsMatchSwiftMemoryLayout() {
    let layout = Vertex.bufferLayout
    #expect(layout.stride == MemoryLayout<Vertex>.stride)

    // Every declared attribute must match Swift's natural offset for that field.
    func offset(_ keyPath: PartialKeyPath<Vertex>) -> UInt32 {
        UInt32(MemoryLayout<Vertex>.offset(of: keyPath)!)
    }

    let byName = Dictionary(uniqueKeysWithValues: Vertex.attributeKeyPaths.map { ($0.name, $0.keyPath) })
    for attr in layout.attributes {
        guard let kp = byName[attr.name] else {
            Issue.record("attribute \(attr.name) has no matching keypath")
            continue
        }
        #expect(attr.offset == offset(kp), "offset mismatch for \(attr.name)")
    }
}

@Test func vertexHasAllCFFields() {
    // Sanity: the CF-style fields are all present.
    let names = Vertex.bufferLayout.attributes.map(\.name)
    let expected: Set<String> = ["pos", "uv", "color", "radius", "stroke", "aa", "type", "alpha", "fill", "posH", "attributes", "uvBounds"]
    #expect(expected.isSubset(of: Set(names)))
}
