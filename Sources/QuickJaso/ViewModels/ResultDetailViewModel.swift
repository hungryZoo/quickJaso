import AppKit
import Foundation
import QuickJasoCore
import UniformTypeIdentifiers

enum StatusFilter: String, CaseIterable, Identifiable {
    case all
    case renamed
    case alreadyNFC
    case needsRename
    case collision
    case problem

    var id: String { rawValue }

    var koreanLabel: String {
        switch self {
        case .all: return "전체"
        case .renamed: return "변환됨"
        case .alreadyNFC: return "이미 NFC"
        case .needsRename: return "NFC 변환 필요"
        case .collision: return "이름 충돌"
        case .problem: return "오류·확인 불가"
        }
    }

    func includes(_ status: NormalizationStatus) -> Bool {
        switch self {
        case .all: return true
        case .renamed: return status == .renamed
        case .alreadyNFC: return status == .alreadyNFC
        case .needsRename: return status == .needsRename
        case .collision: return status == .collision
        case .problem: return status == .skipped || status == .inaccessible || status == .error
        }
    }
}

@MainActor
final class ResultDetailViewModel: ObservableObject {
    @Published private(set) var report: InspectionReport?
    @Published var filter: StatusFilter = .all
    @Published var searchText = ""
    @Published var selection: Set<UUID> = []

    private let exporter = ResultReportExporter()

    var filteredItems: [FilenameInspectionItem] {
        guard let report else { return [] }
        return report.items.filter { item in
            guard filter.includes(item.status) else { return false }
            guard !searchText.isEmpty else { return true }
            return item.originalRelativePath.localizedCaseInsensitiveContains(searchText)
                || relativeResultPath(for: item).localizedCaseInsensitiveContains(searchText)
                || item.status.koreanLabel.localizedCaseInsensitiveContains(searchText)
                || (item.message?.localizedCaseInsensitiveContains(searchText) == true)
        }
    }

    var selectedItems: [FilenameInspectionItem] {
        filteredItems.filter { selection.contains($0.id) }
    }

    func configure(report: InspectionReport, filter: StatusFilter) {
        self.report = report
        self.filter = filter
        searchText = ""
        selection = []
    }

    func revealInFinder(_ item: FilenameInspectionItem) {
        let candidate = item.resultingURL ?? item.originalURL
        if FileManager.default.fileExists(atPath: candidate.path) {
            NSWorkspace.shared.activateFileViewerSelecting([candidate])
        } else {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: candidate.deletingLastPathComponent().path)
        }
    }

    func revealSelection() {
        let urls = selectedItems.compactMap { item -> URL? in
            let candidate = item.resultingURL ?? item.originalURL
            return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
        }
        if !urls.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        } else if let item = selectedItems.first {
            revealInFinder(item)
        }
    }

    func copyChangeLog() {
        guard let report else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let wrote = pasteboard.setString(exporter.humanReadableText(report: report), forType: .string)
        if !wrote {
            NSLog("quickJaso: 변경 내역을 클립보드에 쓰지 못했습니다.")
        }
    }

    func exportCSV() {
        guard let report else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "quickJaso-결과-\(Self.exportDateFormatter.string(from: Date())).csv"
        panel.prompt = "내보내기"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let contents = "\u{FEFF}" + exporter.csv(report: report)
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "CSV를 저장할 수 없습니다."
            alert.runModal()
        }
    }

    func relativeResultPath(for item: FilenameInspectionItem) -> String {
        guard let finalURL = item.resultingURL ?? item.plannedDestinationURL else { return "" }
        let componentCount = item.originalRelativePath.split(separator: "/").count
        var rootParent = item.originalURL
        for _ in 0..<componentCount {
            rootParent.deleteLastPathComponent()
        }
        let parentPath = rootParent.standardizedFileURL.path
        let finalPath = finalURL.standardizedFileURL.path
        let prefix = parentPath.hasSuffix("/") ? parentPath : parentPath + "/"
        return finalPath.hasPrefix(prefix) ? String(finalPath.dropFirst(prefix.count)) : finalURL.lastPathComponent
    }

    private static let exportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter
    }()
}
