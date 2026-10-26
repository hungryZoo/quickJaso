import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SettingsContent(
            settings: appState.settings,
            onShowFullDiskAccessOnboarding: appState.showFullDiskAccessOnboarding
        )
    }
}

private struct SettingsContent: View {
    @ObservedObject var settings: AppSettings
    let onShowFullDiskAccessOnboarding: () -> Void

    var body: some View {
        Form {
            Toggle("변환 전 확인 창 건너뛰기", isOn: $settings.skipConversionConfirmation)
            Toggle("심볼릭 링크 이름도 변환", isOn: $settings.renameSymlinkItself)
            VStack(alignment: .leading, spacing: 4) {
                Toggle("package(.app 등) 내부까지 변환", isOn: $settings.recurseIntoPackages)
                Text("이 옵션을 켜면 항상 위험 확인 창이 표시됩니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Toggle("숨김 파일 포함", isOn: $settings.includeHiddenFiles)

            Divider()

            HStack {
                Text("보호된 위치의 파일과 폴더를 처리하려면 권한을 설정할 수 있습니다.")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("전체 디스크 접근 권한 설정…", action: onShowFullDiskAccessOnboarding)
            }

            Divider()

            UpdateSettingsRow(settings: settings, updates: .shared)
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(width: 500)
    }
}

private struct UpdateSettingsRow: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var updates: UpdateController

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("업데이트 자동 확인 (하루 1회)", isOn: $settings.automaticallyCheckForUpdates)
            HStack {
                Text("현재 버전 \(updates.currentVersion?.description ?? "알 수 없음")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(updates.isChecking ? "확인 중…" : "지금 확인") {
                    updates.checkNow()
                }
                .disabled(updates.isChecking)
            }
        }
    }
}
