import AppKit
import QuickJasoCore
import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Windows 호환 파일명(NFC)")
                    .font(.largeTitle.bold())
                Text("파일과 폴더의 내용은 건드리지 않고, 이름이 Windows와 호환되는 NFC 형식인지 검사하고 안전하게 변환합니다.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DropZoneView(
                isDisabled: appState.isBusy,
                onInspect: { urls in Task { await appState.inspect(urls: urls) } },
                onConvert: { urls in Task { await appState.convert(urls: urls) } }
            )

            HStack {
                Button("파일 선택하여 검사…") { chooseFiles(convert: false) }
                Button("파일 선택하여 변환…") { chooseFiles(convert: true) }
                Spacer()
                Button("상세 결과 보기") { appState.showLatestDetail() }
                    .disabled(appState.latestReport == nil)
                Button("설정…") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            }
            .disabled(appState.isBusy)

            HStack {
                Text("최근 작업")
                    .font(.headline)
                if appState.isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("처리 중")
                    Text("처리 중…")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("되돌리기") {}
                    .disabled(true)
                    .help("향후 지원 예정 (TODO)")
            }

            if appState.history.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.title)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("최근 작업 없음")
                    Text("최근 작업이 없습니다")
                        .font(.headline)
                    Text("파일이나 폴더를 선택해 검사를 시작하세요.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .combine)
            } else {
                List(appState.history) { report in
                    Button {
                        appState.showDetail(report: report)
                    } label: {
                        HStack {
                            Image(systemName: report.mode == .inspection ? "magnifyingglass.circle" : "checkmark.circle")
                                .accessibilityLabel(report.mode == .inspection ? "검사" : "변환")
                            VStack(alignment: .leading, spacing: 3) {
                                Text(report.mode == .inspection ? "Windows 호환성 검사" : "Windows 호환 파일명으로 변환")
                                Text(historySummary(report))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(report.createdAt, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }

            if appState.fullDiskAccessStatus != .granted {
                Divider()
                HStack {
                    Text("보호된 위치에 접근할 수 없나요?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("전체 디스크 접근 권한 설정…") {
                        appState.showFullDiskAccessOnboarding()
                    }
                    .buttonStyle(.link)
                    Spacer()
                }
            }
        }
        .padding(24)
        .frame(minWidth: 600, minHeight: 540)
    }

    private func chooseFiles(convert: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "선택"
        panel.message = "검사하거나 변환할 파일 및 폴더를 선택하세요."
        guard panel.runModal() == .OK else { return }
        if convert {
            Task { await appState.convert(urls: panel.urls) }
        } else {
            Task { await appState.inspect(urls: panel.urls) }
        }
    }

    private func historySummary(_ report: InspectionReport) -> String {
        let summary = report.summary
        if report.mode == .inspection {
            return "총 \(summary.total)개 · 변환 필요 \(summary.needsRename)개 · 문제 \(summary.problems + summary.skipped)개"
        }
        return "총 \(summary.total)개 · 변환됨 \(summary.renamed)개 · 문제 \(summary.problems + summary.skipped)개"
    }
}
