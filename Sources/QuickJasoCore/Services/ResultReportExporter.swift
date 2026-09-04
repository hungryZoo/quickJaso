import Foundation

public struct ResultReportExporter {
    public init() {}

    public func humanReadableText(report: InspectionReport) -> String {
        let summary = report.summary
        var lines = [
            report.mode == .inspection ? "Windows 호환성 검사 결과" : "Windows 호환 파일명 변환 결과",
            "총 \(summary.total)개 · 이미 NFC \(summary.alreadyNFC)개 · 변환 필요 \(summary.needsRename)개 · 변환됨 \(summary.renamed)개 · 충돌 \(summary.collisions)개 · 건너뜀 \(summary.skipped)개 · 접근 오류 \(summary.inaccessible)개 · 오류 \(summary.errors)개",
            ""
        ]
        lines.append(contentsOf: report.items.map { item in
            let resultPath = resultingRelativePath(for: item)
            let detail = item.message.map { " — \($0)" } ?? ""
            return "[\(item.status.koreanLabel)] \(item.originalRelativePath) → \(resultPath)\(detail)"
        })
        return lines.joined(separator: "\n")
    }

    public func csv(report: InspectionReport) -> String {
        var rows = [["결과", "원래 상대 경로", "변환 후 상대 경로", "상태", "상세 사유"]]
        rows.append(contentsOf: report.items.map { item in
            [
                item.status.koreanLabel,
                item.originalRelativePath,
                resultingRelativePath(for: item),
                item.status.rawValue,
                item.message ?? ""
            ]
        })
        return rows.map { $0.map(csvField).joined(separator: ",") }.joined(separator: "\r\n")
    }

    private func resultingRelativePath(for item: FilenameInspectionItem) -> String {
        guard let finalURL = item.resultingURL ?? item.plannedDestinationURL else {
            return item.originalRelativePath
        }
        let componentCount = item.originalRelativePath.split(separator: "/").count
        var rootParent = item.originalURL
        for _ in 0..<componentCount {
            rootParent.deleteLastPathComponent()
        }
        let parentPath = rootParent.standardizedFileURL.path
        let finalPath = finalURL.standardizedFileURL.path
        let prefix = parentPath.hasSuffix("/") ? parentPath : parentPath + "/"
        if finalPath.hasPrefix(prefix) {
            return String(finalPath.dropFirst(prefix.count))
        }
        return finalURL.lastPathComponent
    }

    private func csvField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
