import XCTest
@testable import PensieveIngestCore

final class SmokeTest: XCTestCase {
    func testLibraryImports() {
        // existence check; will fail to compile if module is broken
        let _: VaultReader.Type = VaultReader.self
    }
}
