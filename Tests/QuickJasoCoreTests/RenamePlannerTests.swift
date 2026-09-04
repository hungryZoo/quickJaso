import Foundation
import XCTest
@testable import QuickJasoCore

final class RenamePlannerTests: TemporaryDirectoryTestCase {
    func testDestinationIsUnderParent() throws {
        let parent = try makeTemporaryDirectory()
        let nfd = "\u{1112}\u{1161}\u{11AB}.txt"
        let source = parent.appendingPathComponent(nfd)
        try Data().write(to: source)

        let scan = FileTreeScanner().scan(roots: [source])
        let plan = RenamePlanner().makePlan(from: scan)
        let operation = try XCTUnwrap(plan.operations.first)
        XCTAssertEqual(operation.destinationURL.deletingLastPathComponent(), parent.standardizedFileURL)
        XCTAssertEqual(operation.destinationURL.lastPathComponent, "한.txt")
    }

    func testOperationsAreSortedBottomUpThenByPath() throws {
        let parent = try makeTemporaryDirectory()
        let first = makeItem(parent: parent, name: "e\u{0301}.txt", relative: "Root/e\u{0301}.txt", depth: 1)
        let deep = makeItem(parent: parent, name: "a\u{0301}.txt", relative: "Root/Sub/a\u{0301}.txt", depth: 2)
        let second = makeItem(parent: parent, name: "o\u{0301}.txt", relative: "Root/o\u{0301}.txt", depth: 1)
        let listing = Set([first.originalName, deep.originalName, second.originalName])
        let scan = ScanResult(items: [first, second, deep], directoryListings: [parent.standardizedFileURL: listing])

        let operations = RenamePlanner().makePlan(from: scan).operations
        XCTAssertEqual(operations.map(\.depth), [2, 1, 1])
        XCTAssertTrue(operations[1].originalRelativePath.utf8.lexicographicallyPrecedes(operations[2].originalRelativePath.utf8))
    }

    private func makeItem(parent: URL, name: String, relative: String, depth: Int) -> FilenameInspectionItem {
        FilenameInspectionItem(
            originalURL: parent.appendingPathComponent(name),
            originalRelativePath: relative,
            originalName: name,
            normalizedNFCName: FilenameNormalizer.normalizedNFC(name),
            kind: .file,
            status: .needsRename,
            depth: depth,
            parentURL: parent.standardizedFileURL
        )
    }
}
