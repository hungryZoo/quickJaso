import Foundation

public struct GitRepositoryDetector {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func isInsideGitRepository(_ url: URL) -> Bool {
        var current = directoryForSearch(url).standardizedFileURL
        while true {
            if fileManager.fileExists(atPath: current.appendingPathComponent(".git").path) {
                return true
            }
            let parent = current.deletingLastPathComponent().standardizedFileURL
            if parent.path == current.path { return false }
            current = parent
        }
    }

    private func directoryForSearch(_ url: URL) -> URL {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return url
        }
        return url.deletingLastPathComponent()
    }
}
