import Foundation

public struct ScanResult: Sendable, RandomAccessCollection {
    public typealias Index = Int
    public typealias Element = FilenameInspectionItem

    public var items: [FilenameInspectionItem]
    public var directoryListings: [URL: Set<String>]
    public var rootURLs: [URL]

    public init(
        items: [FilenameInspectionItem],
        directoryListings: [URL: Set<String>],
        rootURLs: [URL]? = nil
    ) {
        self.items = items
        self.directoryListings = directoryListings
        self.rootURLs = rootURLs ?? items.filter(\.isRoot).map(\.originalURL)
    }

    public var startIndex: Int { items.startIndex }
    public var endIndex: Int { items.endIndex }

    public subscript(position: Int) -> FilenameInspectionItem {
        items[position]
    }
}

public struct RenamePlan: Sendable {
    public let items: [FilenameInspectionItem]
    public let operations: [RenameOperation]
    public let summary: InspectionSummary
    public let rootURLs: [URL]

    public init(
        items: [FilenameInspectionItem],
        operations: [RenameOperation],
        summary: InspectionSummary,
        rootURLs: [URL]
    ) {
        self.items = items
        self.operations = operations
        self.summary = summary
        self.rootURLs = rootURLs
    }
}
