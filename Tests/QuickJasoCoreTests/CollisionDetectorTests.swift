import Foundation
import XCTest
@testable import QuickJasoCore

final class CollisionDetectorTests: TemporaryDirectoryTestCase {
    func testExistingExactNFCSiblingIsCollision() throws {
        let parent = try makeTemporaryDirectory()
        let nfd = "e\u{0301}.txt"
        let item = makeItem(parent: parent, name: nfd)
        let existing = FilenameInspectionItem(
            originalURL: parent.appendingPathComponent("é.txt"),
            originalRelativePath: "é.txt",
            originalName: "é.txt",
            normalizedNFCName: "é.txt",
            kind: .file,
            status: .alreadyNFC,
            depth: 0,
            parentURL: parent.standardizedFileURL
        )
        let listings = [parent.standardizedFileURL: Set([nfd, "é.txt"])]

        let detected = CollisionDetector().detect(items: [item, existing], listings: listings)
        XCTAssertEqual(detected.first?.status, .collision)
    }

    func testDifferentDecompositionsConvergingAreBothCollisions() throws {
        let parent = try makeTemporaryDirectory()
        let fullyDecomposed = "a\u{0301}\u{0323}.txt"
        let partiallyComposed = "a\u{0323}\u{0301}.txt"
        let items = [
            makeItem(parent: parent, name: fullyDecomposed),
            makeItem(parent: parent, name: partiallyComposed)
        ]
        let detected = CollisionDetector().detect(
            items: items,
            listings: [parent.standardizedFileURL: Set([fullyDecomposed, partiallyComposed])]
        )
        XCTAssertEqual(detected.map(\.status), [.collision, .collision])
    }

    func testReconvertAfterConversionReportsAllAlreadyNFC() throws {
        let root = try makeTemporaryDirectory().appendingPathComponent("Root", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let nfdName = "\u{1112}\u{1161}\u{11AB}.txt"
        let nfcName = "한.txt"
        let nfdURL = root.appendingPathComponent(nfdName)
        try Data("payload".utf8).write(to: nfdURL)

        let pipeline = ConversionPipeline()
        let (firstPlan, _) = pipeline.plan(urls: [nfdURL])
        let conversion = pipeline.execute(plan: firstPlan)
        XCTAssertEqual(conversion.summary.renamed, 1)
        XCTAssertTrue(try onDiskNames(in: root).contains(Array(nfcName.utf8)))

        let roots = [root, nfdURL]
        let inspection = pipeline.inspect(urls: roots)
        XCTAssertEqual(inspection.summary.needsRename, 0)
        XCTAssertEqual(inspection.summary.collisions, 0)
        XCTAssertEqual(inspection.summary.alreadyNFC, inspection.summary.total)

        let (secondPlan, _) = pipeline.plan(urls: roots)
        XCTAssertEqual(secondPlan.summary.needsRename, 0)
        XCTAssertEqual(secondPlan.summary.collisions, 0)
        XCTAssertEqual(secondPlan.summary.alreadyNFC, secondPlan.summary.total)
        XCTAssertTrue(secondPlan.operations.isEmpty)
    }

    private func makeItem(parent: URL, name: String) -> FilenameInspectionItem {
        FilenameInspectionItem(
            originalURL: parent.appendingPathComponent(name),
            originalRelativePath: name,
            originalName: name,
            normalizedNFCName: FilenameNormalizer.normalizedNFC(name),
            kind: .file,
            status: .needsRename,
            depth: 0,
            parentURL: parent.standardizedFileURL,
            isRoot: true
        )
    }
}
