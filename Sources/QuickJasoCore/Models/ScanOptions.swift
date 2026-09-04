import Foundation

public struct ScanOptions: Codable, Hashable, Sendable {
    public var followSymlinks: Bool
    public var renameSymlinkItself: Bool
    public var recurseIntoPackages: Bool
    public var includeHidden: Bool
    public var skipSystemFiles: Bool

    public init(
        followSymlinks: Bool = false,
        renameSymlinkItself: Bool = false,
        recurseIntoPackages: Bool = false,
        includeHidden: Bool = true,
        skipSystemFiles: Bool = true
    ) {
        self.followSymlinks = followSymlinks
        self.renameSymlinkItself = renameSymlinkItself
        self.recurseIntoPackages = recurseIntoPackages
        self.includeHidden = includeHidden
        self.skipSystemFiles = skipSystemFiles
    }

    public static let `default` = ScanOptions()
}
