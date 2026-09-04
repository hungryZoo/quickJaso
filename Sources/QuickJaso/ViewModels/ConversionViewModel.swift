import AppKit
import Foundation
import QuickJasoCore
import SwiftUI

@MainActor
final class ConversionViewModel: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastReport: InspectionReport?
    @Published private(set) var lastOperationRecord: OperationRecord?

    private let pipeline: ConversionPipeline

    init(pipeline: ConversionPipeline = ConversionPipeline()) {
        self.pipeline = pipeline
    }

    func convert(urls: [URL], options: ScanOptions, settings: AppSettings) async -> InspectionReport? {
        isRunning = true
        lastOperationRecord = nil
        defer { isRunning = false }

        let start = Date()
        let pipeline = self.pipeline
        let planned = await Task.detached(priority: .userInitiated) {
            pipeline.plan(urls: urls, options: options)
        }.value
        let plan = planned.0
        let risk = planned.1

        if plan.summary.needsRename == 0 && plan.summary.problems == 0 {
            let report = InspectionReport(
                mode: .conversion,
                items: plan.items,
                summary: plan.summary,
                rootURLs: plan.rootURLs,
                duration: Date().timeIntervalSince(start),
                risk: risk
            )
            lastReport = report
            return report
        }

        if !settings.skipConversionConfirmation, !confirmConversion(settings: settings) {
            return nil
        }

        if risk.isRisky, !confirmRisk(risk) {
            return nil
        }

        let executed = await Task.detached(priority: .userInitiated) {
            pipeline.execute(plan: plan)
        }.value
        let report = InspectionReport(
            id: executed.id,
            mode: .conversion,
            createdAt: executed.createdAt,
            items: executed.items,
            summary: executed.summary,
            rootURLs: executed.rootURLs,
            duration: Date().timeIntervalSince(start),
            risk: risk
        )
        lastOperationRecord = operationRecord(from: report)
        lastReport = report
        return report
    }

    private func confirmConversion(settings: AppSettings) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Windows 호환 파일명으로 변환할까요?"
        alert.informativeText = [
            "선택한 항목에서 NFC가 아닌 파일 및 폴더 이름만 NFC로 변경합니다.",
            "파일 내용은 변경하지 않습니다.",
            "이름 충돌, 권한 오류, 동기화 중인 항목은 자동으로 건너뜁니다."
        ].joined(separator: "\n")
        alert.addButton(withTitle: "변환")
        alert.addButton(withTitle: "취소")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "앞으로 묻지 않기"

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        NSLog("quickJaso: confirmation response=%ld", response.rawValue)
        if response == .alertFirstButtonReturn,
           alert.suppressionButton?.state == .on {
            settings.skipConversionConfirmation = true
        }
        return response == .alertFirstButtonReturn
    }

    private func confirmRisk(_ risk: RiskAssessment) -> Bool {
        let content = RiskConfirmationView(
            risk: risk,
            onCancel: { NSApp.abortModal() },
            onContinue: { NSApp.stopModal(withCode: .OK) }
        )
        let controller = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: controller)
        window.title = "변환 전 미리보기"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 520, height: 430))
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        let response = NSApp.runModal(for: window)
        NSLog("quickJaso: risk confirmation response=%ld", response.rawValue)
        window.orderOut(nil)
        return response == .OK
    }

    private func operationRecord(from report: InspectionReport) -> OperationRecord? {
        let records = report.items.compactMap { item -> RenameRecord? in
            guard item.status == .renamed, let destination = item.resultingURL else { return nil }
            return RenameRecord(
                sourceURL: item.originalURL,
                destinationURL: destination,
                resourceIdentifier: item.resourceIdentifier
            )
        }
        return records.isEmpty ? nil : OperationRecord(renames: records)
    }
}
