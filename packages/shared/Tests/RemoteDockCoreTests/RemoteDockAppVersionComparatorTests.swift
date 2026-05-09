import XCTest
@testable import RemoteDockCore

final class RemoteDockAppVersionComparatorTests: XCTestCase {
    func testReturnsNilForMatchingVersions() {
        XCTAssertNil(RemoteDockAppVersionComparator.mismatch(local: "1.2.0", remote: "1.2"))
    }

    func testDetectsLocalNewerVersion() {
        XCTAssertEqual(
            RemoteDockAppVersionComparator.mismatch(local: "1.3.0", remote: "1.2.9"),
            .localNewer
        )
    }

    func testDetectsRemoteNewerVersion() {
        XCTAssertEqual(
            RemoteDockAppVersionComparator.mismatch(local: "1.2.9", remote: "1.3.0"),
            .remoteNewer
        )
    }

    func testComparesNumericPrefixesInSuffixVersions() {
        XCTAssertEqual(
            RemoteDockAppVersionComparator.mismatch(local: "2.0.0", remote: "2.0.1-beta"),
            .remoteNewer
        )
    }

    func testReturnsNilForMissingVersions() {
        XCTAssertNil(RemoteDockAppVersionComparator.mismatch(local: nil, remote: "1.0.0"))
        XCTAssertNil(RemoteDockAppVersionComparator.mismatch(local: "1.0.0", remote: nil))
    }
}
