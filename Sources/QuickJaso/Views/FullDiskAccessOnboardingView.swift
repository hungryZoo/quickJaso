import AppKit
import SwiftUI

struct FullDiskAccessOnboardingView: View {
    @ObservedObject private var appState: AppState
    @ObservedObject private var settings: AppSettings
    let onClose: () -> Void

    init(appState: AppState, onClose: @escaping () -> Void) {
        self.appState = appState
        settings = appState.settings
        self.onClose = onClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("전체 디스크 접근 권한을 설정해 주세요")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Text("quickJaso는 Finder에서 선택한 파일·폴더의 이름만 검사하고 NFC로 변경합니다. 파일 내용은 읽거나 수정하지 않습니다.")
                Text("데스크탑, 문서, 다운로드, 외장 디스크, iCloud Drive 등 보호된 위치의 항목을 매번 묻지 않고 처리하려면 macOS의 \"전체 디스크 접근 권한\"이 필요합니다.")
                Text("권한을 주지 않아도 앱은 동작하지만, 접근할 수 없는 항목은 \"변환 불가 — 접근 오류\"로 표시됩니다.")
            }
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 9) {
                OnboardingStep(number: 1, text: "아래 버튼으로 시스템 설정을 엽니다")
                OnboardingStep(number: 2, text: "'전체 디스크 접근 권한' 목록에서 quickJaso를 켭니다 (목록에 없으면 + 버튼으로 /Applications/quickJaso.app 추가)")
                OnboardingStep(number: 3, text: "quickJaso를 종료했다가 다시 실행합니다.")
            }

            HStack(spacing: 8) {
                Image(systemName: statusSymbol)
                    .foregroundStyle(statusColor)
                    .accessibilityLabel(statusAccessibilityLabel)
                Text(statusText)
                Spacer()
                Button("다시 확인") {
                    appState.refreshFullDiskAccessStatus()
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(statusAccessibilityLabel)

            HStack {
                Button("Finder에서 앱 위치 보기") {
                    NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                }
                .buttonStyle(.link)
                Spacer()
            }

            Toggle(
                "앞으로 표시하지 않기",
                isOn: $settings.hasDismissedFullDiskAccessOnboarding
            )

            HStack {
                Spacer()
                Button("나중에", action: onClose)
                    .keyboardShortcut(.cancelAction)
                Button("시스템 설정 열기", action: openSystemSettings)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 620)
    }

    private var isGranted: Bool {
        appState.fullDiskAccessStatus == .granted
    }

    private var statusText: String {
        isGranted ? "현재 상태: 허용됨 ✓" : "현재 상태: 허용되지 않음"
    }

    private var statusSymbol: String {
        isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var statusColor: Color {
        isGranted ? .green : .orange
    }

    private var statusAccessibilityLabel: String {
        isGranted ? "현재 전체 디스크 접근 권한 상태, 허용됨" : "현재 전체 디스크 접근 권한 상태, 허용되지 않음"
    }

    private func openSystemSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        ) else {
            NSLog("quickJaso: 전체 디스크 접근 권한 설정 URL을 만들 수 없습니다.")
            return
        }
        if !NSWorkspace.shared.open(url) {
            NSLog("quickJaso: 전체 디스크 접근 권한 시스템 설정을 열 수 없습니다.")
        }
    }
}

private struct OnboardingStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number))")
                .fontWeight(.semibold)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(number)단계, \(text)")
    }
}
