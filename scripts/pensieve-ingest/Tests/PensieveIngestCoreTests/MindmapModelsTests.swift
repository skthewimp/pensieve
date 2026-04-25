import XCTest
@testable import PensieveIngestCore

final class MindmapModelsTests: XCTestCase {
    func testStateRoundTrip() throws {
        let root = MindmapNode(
            id: "root", label: "Brain", noteCount: 0, importance: 10,
            summary: "the user's mind", sourcePages: [],
            children: [
                MindmapNode(id: "career", label: "Career", noteCount: 12,
                            importance: 9, summary: "work life",
                            sourcePages: ["themes/career.md"], children: [])
            ]
        )
        let state = MindmapState(version: 1, lastUpdated: "2026-04-25", root: root)
        let data = try JSONEncoder().encode(state)
        let back = try JSONDecoder().decode(MindmapState.self, from: data)
        XCTAssertEqual(back.root.children.first?.id, "career")
        XCTAssertEqual(back.root.children.first?.noteCount, 12)
    }

    func testNodeOpAddDecodes() throws {
        let json = """
        {"add":{"parentId":"root","node":{"id":"hobbies","label":"Hobbies","noteCount":0,"importance":5,"summary":"","sourcePages":[],"children":[]}}}
        """.data(using: .utf8)!
        let op = try JSONDecoder().decode(NodeOp.self, from: json)
        if case .add(let parent, let node) = op {
            XCTAssertEqual(parent, "root")
            XCTAssertEqual(node.id, "hobbies")
        } else { XCTFail("expected .add") }
    }

    func testNodeOpUpdateDecodes() throws {
        let json = """
        {"update":{"id":"career","importance":4,"summary":"shifted","label":null}}
        """.data(using: .utf8)!
        if case .update(let id, let imp, let summary, let label) =
            try JSONDecoder().decode(NodeOp.self, from: json) {
            XCTAssertEqual(id, "career")
            XCTAssertEqual(imp, 4)
            XCTAssertEqual(summary, "shifted")
            XCTAssertNil(label)
        } else { XCTFail("expected .update") }
    }

    func testNodeOpMoveDecodes() throws {
        let json = """
        {"move":{"id":"career.advisory","newParentId":"career.consulting"}}
        """.data(using: .utf8)!
        if case .move(let id, let parent) =
            try JSONDecoder().decode(NodeOp.self, from: json) {
            XCTAssertEqual(id, "career.advisory")
            XCTAssertEqual(parent, "career.consulting")
        } else { XCTFail("expected .move") }
    }

    func testNodeOpMergeDecodes() throws {
        let json = """
        {"merge":{"fromId":"a","intoId":"b"}}
        """.data(using: .utf8)!
        if case .merge(let from, let into) =
            try JSONDecoder().decode(NodeOp.self, from: json) {
            XCTAssertEqual(from, "a"); XCTAssertEqual(into, "b")
        } else { XCTFail("expected .merge") }
    }

    func testNodeOpRemoveDecodes() throws {
        let json = """
        {"remove":{"id":"old"}}
        """.data(using: .utf8)!
        if case .remove(let id) =
            try JSONDecoder().decode(NodeOp.self, from: json) {
            XCTAssertEqual(id, "old")
        } else { XCTFail("expected .remove") }
    }

    func testInsightRoundTrip() throws {
        let i = Insight(kind: .tooDeep, nodeId: "career.consulting.pricing",
                        message: "40 notes, importance 4")
        let data = try JSONEncoder().encode(i)
        let back = try JSONDecoder().decode(Insight.self, from: data)
        XCTAssertEqual(back.kind, .tooDeep)
    }
}
