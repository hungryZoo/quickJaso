import Foundation
import XCTest
@testable import QuickJasoCore

final class FileTreeScannerTests: TemporaryDirectoryTestCase {
    private let scanner = FileTreeScanner()

    func testFindsNFDFileAndFolderWithRelativePathsAndDepths() throws {
        let root = try makeTemporaryDirectory().appendingPathComponent("Root")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let folderName = "\u{1111}\u{1169}\u{11AF}\u{1103}\u{1165}"
        let fileName = "\u{1112}\u{1161}\u{11AB}\u{1100}\u{1173}\u{11AF}.txt"
        let folder = root.appendingPathComponent(folderName)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        try Data("content".utf8).write(to: folder.appendingPathComponent(fileName))

        XCTAssertTrue(try onDiskNames(in: root).contains(Array(folderName.utf8)))
        XCTAssertTrue(try onDiskNames(in: folder).contains(Array(fileName.utf8)))

        let result = scanner.scan(roots: [root])
        let folderItem = try XCTUnwrap(result.items.first { bytesEqual($0.originalName, folderName) })
        let fileItem = try XCTUnwrap(result.items.first { bytesEqual($0.originalName, fileName) })

        XCTAssertEqual(folderItem.status, .needsRename)
        XCTAssertEqual(fileItem.status, .needsRename)
        XCTAssertEqual(folderItem.depth, 1)
        XCTAssertEqual(fileItem.depth, 2)
        XCTAssertTrue(bytesEqual(folderItem.originalRelativePath, "Root/\(folderName)"))
        XCTAssertTrue(bytesEqual(fileItem.originalRelativePath, "Root/\(folderName)/\(fileName)"))
    }

    func testSymlinkToDirectoryIsNotFollowed() throws {
        let root = try makeTemporaryDirectory()
        let target = root.appendingPathComponent("Target")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        try Data().write(to: target.appendingPathComponent("inside.txt"))
        let link = root.appendingPathComponent("Link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let result = scanner.scan(roots: [link])
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items.first?.kind, .symlink)
        XCTAssertFalse(result.items.contains { $0.originalName == "inside.txt" })
    }

    func testPackageRecursionOption() throws {
        let root = try makeTemporaryDirectory()
        let package = root.appendingPathComponent("Foo.app")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: false)
        let nfdName = "\u{1112}\u{1161}\u{11AB}.txt"
        try Data().write(to: package.appendingPathComponent(nfdName))
        XCTAssertTrue(try onDiskNames(in: package).contains(Array(nfdName.utf8)))

        let defaultResult = scanner.scan(roots: [package])
        XCTAssertEqual(defaultResult.items.first?.kind, .package)
        XCTAssertEqual(defaultResult.items.count, 1)

