import XCTest
@testable import PensieveIngestCore

final class VaultWriterMindmapTests: XCTestCase {
    func testWritesJSONAndHTML() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmp.appendingPathComponent("wiki"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let state = MindmapState(version: 1, lastUpdated: "2026-04-25",
            root: MindmapNode(id: "root", label: "Brain", noteCount: 0,
                              importance: 10, summary: "", sourcePages: [], children: []))
        let writer = VaultWriter(vaultURL: tmp)
        try writer.writeMindmap(state: state, html: "<html><body>x</body></html>")

        let json = try String(contentsOf: tmp.appendingPathComponent("wiki/mindmap.json"), encoding: .utf8)
        XCTAssertTrue(json.contains("\"version\""))
        let html = try String(contentsOf: tmp.appendingPathComponent("wiki/mindmap.html"), encoding: .utf8)
        XCTAssertEqual(html, "<html><body>x</body></html>")
    }
}
