import Foundation

public enum FileItemKind: String, Codable, CaseIterable, Sendable {
    case file
    case directory
    case symlink
    case package
    case unknown
}
