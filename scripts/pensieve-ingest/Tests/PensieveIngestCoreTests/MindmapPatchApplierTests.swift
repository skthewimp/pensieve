import XCTest
@testable import PensieveIngestCore

final class MindmapPatchApplierTests: XCTestCase {
    private func base() -> MindmapState {
        let career = MindmapNode(id: "career", label: "Career", noteCount: 5,
                                 importance: 8, summary: "", sourcePages: [], children: [])
        let root = MindmapNode(id: "root", label: "Brain", noteCount: 0,
                               importance: 10, summary: "", sourcePages: [], children: [career])
        return MindmapState(version: 1, lastUpdated: "2026-04-24", root: root)
    }

    func testAddChild() throws {
        let newNode = MindmapNode(id: "career.consulting", label: "Consulting",
                                  noteCount: 0, importance: 7, summary: "",
                                  sourcePages: [], children: [])
        let patch = MindmapPatch(
            operations: [.add(parentId: "career", node: newNode)],
            insights: []
        )
        let updated = try MindmapPatchApplier.apply(patch, to: base())
        XCTAssertEqual(updated.root.children.first?.children.first?.id, "career.consulting")
    }

    func testUpdateImportance() throws {
        let patch = MindmapPatch(
            operations: [.update(id: "career", importance: 4, summary: nil, label: nil)],
            insights: []
        )
        let updated = try MindmapPatchApplier.apply(patch, to: base())
        XCTAssertEqual(updated.root.children.first?.importance, 4)
    }

    func testRemove() throws {
        let patch = MindmapPatch(
            operations: [.remove(id: "career")],
            insights: []
        )
        let updated = try MindmapPatchApplier.apply(patch, to: base())
        XCTAssertTrue(updated.root.children.isEmpty)
    }

    func testMoveReparents() throws {
        var b = base()
        let hobbies = MindmapNode(id: "hobbies", label: "Hobbies", noteCount: 0,
                                  importance: 4, summary: "", sourcePages: [], children: [])
        b.root.children.append(hobbies)
        let patch = MindmapPatch(
            operations: [.move(id: "hobbies", newParentId: "career")],
            insights: []
        )
        let updated = try MindmapPatchApplier.apply(patch, to: b)
        XCTAssertEqual(updated.root.children.count, 1)
        XCTAssertEqual(updated.root.children.first?.children.first?.id, "hobbies")
    }

    func testMergeAbsorbsChildren() throws {
        var b = base()
        let consulting = MindmapNode(id: "career.consulting", label: "Consulting",
                                     noteCount: 3, importance: 7, summary: "",
                                     sourcePages: [], children: [])
        let advisory = MindmapNode(id: "career.advisory", label: "Advisory",
                                   noteCount: 2, importance: 6, summary: "",
                                   sourcePages: [], children: [])
        b.root.children[0].children = [consulting, advisory]
        let patch = MindmapPatch(
            operations: [.merge(fromId: "career.advisory", intoId: "career.consulting")],
            insights: []
        )
        let updated = try MindmapPatchApplier.apply(patch, to: b)
        XCTAssertEqual(updated.root.children[0].children.count, 1)
        XCTAssertEqual(updated.root.children[0].children[0].id, "career.consulting")
    }

    func testUnknownIdIsIgnored() throws {
        let patch = MindmapPatch(
            operations: [.update(id: "ghost", importance: 1, summary: nil, label: nil)],
            insights: []
        )
        let updated = try MindmapPatchApplier.apply(patch, to: base())
        XCTAssertEqual(updated.root.children.first?.importance, 8) // unchanged
    }
}
