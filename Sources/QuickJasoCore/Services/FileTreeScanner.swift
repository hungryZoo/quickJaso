import Foundation

public struct FileTreeScanner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func scan(roots: [URL], options: ScanOptions = .default) -> ScanResult {
        var items: [FilenameInspectionItem] = []
        var listings: [URL: Set<String>] = [:]

        for root in roots {
            let standardizedRoot = root.standardizedFileURL
            let parent = standardizedRoot.deletingLastPathComponent().standardizedFileURL
            captureListing(of: parent, into: &listings)

            guard fileManager.fileExists(atPath: standardizedRoot.path) else {
                let name = standardizedRoot.lastPathComponent
                items.append(FilenameInspectionItem(
                    originalURL: standardizedRoot,
                    originalRelativePath: name,
                    originalName: name,
                    normalizedNFCName: FilenameNormalizer.normalizedNFC(name),
                    kind: .unknown,
                    status: .inaccessible,
                    message: "항목을 찾을 수 없습니다",
                    depth: 0,
                    parentURL: parent,
                    isRoot: true
                ))
                continue
            }

            scanItem(
                standardizedRoot,
                parentURL: parent,
                depth: 0,
                isRoot: true,
                ancestorRelativePath: nil,
                options: options,
                items: &items,
                listings: &listings
            )
        }

