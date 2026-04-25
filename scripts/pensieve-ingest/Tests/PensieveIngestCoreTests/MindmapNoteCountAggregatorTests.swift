import XCTest
@testable import PensieveIngestCore

final class MindmapNoteCountAggregatorTests: XCTestCase {
    private func themesDir() -> URL {
        guard let url = Bundle.module.url(
            forResource: "career", withExtension: "md",
            subdirectory: "Fixtures/sample-themes"
        ) else {
            fatalError("test fixture missing — check Package.swift resources directive and Fixtures path")
        }
        return url.deletingLastPathComponent()
    }

    func testCountsPerThemeFromFrontmatter() throws {
        let counts = try MindmapNoteCountAggregator.countsFromThemesDir(themesDir())
        XCTAssertEqual(counts["career"], 12)
        XCTAssertEqual(counts["mental-health"], 5)
    }

    func testMissingFieldsDefaultToZero() throws {
        let counts = try MindmapNoteCountAggregator.countsFromThemesDir(themesDir())
        XCTAssertNil(counts["nonexistent"])
    }

    func testMissingDirectoryReturnsEmpty() throws {
        let bogus = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString)")
        let counts = try MindmapNoteCountAggregator.countsFromThemesDir(bogus)
        XCTAssertTrue(counts.isEmpty)
    }
}
