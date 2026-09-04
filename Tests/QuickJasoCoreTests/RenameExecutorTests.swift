import Darwin
import Foundation
import XCTest
@testable import QuickJasoCore

final class RenameExecutorTests: TemporaryDirectoryTestCase {
    func testRenamesFileWithoutChangingContents() throws {
        let parent = try makeTemporaryDirectory()
        let nfd = "\u{1112}\u{1161}\u{11AB}.txt"
        let source = parent.appendingPathComponent(nfd)
        let contents = Data([0, 1, 2, 3, 255])
        try contents.write(to: source)

        let plan = makePlan(roots: [source])
        let result = RenameExecutor().execute(plan: plan)
        let destination = parent.appendingPathComponent("한.txt")

        XCTAssertEqual(result.items.first?.status, .renamed)
        XCTAssertEqual(try Data(contentsOf: destination), contents)
        XCTAssertEqual(result.record.renames.count, 1)
        let names = try onDiskNames(in: parent)
        XCTAssertTrue(names.contains(Array("한.txt".utf8)))
        XCTAssertFalse(names.contains(Array(nfd.utf8)))
    }

    func testNestedFoldersAndFileAreRenamedBottomUp() throws {
        let parent = try makeTemporaryDirectory()
        let outerNFD = "\u{1111}\u{1169}\u{11AF}\u{1103}\u{1165}"
        let innerNFD = "\u{1102}\u{1162}\u{1107}\u{116E}"
        let fileNFD = "\u{1112}\u{1161}\u{11AB}\u{1100}\u{1173}\u{11AF}.txt"
        let outer = parent.appendingPathComponent(outerNFD)
        let inner = outer.appendingPathComponent(innerNFD)
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        try Data("payload".utf8).write(to: inner.appendingPathComponent(fileNFD))

        let plan = makePlan(roots: [outer])
        let result = RenameExecutor().execute(plan: plan)
        let final = parent.appendingPathComponent("폴더/내부/한글.txt")

        XCTAssertEqual(result.items.filter { $0.status == .renamed }.count, 3)
        XCTAssertEqual(try Data(contentsOf: final), Data("payload".utf8))
        let parentNames = try onDiskNames(in: parent)
        XCTAssertTrue(parentNames.contains(Array("폴더".utf8)))
        XCTAssertFalse(parentNames.contains(Array(outerNFD.utf8)))
        let outerNames = try onDiskNames(in: parent.appendingPathComponent("폴더"))
        XCTAssertTrue(outerNames.contains(Array("내부".utf8)))
        XCTAssertFalse(outerNames.contains(Array(innerNFD.utf8)))
        let innerNames = try onDiskNames(in: parent.appendingPathComponent("폴더/내부"))
        XCTAssertTrue(innerNames.contains(Array("한글.txt".utf8)))
        XCTAssertFalse(innerNames.contains(Array(fileNFD.utf8)))
    }