        return ScanResult(
            items: items,
            directoryListings: listings,
            rootURLs: roots.map(\.standardizedFileURL)
        )
    }

    private func scanItem(
        _ url: URL,
        parentURL: URL,
        depth: Int,
        isRoot: Bool,
        ancestorRelativePath: String?,
        options: ScanOptions,
        items: inout [FilenameInspectionItem],
        listings: inout [URL: Set<String>]
    ) {
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey, .isSymbolicLinkKey, .isPackageKey, .isHiddenKey,
            .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey,
            .fileResourceIdentifierKey, .volumeIsReadOnlyKey, .isWritableKey,
            .nameKey
        ]

        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: keys)
        } catch {
            items.append(makeItem(
                url: url,
                parentURL: parentURL,
                depth: depth,
                isRoot: isRoot,
                ancestorRelativePath: ancestorRelativePath,
                kind: .unknown,
                status: .inaccessible,
                message: error.localizedDescription,
                resourceIdentifier: nil
            ))
            return
        }

        let parent = isRoot ? parentURL.standardizedFileURL : parentURL
        let resolvedName = resolveOnDiskName(
            for: url,
            parent: parent,
            values: values
        )
        let name = resolvedName.name
        if options.skipSystemFiles && Self.systemFileNames.contains(name) {
            return
        }

        if !options.includeHidden && values.isHidden == true {
            return
        }

        let isSymlink = values.isSymbolicLink == true
        let isDirectory = values.isDirectory == true
        let originalURL = rebuildURL(parent: parent, name: name, isDirectory: isDirectory)
        let relativePath = ancestorRelativePath.map { "\($0)/\(name)" } ?? name
        let isPackage = !isSymlink && isDirectory && (
            values.isPackage == true || Self.packageExtensions.contains(originalURL.pathExtension.lowercased())
        )
        let kind: FileItemKind = isSymlink ? .symlink : (isPackage ? .package : (isDirectory ? .directory : .file))
        let normalized = FilenameNormalizer.normalizedNFC(name)
        let needsRename = !FilenameNormalizer.isNFC(name)
        var status = FilenameNormalizer.classify(name)
        var message: String?

        if !resolvedName.isVerified {
            status = .skipped
            message = "디스크상의 실제 이름을 확인할 수 없습니다"
        } else if isSymlink && needsRename && !options.renameSymlinkItself {
            status = .skipped
            message = "심볼릭 링크 이름은 설정에서 켠 경우에만 변환합니다"
        } else if values.isUbiquitousItem == true,
                  values.ubiquitousItemDownloadingStatus != .current {
            status = .skipped
            message = "확인 불가 — 먼저 다운로드 필요"
        } else if needsRename && values.volumeIsReadOnly == true {
            status = .inaccessible
            message = "읽기 전용 볼륨"
        } else if needsRename && !fileManager.isWritableFile(atPath: parent.path) {
            status = .inaccessible
            message = "부모 폴더에 쓰기 권한 없음"
        }

        let identifier = FileAccessService.dataRepresentation(of: values.fileResourceIdentifier)
        let itemIndex = items.count
        items.append(FilenameInspectionItem(
            originalURL: originalURL,
            originalRelativePath: relativePath,
            originalName: name,
            normalizedNFCName: normalized,
            kind: kind,
            status: status,
            message: message,
            depth: depth,
            resourceIdentifier: identifier,
            parentURL: parent,
            isRoot: isRoot
        ))

        guard isDirectory, !isSymlink, (!isPackage || options.recurseIntoPackages) else {
            return
        }

        let children: [URL]
        do {
            children = try fileManager.contentsOfDirectory(
                at: originalURL,
                includingPropertiesForKeys: Array(keys),
                options: []
            )
        } catch {
            items[itemIndex].status = .inaccessible
            items[itemIndex].message = error.localizedDescription
            return
        }

        let childNames = (try? fileManager.contentsOfDirectory(atPath: originalURL.path))
            ?? children.compactMap { try? $0.resourceValues(forKeys: [.nameKey]).name }
        listings[originalURL.standardizedFileURL] = Set(childNames)
        for child in children.sorted(by: { childURLName($0).utf8.lexicographicallyPrecedes(childURLName($1).utf8) }) {
            scanItem(
                child,
                parentURL: originalURL,
                depth: depth + 1,
                isRoot: false,
                ancestorRelativePath: relativePath,
                options: options,
                items: &items,
                listings: &listings
            )
        }
    }

    private func captureListing(of directory: URL, into listings: inout [URL: Set<String>]) {
        do {
            listings[directory.standardizedFileURL] = Set(
                try fileManager.contentsOfDirectory(atPath: directory.path)
            )
        } catch {
            // A missing parent listing is handled later by destination identity checks.
            listings[directory.standardizedFileURL] = []
        }
    }

    private func resolveOnDiskName(
        for url: URL,
        parent: URL,
        values: URLResourceValues
    ) -> (name: String, isVerified: Bool) {
        let urlName = url.lastPathComponent
        let resourceIdentifier = values.fileResourceIdentifier
        let canonicalURLName = urlName.precomposedStringWithCanonicalMapping
        let matchingNames: [String]

        if let resourceIdentifier,
           let names = try? fileManager.contentsOfDirectory(atPath: parent.path) {
            matchingNames = names.filter { candidate in
                guard candidate.precomposedStringWithCanonicalMapping == canonicalURLName else {
                    return false
                }
                let candidateURL = rebuildURL(parent: parent, name: candidate, isDirectory: false)
                guard let candidateIdentifier = FileAccessService.opaqueResourceIdentifier(of: candidateURL) else {
                    return false
                }
                return FileAccessService.identifiersEqual(resourceIdentifier, candidateIdentifier)
            }
        } else {
            matchingNames = []
        }

        if matchingNames.count == 1, let matchedName = matchingNames.first {
            return (matchedName, true)
        }
        if let resourceName = values.name {
            return (resourceName, true)
        }
        return (urlName, false)
    }

    private func childURLName(_ url: URL) -> String {
        (try? url.resourceValues(forKeys: [.nameKey]).name) ?? url.lastPathComponent
    }

    private func rebuildURL(parent: URL, name: String, isDirectory: Bool) -> URL {
        let appended = parent.appendingPathComponent(name, isDirectory: isDirectory)
        guard Array(appended.lastPathComponent.utf8) != Array(name.utf8) else {
            return appended
        }

        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/%?#")
        guard let encodedName = name.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return appended
        }
        let base = parent.absoluteString.hasSuffix("/")
            ? parent.absoluteString
            : parent.absoluteString + "/"
        return URL(string: base + encodedName + (isDirectory ? "/" : "")) ?? appended
    }

    private func makeItem(
        url: URL,
        parentURL: URL,
        depth: Int,
        isRoot: Bool,
        ancestorRelativePath: String?,
        kind: FileItemKind,
        status: NormalizationStatus,
        message: String?,
        resourceIdentifier: Data?
    ) -> FilenameInspectionItem {
        let name = url.lastPathComponent
        let parent = isRoot ? parentURL.standardizedFileURL : parentURL
        return FilenameInspectionItem(
            originalURL: url,
            originalRelativePath: ancestorRelativePath.map { "\($0)/\(name)" } ?? name,
            originalName: name,
            normalizedNFCName: FilenameNormalizer.normalizedNFC(name),
            kind: kind,
            status: status,
            message: message,
            depth: depth,
            resourceIdentifier: resourceIdentifier,
            parentURL: parent,
            isRoot: isRoot
        )
    }

    private static let systemFileNames: Set<String> = [
        ".DS_Store", ".localized", "Icon\r", ".Spotlight-V100", ".Trashes",
        ".fseventsd", ".TemporaryItems", ".DocumentRevisions-V100"
    ]

    private static let packageExtensions: Set<String> = [
        "app", "bundle", "framework", "photoslibrary", "xcodeproj", "xcworkspace",
        "playground", "pkg", "kext", "plugin", "prefpane", "qlgenerator", "mlmodelc",
        "docset", "scptd", "rtfd", "key", "pages", "numbers"
    ]
}
