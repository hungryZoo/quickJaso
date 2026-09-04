import Foundation

public struct CollisionDetector {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func detect(
        items: [FilenameInspectionItem],
        listings: [URL: Set<String>]
    ) -> [FilenameInspectionItem] {
        var result = items
        let candidateIndexes = result.indices.filter { result[$0].status == .needsRename }

        var convergenceGroups: [CollisionKey: [Int]] = [:]
        for index in candidateIndexes {
            let item = result[index]
            let key = CollisionKey(parent: item.parentURL, normalizedName: item.normalizedNFCName)
            convergenceGroups[key, default: []].append(index)
        }
        for indexes in convergenceGroups.values where indexes.count > 1 {
            for index in indexes {
                markCollision(&result[index], "여러 항목이 같은 NFC 이름으로 변환됩니다")
            }
        }

        for index in candidateIndexes where result[index].status == .needsRename {
            let item = result[index]
            let siblingNames = listings[item.parentURL.standardizedFileURL] ?? []
            let scannedSiblingExists = result.contains { sibling in
                sibling.id != item.id &&
                    sibling.parentURL.standardizedFileURL == item.parentURL.standardizedFileURL &&
                    bytesEqual(sibling.originalName, item.normalizedNFCName)
            }
            let listedSiblingExists = siblingNames.contains { sibling in
                bytesEqual(sibling, item.normalizedNFCName) && !bytesEqual(sibling, item.originalName)
            }
            let onDiskSiblingExists = rawNames(in: item.parentURL).contains { sibling in
                bytesEqual(sibling, item.normalizedNFCName) && !bytesEqual(sibling, item.originalName)
            }
            if scannedSiblingExists || listedSiblingExists || onDiskSiblingExists {
                markCollision(&result[index], "같은 이름의 다른 항목이 이미 존재합니다")
                continue
            }

            let destination = item.parentURL.appendingPathComponent(
                item.normalizedNFCName,
                isDirectory: item.kind == .directory || item.kind == .package
            )
            guard fileManager.fileExists(atPath: destination.path) else { continue }

            let sourceIdentifier = FileAccessService.opaqueResourceIdentifier(of: item.originalURL)
            let destinationIdentifier = FileAccessService.opaqueResourceIdentifier(of: destination)
            if let sourceIdentifier, let destinationIdentifier {
                if !FileAccessService.identifiersEqual(sourceIdentifier, destinationIdentifier) {
                    markCollision(&result[index], "같은 이름의 다른 항목이 이미 존재합니다")
                }
                // Same identity is safe and RenamePlanner will request a two-step rename.
            } else {
                markCollision(&result[index], "목적지 존재 여부를 안전하게 판단할 수 없습니다")
            }
        }

        return result
    }

    public func requiresTwoStepRename(for item: FilenameInspectionItem) -> Bool {
        guard item.status == .needsRename,
              let destination = item.plannedDestinationURL,
              fileManager.fileExists(atPath: destination.path),
              let sourceIdentifier = FileAccessService.opaqueResourceIdentifier(of: item.originalURL),
              let destinationIdentifier = FileAccessService.opaqueResourceIdentifier(of: destination) else {
            return false
        }
        return FileAccessService.identifiersEqual(sourceIdentifier, destinationIdentifier)
    }

    private func markCollision(_ item: inout FilenameInspectionItem, _ message: String) {
        item.status = .collision
        item.message = message
    }

    private func bytesEqual(_ lhs: String, _ rhs: String) -> Bool {
        Array(lhs.utf8) == Array(rhs.utf8)
    }

    private func rawNames(in directory: URL) -> [String] {
        do {
            return try fileManager.contentsOfDirectory(atPath: directory.path)
        } catch {
            // Destination identity checks below remain the fail-safe when relisting fails.
            return []
        }
    }

    private struct CollisionKey: Hashable {
        let parentPath: String
        let normalizedBytes: Data

        init(parent: URL, normalizedName: String) {
            parentPath = parent.standardizedFileURL.path
            normalizedBytes = Data(normalizedName.utf8)
        }
    }
}
