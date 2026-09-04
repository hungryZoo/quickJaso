import AppKit
import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("열어서 검사…") {
                chooseFiles { urls in
                    Task { await appState.inspect(urls: urls) }
                }
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("열어서 변환…") {
                chooseFiles { urls in
                    Task { await appState.convert(urls: urls) }
                }
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Divider()

            Button("상세 결과 보기") {
                appState.showLatestDetail()
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(appState.latestReport == nil)
        }

        CommandGroup(after: .help) {
            Divider()
            Button("전체 디스크 접근 권한 설정…") {
                appState.showFullDiskAccessOnboarding()
            }
        }
    }

    private func chooseFiles(completion: @escaping ([URL]) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "선택"
        panel.message = "검사하거나 변환할 파일 및 폴더를 선택하세요."
        guard panel.runModal() == .OK else { return }
        completion(panel.urls)
    }
}
