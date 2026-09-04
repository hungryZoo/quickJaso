import Foundation

public struct InspectionSummary: Codable, Hashable, Sendable {
    public var total: Int
    public var alreadyNFC: Int
    public var needsRename: Int
    public var renamed: Int
    public var collisions: Int
    public var skipped: Int
    public var inaccessible: Int
    public var errors: Int

    public var problems: Int { collisions + inaccessible + errors }

    public init(
        total: Int = 0,
        alreadyNFC: Int = 0,
        needsRename: Int = 0,
        renamed: Int = 0,
        collisions: Int = 0,
        skipped: Int = 0,
        inaccessible: Int = 0,
        errors: Int = 0
    ) {
        self.total = total
        self.alreadyNFC = alreadyNFC
        self.needsRename = needsRename
        self.renamed = renamed
        self.collisions = collisions
        self.skipped = skipped
        self.inaccessible = inaccessible
        self.errors = errors
    }

    public init(items: [FilenameInspectionItem]) {
        self.init(total: items.count)
        for item in items {
            switch item.status {
            case .alreadyNFC: alreadyNFC += 1
            case .needsRename: needsRename += 1
            case .renamed: renamed += 1
            case .collision: collisions += 1
            case .skipped: skipped += 1
            case .inaccessible: inaccessible += 1
            case .error: errors += 1
            }
        }
    }
}