    func testCollisionItemIsLeftUntouched() throws {
        let parent = try makeTemporaryDirectory()
        let nfd = "e\u{0301}.txt"
        let source = parent.appendingPathComponent(nfd)
        try Data("original".utf8).write(to: source)
        let collision = FilenameInspectionItem(
            originalURL: source,
            originalRelativePath: nfd,
            originalName: nfd,
            normalizedNFCName: "é.txt",
            plannedDestinationURL: parent.appendingPathComponent("é.txt"),
            kind: .file,
            status: .collision,
            message: "같은 이름의 다른 항목이 이미 존재합니다",
            depth: 0,
            parentURL: parent,
            isRoot: true
        )
        let plan = RenamePlan(
            items: [collision],
            operations: [],
            summary: InspectionSummary(items: [collision]),
            rootURLs: [source]
        )

        let result = RenameExecutor().execute(plan: plan)
        XCTAssertEqual(result.items.first?.status, .collision)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testReadOnlyParentReportsErrorAndContinues() throws {
        if getuid() == 0 { throw XCTSkip("root 사용자는 POSIX 쓰기 권한을 우회할 수 있습니다") }
        let base = try makeTemporaryDirectory()
        let locked = base.appendingPathComponent("Locked")
        let writable = base.appendingPathComponent("Writable")
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: writable, withIntermediateDirectories: false)
        let nfd = "\u{1112}\u{1161}\u{11AB}.txt"
        let lockedFile = locked.appendingPathComponent(nfd)
        let writableFile = writable.appendingPathComponent(nfd)
        try Data().write(to: lockedFile)
        try Data().write(to: writableFile)
        let plan = makePlan(roots: [lockedFile, writableFile])
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked.path)
        defer {
            // Restoring permissions is required so the temporary tree remains removable.
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: locked.path)
        }

        let result = RenameExecutor().execute(plan: plan)
        let lockedResult = try XCTUnwrap(result.items.first { $0.originalURL == lockedFile })
        let writableResult = try XCTUnwrap(result.items.first { $0.originalURL == writableFile })
        XCTAssertEqual(lockedResult.status, .error)
        XCTAssertEqual(writableResult.status, .renamed)
        let writableNames = try onDiskNames(in: writable)
        XCTAssertTrue(writableNames.contains(Array("한.txt".utf8)))
        XCTAssertFalse(writableNames.contains(Array(nfd.utf8)))
    }

    func testRenameActuallyChangesOnDiskBytesOnNormalizationInsensitiveVolume() throws {
        let parent = try makeTemporaryDirectory()
        let folderNFD = "\u{1111}\u{1169}\u{11AF}\u{1103}\u{1165}"
        let nestedFolderNFD = "\u{1102}\u{1162}\u{1107}\u{116E}"
        let fileNFD = "\u{1112}\u{1161}\u{11AB}.txt"
        let standaloneNFD = "\u{1106}\u{1166}\u{1106}\u{1169}.txt"
        let folder = parent.appendingPathComponent(folderNFD)
        let nestedFolder = folder.appendingPathComponent(nestedFolderNFD)
        try FileManager.default.createDirectory(at: nestedFolder, withIntermediateDirectories: true)
        let nestedContents = Data("nested byte-preserving payload".utf8)
        let standaloneContents = Data("standalone byte-preserving payload".utf8)
        try nestedContents.write(to: nestedFolder.appendingPathComponent(fileNFD))
        let standalone = parent.appendingPathComponent(standaloneNFD)
        try standaloneContents.write(to: standalone)

        let scan = FileTreeScanner().scan(roots: [folder, standalone])
        let plan = RenamePlanner().makePlan(from: scan)
        let result = RenameExecutor().execute(plan: plan)

        XCTAssertEqual(result.items.filter { $0.status == .renamed }.count, 4)
        XCTAssertEqual(result.items.filter { $0.status == .error }.count, 0)
        assertDirectory(
            parent,
            contains: "폴더",
            excludes: folderNFD
        )
        let finalFolder = parent.appendingPathComponent("폴더")
        assertDirectory(
            finalFolder,
            contains: "내부",
            excludes: nestedFolderNFD
        )
        let finalNestedFolder = finalFolder.appendingPathComponent("내부")
        assertDirectory(
            finalNestedFolder,
            contains: "한.txt",
            excludes: fileNFD
        )
        assertDirectory(
            parent,
            contains: "메모.txt",
            excludes: standaloneNFD
        )
        XCTAssertEqual(
            try Data(contentsOf: finalNestedFolder.appendingPathComponent("한.txt")),
            nestedContents
        )
        XCTAssertEqual(try Data(contentsOf: parent.appendingPathComponent("메모.txt")), standaloneContents)

        for directory in [parent, finalFolder, finalNestedFolder] {
            let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            XCTAssertTrue(names.allSatisfy { $0 == $0.precomposedStringWithCanonicalMapping })
        }
    }

    func testExecutorIgnoresFalseTwoStepCompatibilityFlag() throws {
        let parent = try makeTemporaryDirectory()
        let nfd = "\u{1112}\u{1161}\u{11AB}.txt"
        let source = parent.appendingPathComponent(nfd)
        try Data("payload".utf8).write(to: source)
        let planned = makePlan(roots: [source])
        let operations = planned.operations.map {
            RenameOperation(
                id: $0.id,
                itemID: $0.itemID,
                sourceURL: $0.sourceURL,
                destinationURL: $0.destinationURL,
                originalRelativePath: $0.originalRelativePath,
                depth: $0.depth,
                requiresTwoStepRename: false
            )
        }
        let plan = RenamePlan(
            items: planned.items,
            operations: operations,
            summary: planned.summary,
            rootURLs: planned.rootURLs
        )

        let result = RenameExecutor().execute(plan: plan)

        XCTAssertEqual(result.items.first?.status, .renamed)
        let names = try onDiskNames(in: parent)
        XCTAssertTrue(names.contains(Array("한.txt".utf8)))
        XCTAssertFalse(names.contains(Array(nfd.utf8)))
    }

    private func assertDirectory(
        _ directory: URL,
        contains normalizedName: String,
        excludes originalName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            let names = try onDiskNames(in: directory)
            XCTAssertTrue(names.contains(Array(normalizedName.utf8)), file: file, line: line)
            XCTAssertFalse(names.contains(Array(originalName.utf8)), file: file, line: line)
        } catch {
            XCTFail("디렉터리 이름을 읽지 못했습니다: \(error)", file: file, line: line)
        }
    }

    private func makePlan(roots: [URL]) -> RenamePlan {
        let scan = FileTreeScanner().scan(roots: roots)
        return RenamePlanner().makePlan(from: scan)
    }
}
