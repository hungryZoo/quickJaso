import Darwin
import Foundation
import XCTest

class TemporaryDirectoryTestCase: XCTestCase {
    private var temporaryDirectories: [URL] = []

    func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        temporaryDirectories.append(url)
        return url
    }

    override func tearDownWithError() throws {
        for url in temporaryDirectories {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o700],
                    ofItemAtPath: url.path
                )
                try FileManager.default.removeItem(at: url)
            }
        }
        temporaryDirectories.removeAll()
        try super.tearDownWithError()
    }
}

func bytesEqual(_ lhs: String, _ rhs: String) -> Bool {
    Array(lhs.utf8) == Array(rhs.utf8)
}

func onDiskNames(in directory: URL) throws -> [[UInt8]] {
    try FileManager.default.contentsOfDirectory(atPath: directory.path).map { Array($0.utf8) }
}

func writeRawNamedFile(in directory: URL, name: String, contents: Data = Data()) throws {
    let temporary = directory.appendingPathComponent(".raw-name-fixture-\(UUID().uuidString)")
    try contents.write(to: temporary)
    do {
        try renameFixture(from: temporary, toRawName: name, in: directory)
    } catch {
        try? FileManager.default.removeItem(at: temporary)
        throw error
    }
}

func createRawNamedDirectory(in directory: URL, name: String) throws -> URL {
    let temporary = directory.appendingPathComponent(".raw-name-fixture-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false)
    do {
        try renameFixture(from: temporary, toRawName: name, in: directory)
    } catch {
        try? FileManager.default.removeItem(at: temporary)
        throw error
    }
    return directory.appendingPathComponent(name, isDirectory: true)
}

private func renameFixture(from source: URL, toRawName name: String, in directory: URL) throws {
    let destinationPath = directory.path.hasSuffix("/")
        ? directory.path + name
        : directory.path + "/" + name
    let result = source.path.withCString { sourcePath in
        destinationPath.withCString { destination in
            renamex_np(sourcePath, destination, UInt32(RENAME_EXCL))
        }
    }
    guard result == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
}
