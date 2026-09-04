import Foundation

public struct FilenameInspectionItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let originalURL: URL
    public let originalRelativePath: String
    public let originalName: String
    public let normalizedNFCName: String
    public var plannedDestinationURL: URL?
    public var resultingURL: URL?
    public let kind: FileItemKind
    public var status: NormalizationStatus
    public var message: String?
    public var depth: Int
    public let resourceIdentifier: Data?
    public let parentURL: URL
    public let isRoot: Bool

    public init(
        id: UUID = UUID(),
        originalURL: URL,
        originalRelativePath: String,
        originalName: String,
        normalizedNFCName: String,
        plannedDestinationURL: URL? = nil,
        resultingURL: URL? = nil,
        kind: FileItemKind,
        status: NormalizationStatus,
        message: String? = nil,
        depth: Int,
        resourceIdentifier: Data? = nil,
        parentURL: URL,
        isRoot: Bool = false
    ) {
        self.id = id
        self.originalURL = originalURL
        self.originalRelativePath = originalRelativePath
        self.originalName = originalName
        self.normalizedNFCName = normalizedNFCName
        self.plannedDestinationURL = plannedDestinationURL
        self.resultingURL = resultingURL
        self.kind = kind
        self.status = status
        self.message = message
        self.depth = depth
        self.resourceIdentifier = resourceIdentifier
        self.parentURL = parentURL
        self.isRoot = isRoot
    }
}
