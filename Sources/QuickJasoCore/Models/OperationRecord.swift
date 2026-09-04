import Foundation

public struct RenameRecord: Codable, Hashable, Sendable {
    public let sourceURL: URL
    public let destinationURL: URL
    public let resourceIdentifier: Data?

    public init(sourceURL: URL, destinationURL: URL, resourceIdentifier: Data? = nil) {
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.resourceIdentifier = resourceIdentifier
    }
}

public struct OperationRecord: Codable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let renames: [RenameRecord]

    public init(id: UUID = UUID(), date: Date = Date(), renames: [RenameRecord]) {
        self.id = id
        self.date = date
        self.renames = renames
    }

    // TODO: Undo should verify identity and destination availability before reversing records.
}

public struct ExecutionResult: Sendable {
    public let items: [FilenameInspectionItem]
    public let record: OperationRecord

    public init(items: [FilenameInspectionItem], record: OperationRecord) {
        self.items = items
        self.record = record
    }
}
