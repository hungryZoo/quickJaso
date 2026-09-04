import Foundation

public struct RenameOperation: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let itemID: UUID
    public let sourceURL: URL
    public let destinationURL: URL
    public let originalRelativePath: String
    public let depth: Int
    public let requiresTwoStepRename: Bool

    public init(
        id: UUID = UUID(),
        itemID: UUID,
        sourceURL: URL,
        destinationURL: URL,
        originalRelativePath: String,
        depth: Int,
        requiresTwoStepRename: Bool
    ) {
        self.id = id
        self.itemID = itemID
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.originalRelativePath = originalRelativePath
        self.depth = depth
        self.requiresTwoStepRename = requiresTwoStepRename
    }
}
