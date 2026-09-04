import Foundation
import XCTest
@testable import QuickJasoCore

final class GitRepositoryDetectorTests: TemporaryDirectoryTestCase {
    func testDetectsGitDirectoryFromDescendant() throws {
        let root = try makeTemporaryDirectory()
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".git"),
            withIntermediateDirectories: false
        )
        let descendant = root.appendingPathComponent("Sources/Feature")
        try FileManager.default.createDirectory(at: descendant, withIntermediateDirectories: true)
        XCTAssertTrue(GitRepositoryDetector().isInsideGitRepository(descendant))
    }

    func testDetectsGitFile() throws {
        let root = try makeTemporaryDirectory()
        try Data("gitdir: elsewhere".utf8).write(to: root.appendingPathComponent(".git"))
        XCTAssertTrue(GitRepositoryDetector().isInsideGitRepository(root))
    }

    func testReturnsFalseOutsideRepository() throws {
        let root = try makeTemporaryDirectory()
        XCTAssertFalse(GitRepositoryDetector().isInsideGitRepository(root))
    }
}