        var options = ScanOptions.default
        options.recurseIntoPackages = true
        let recursiveResult = scanner.scan(roots: [package], options: options)
        XCTAssertEqual(recursiveResult.items.count, 2)
        XCTAssertTrue(recursiveResult.items.contains { bytesEqual($0.originalName, nfdName) })
    }

    func testSystemAndHiddenFileRules() throws {
        let root = try makeTemporaryDirectory()
        try Data().write(to: root.appendingPathComponent(".DS_Store"))
        try Data().write(to: root.appendingPathComponent(".hidden"))

        let defaultResult = scanner.scan(roots: [root])
        XCTAssertFalse(defaultResult.items.contains { $0.originalName == ".DS_Store" })
        XCTAssertTrue(defaultResult.items.contains { $0.originalName == ".hidden" })

        var options = ScanOptions.default
        options.includeHidden = false
        let excludingHidden = scanner.scan(roots: [root], options: options)
        XCTAssertFalse(excludingHidden.items.contains { $0.originalName == ".hidden" })
    }

    func testNonexistentRootIsInaccessible() throws {
        let missing = try makeTemporaryDirectory().appendingPathComponent("missing")
        let result = scanner.scan(roots: [missing])
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items.first?.status, .inaccessible)
        XCTAssertEqual(result.items.first?.message, "항목을 찾을 수 없습니다")
    }

    func testRootURLSpelledInNFDForNFCFileIsAlreadyNFC() throws {
        let parent = try makeTemporaryDirectory()
        let nfcName = "한.txt"
        let nfdName = "\u{1112}\u{1161}\u{11AB}.txt"
        try writeRawNamedFile(in: parent, name: nfcName, contents: Data("payload".utf8))
        XCTAssertTrue(try onDiskNames(in: parent).contains(Array(nfcName.utf8)))

        let nfdSpelledURL = parent.appendingPathComponent(nfdName)
        let scan = scanner.scan(roots: [nfdSpelledURL])
        let item = try XCTUnwrap(scan.items.first)

        XCTAssertEqual(item.status, .alreadyNFC)
        XCTAssertTrue(bytesEqual(item.originalName, nfcName))
        XCTAssertTrue(bytesEqual(item.originalURL.lastPathComponent, nfcName))

        let report = ConversionPipeline().inspect(urls: [nfdSpelledURL])
        XCTAssertEqual(report.summary.alreadyNFC, 1)
        XCTAssertEqual(report.summary.needsRename, 0)
        XCTAssertEqual(report.summary.collisions, 0)
    }

    func testRootURLSpelledInNFCForNFDFileNeedsRename() throws {
        let parent = try makeTemporaryDirectory()
        let nfcName = "한.txt"
        let nfdName = "\u{1112}\u{1161}\u{11AB}.txt"
        try Data("payload".utf8).write(to: parent.appendingPathComponent(nfdName))
        XCTAssertTrue(try onDiskNames(in: parent).contains(Array(nfdName.utf8)))

        let nfcSpelledURL = parent.appendingPathComponent(nfcName)
        let scan = scanner.scan(roots: [nfcSpelledURL])
        let item = try XCTUnwrap(scan.items.first)
        XCTAssertEqual(item.status, .needsRename)
        XCTAssertTrue(bytesEqual(item.originalName, nfdName))

        let plan = RenamePlanner().makePlan(from: scan)
        let result = RenameExecutor().execute(plan: plan)
        XCTAssertEqual(result.items.first?.status, .renamed)
        let names = try onDiskNames(in: parent)
        XCTAssertTrue(names.contains(Array(nfcName.utf8)))
        XCTAssertFalse(names.contains(Array(nfdName.utf8)))
    }

    func testDirectoryRootSpelledInNFDForNFCDirectoryUsesOnDiskName() throws {
        let parent = try makeTemporaryDirectory()
        let nfcName = "한글"
        let nfdName = "\u{1112}\u{1161}\u{11AB}\u{1100}\u{1173}\u{11AF}"
        let onDiskDirectory = try createRawNamedDirectory(in: parent, name: nfcName)
        let childName = "파일.txt"
        try writeRawNamedFile(in: onDiskDirectory, name: childName)
        XCTAssertTrue(try onDiskNames(in: parent).contains(Array(nfcName.utf8)))

        let scan = scanner.scan(roots: [parent.appendingPathComponent(nfdName, isDirectory: true)])
        let rootItem = try XCTUnwrap(scan.items.first { $0.isRoot })
        XCTAssertEqual(rootItem.status, .alreadyNFC)
        XCTAssertEqual(rootItem.kind, .directory)
        XCTAssertTrue(bytesEqual(rootItem.originalName, nfcName))
        XCTAssertTrue(bytesEqual(rootItem.originalRelativePath, nfcName))
        XCTAssertTrue(bytesEqual(rootItem.originalURL.lastPathComponent, nfcName))
        let childItem = try XCTUnwrap(scan.items.first { !$0.isRoot })
        XCTAssertTrue(bytesEqual(childItem.originalName, childName))
        XCTAssertTrue(bytesEqual(childItem.originalRelativePath, "\(nfcName)/\(childName)"))
        XCTAssertTrue(bytesEqual(childItem.originalURL.lastPathComponent, childName))
    }
}
