import Darwin
import Foundation

public struct RenameExecutor {
    public init() {}

    public func execute(
        plan: RenamePlan,
        fileManager: FileManager = .default,
        progress: ((Int, Int) -> Void)? = nil
    ) -> ExecutionResult {
        var items = plan.items
        var records: [RenameRecord] = []
        let total = plan.operations.count

        for (offset, operation) in plan.operations.enumerated() {
            guard let itemIndex = items.firstIndex(where: { $0.id == operation.itemID }) else {
                progress?(offset + 1, total)
                continue
            }

            let parent = operation.sourceURL.deletingLastPathComponent()
            FileAccessService.withSecurityScopedAccess(parent) {
                executeOne(
                    operation,
                    itemIndex: itemIndex,
                    items: &items,
                    records: &records,
                    fileManager: fileManager
                )
            }
            progress?(offset + 1, total)
        }

        return ExecutionResult(
            items: items,
            record: OperationRecord(renames: records)
        )
    }

    private func executeOne(
        _ operation: RenameOperation,
        itemIndex: Int,
        items: inout [FilenameInspectionItem],
        records: inout [RenameRecord],
        fileManager: FileManager
    ) {
        guard fileManager.fileExists(atPath: operation.sourceURL.path) else {
            setError(&items[itemIndex], "계획 이후 외부에서 변경됨")
            return
        }

        if let plannedIdentifier = items[itemIndex].resourceIdentifier {
            guard let currentIdentifier = FileAccessService.resourceIdentifier(of: operation.sourceURL),
                  currentIdentifier == plannedIdentifier else {
                setError(&items[itemIndex], "계획 이후 외부에서 변경됨")
                return
            }
        }

        do {
            try executeTwoStep(
                operation,
                originalName: items[itemIndex].originalName,
                normalizedName: items[itemIndex].normalizedNFCName,
                fileManager: fileManager
            )
            items[itemIndex].status = .renamed
            items[itemIndex].message = nil
            items[itemIndex].resultingURL = operation.destinationURL
            records.append(RenameRecord(
                sourceURL: operation.sourceURL,
                destinationURL: operation.destinationURL,
                resourceIdentifier: items[itemIndex].resourceIdentifier
            ))
            if items[itemIndex].kind == .directory || items[itemIndex].kind == .package {
                updateDescendantResultURLs(
                    in: &items,
                    renamedItemID: items[itemIndex].id,
                    from: operation.sourceURL,
                    to: operation.destinationURL
                )
            }
        } catch RenameExecutionError.destinationAppeared {
            items[itemIndex].status = .collision
            items[itemIndex].message = "같은 이름의 다른 항목이 이미 존재합니다"
        } catch {
            setError(&items[itemIndex], error.localizedDescription)
        }
    }

    private func executeTwoStep(
        _ operation: RenameOperation,
        originalName: String,
        normalizedName: String,
        fileManager: FileManager
    ) throws {
        let parent = operation.sourceURL.deletingLastPathComponent()
        let existingNames = try fileManager.contentsOfDirectory(atPath: parent.path)
        var temporaryURL: URL
        repeat {
            temporaryURL = parent.appendingPathComponent(".quickjaso-tmp-\(UUID().uuidString)")
        } while fileManager.fileExists(atPath: temporaryURL.path)
            || existingNames.contains { bytesEqual($0, temporaryURL.lastPathComponent) }

        try fileManager.moveItem(at: operation.sourceURL, to: temporaryURL)

        let namesBeforeFinalMove: [String]
        do {
            namesBeforeFinalMove = try fileManager.contentsOfDirectory(atPath: parent.path)
        } catch {
            do {
                try fileManager.moveItem(at: temporaryURL, to: operation.sourceURL)
            } catch {
                throw RenameExecutionError.stepTwoAndRollbackFailed
            }
            throw error
        }

        if namesBeforeFinalMove.contains(where: { bytesEqual($0, normalizedName) }) {
            do {
                try fileManager.moveItem(at: temporaryURL, to: operation.sourceURL)
            } catch {
                throw RenameExecutionError.stepTwoAndRollbackFailed
            }
            throw RenameExecutionError.destinationAppeared
        }

        do {
            try moveWithoutOverwriting(
                fromPath: temporaryURL.path,
                toPath: rawChildPath(parent: parent, name: normalizedName)
            )
        } catch {
            do {
                try fileManager.moveItem(at: temporaryURL, to: operation.sourceURL)
            } catch {
                throw RenameExecutionError.stepTwoAndRollbackFailed
            }
            throw error
        }

        guard let finalNames = try? fileManager.contentsOfDirectory(atPath: parent.path),
              finalNames.contains(where: { bytesEqual($0, normalizedName) }),
              !finalNames.contains(where: { bytesEqual($0, originalName) }) else {
            throw RenameExecutionError.postconditionFailed
        }
    }

    private func bytesEqual(_ lhs: String, _ rhs: String) -> Bool {
        Array(lhs.utf8) == Array(rhs.utf8)
    }

    private func rawChildPath(parent: URL, name: String) -> String {
        let parentPath = parent.path
        return parentPath.hasSuffix("/") ? parentPath + name : parentPath + "/" + name
    }

    private func moveWithoutOverwriting(fromPath: String, toPath: String) throws {
        let result = fromPath.withCString { source in
            toPath.withCString { destination in
                renamex_np(source, destination, UInt32(RENAME_EXCL))
            }
        }
        guard result == 0 else {
            let errorNumber = errno
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errorNumber))
        }
    }

    private func updateDescendantResultURLs(
        in items: inout [FilenameInspectionItem],
        renamedItemID: UUID,
        from source: URL,
        to destination: URL
    ) {
        let sourcePath = source.standardizedFileURL.path
        let sourcePrefix = sourcePath.hasSuffix("/") ? sourcePath : sourcePath + "/"
        for index in items.indices where items[index].id != renamedItemID {
            let currentURL = items[index].resultingURL ?? items[index].originalURL
            let currentPath = currentURL.standardizedFileURL.path
            guard currentPath.hasPrefix(sourcePrefix) else { continue }
            let suffix = String(currentPath.dropFirst(sourcePrefix.count))
            items[index].resultingURL = destination.appendingPathComponent(suffix)
        }
    }

    private func setError(_ item: inout FilenameInspectionItem, _ message: String) {
        item.status = .error
        item.message = message
    }

    private enum RenameExecutionError: LocalizedError {
        case destinationAppeared
        case stepTwoAndRollbackFailed
        case postconditionFailed

        var errorDescription: String? {
            switch self {
            case .destinationAppeared:
                return "같은 이름의 다른 항목이 이미 존재합니다"
            case .stepTwoAndRollbackFailed:
                return "2단계 이름 변경과 원래 이름 복구에 실패했습니다"
            case .postconditionFailed:
                return "이름 변경이 파일 시스템에 반영되지 않았습니다"
            }
        }
    }
}
