import Foundation

public struct RenamePlanner {
    private let collisionDetector: CollisionDetector

    public init(collisionDetector: CollisionDetector = CollisionDetector()) {
        self.collisionDetector = collisionDetector
    }

    public func makePlan(from scan: ScanResult, options: ScanOptions = .default) -> RenamePlan {
        var items = scan.items
        for index in items.indices where items[index].status == .needsRename {
            let item = items[index]
            items[index].plannedDestinationURL = item.parentURL.appendingPathComponent(
                item.normalizedNFCName,
                isDirectory: item.kind == .directory || item.kind == .package
            )
        }

        items = collisionDetector.detect(items: items, listings: scan.directoryListings)
        let operations = items.compactMap { item -> RenameOperation? in
            guard item.status == .needsRename, let destination = item.plannedDestinationURL else {
                return nil
            }
            return RenameOperation(
                itemID: item.id,
                sourceURL: item.originalURL,
                destinationURL: destination,
                originalRelativePath: item.originalRelativePath,
                depth: item.depth,
                requiresTwoStepRename: collisionDetector.requiresTwoStepRename(for: item)
            )
        }.sorted {
            if $0.depth != $1.depth { return $0.depth > $1.depth }
            return $0.originalRelativePath.utf8.lexicographicallyPrecedes($1.originalRelativePath.utf8)
        }

        return RenamePlan(
            items: items,
            operations: operations,
            summary: InspectionSummary(items: items),
            rootURLs: scan.rootURLs
        )
    }
}
