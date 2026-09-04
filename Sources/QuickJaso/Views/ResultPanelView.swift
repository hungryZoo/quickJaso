import QuickJasoCore
import SwiftUI

struct ResultPanelView: View {
    let report: InspectionReport
    @ObservedObject var presentation: ResultPanelPresentation
    let onDetail: (StatusFilter) -> Void
    let onConvert: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                if report.mode == .inspection {
                    PanelResultLine(symbol: "checkmark.circle.fill", color: .green, label: "Windows 호환 (NFC): \(report.summary.alreadyNFC)개", accessibilityLabel: "Windows 호환 NFC \(report.summary.alreadyNFC)개")
                    PanelResultLine(symbol: "exclamationmark.triangle.fill", color: .orange, label: "NFC 변환 필요: \(report.summary.needsRename)개", accessibilityLabel: "NFC 변환 필요 \(report.summary.needsRename)개")
                    PanelResultLine(symbol: "xmark.octagon.fill", color: .red, label: "변환 불가: \(report.summary.problems)개", accessibilityLabel: "변환 불가 \(report.summary.problems)개")
                    PanelResultLine(symbol: "questionmark.circle", color: .secondary, label: "확인 불가: \(report.summary.skipped)개", accessibilityLabel: "확인 불가 \(report.summary.skipped)개")
                } else if isAllCompatible {
                    Text("검사한 \(report.summary.total)개 항목은 모두 NFC 형식입니다.")
                        .fixedSize(horizontal: false, vertical: true)
                } else if isConversionSuccess {
                    PanelResultLine(symbol: "checkmark.circle.fill", color: .green, label: "변환됨: \(report.summary.renamed)개", accessibilityLabel: "변환됨 \(report.summary.renamed)개")
                    PanelResultLine(symbol: "checkmark.circle.fill", color: .green, label: "이미 호환: \(report.summary.alreadyNFC)개", accessibilityLabel: "이미 호환 \(report.summary.alreadyNFC)개")
                    PanelResultLine(symbol: "minus.circle", color: .secondary, label: "건너뜀: 0개", accessibilityLabel: "건너뜀 0개")
                } else {
                    PanelResultLine(symbol: "checkmark.circle.fill", color: .green, label: "변환됨: \(report.summary.renamed)개", accessibilityLabel: "변환됨 \(report.summary.renamed)개")
                    PanelResultLine(symbol: "checkmark.circle.fill", color: .green, label: "이미 호환: \(report.summary.alreadyNFC)개", accessibilityLabel: "이미 호환 \(report.summary.alreadyNFC)개")
                    if report.summary.collisions > 0 {
                        PanelResultLine(symbol: "xmark.octagon.fill", color: .red, label: "이름 충돌: \(report.summary.collisions)개", accessibilityLabel: "이름 충돌 \(report.summary.collisions)개")
                    }
                    if accessProblemCount > 0 {
                        PanelResultLine(symbol: "xmark.octagon.fill", color: .red, label: "접근 오류: \(accessProblemCount)개", accessibilityLabel: "접근 오류 \(accessProblemCount)개")
                    }
                    if report.summary.skipped > 0 {
                        PanelResultLine(symbol: "questionmark.circle", color: .secondary, label: "확인 불가: \(report.summary.skipped)개", accessibilityLabel: "확인 불가 \(report.summary.skipped)개")
                    }
                }
            }

            if let explanation {
                Text(explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let remaining = presentation.remainingSeconds {
                Text("\(remaining)초 후 자동으로 닫힙니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if report.mode == .inspection {
                    Button("상세 보기") { interact { onDetail(.all) } }
                    if report.summary.needsRename > 0 {
                        Button("NFC로 변환…") { interact(action: onConvert) }
                    }
                } else if !isAllCompatible {
                    if !isConversionSuccess {
                        Button("문제 항목 보기") {
                            interact { onDetail(report.summary.collisions > 0 ? .collision : .problem) }
                        }
                    }
                    Button("변경 내역 보기") { interact { onDetail(.all) } }
                }
                Spacer()
                Button("닫기") { interact(action: onClose) }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(18)
        .frame(width: 360)
        .onHover { hovering in
            if hovering { presentation.cancelAutoClose() }
        }
    }

    private var isAllCompatible: Bool {
        report.summary.renamed == 0 && report.summary.problems == 0 && report.summary.skipped == 0
    }

    private var isConversionSuccess: Bool {
        report.summary.problems == 0 && report.summary.skipped == 0
    }

    private var accessProblemCount: Int {
        report.summary.inaccessible + report.summary.errors
    }

    private var title: String {
        if report.mode == .inspection { return "Windows 호환성 검사 완료" }
        if isAllCompatible { return "이미 Windows 호환 파일명입니다" }
        if isConversionSuccess { return "Windows 호환 파일명으로 변환 완료" }
        return "일부 항목만 변환했습니다"
    }

    private var explanation: String? {
        if report.mode == .inspection || isAllCompatible { return nil }
        if isConversionSuccess {
            return "선택한 파일 및 폴더 이름을 NFC 형식으로 정리했습니다."
        }
        return "충돌하거나 접근할 수 없는 항목은 변경하지 않았습니다."
    }

    private func interact(action: () -> Void) {
        presentation.cancelAutoClose()
        action()
    }
}

private struct PanelResultLine: View {
    let symbol: String
    let color: Color
    let label: String
    let accessibilityLabel: String

    var body: some View {
        Label {
            Text(label)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .accessibilityLabel(accessibilityLabel)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
}
