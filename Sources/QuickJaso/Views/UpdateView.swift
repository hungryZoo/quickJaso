import AppKit
import QuickJasoCore
import SwiftUI

struct UpdateView: View {
    let info: UpdateInfo
    let onSkip: () -> Void
    let onLater: () -> Void
    let onInstall: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 12) {
                Text("새 버전의 quickJaso를 사용할 수 있습니다")
                    .font(.title3.bold())
                Text("새 버전 \(info.newVersion.description) (현재 \(info.currentVersion.description))")
                    .foregroundStyle(.secondary)

                Text("패치 노트")
                    .font(.headline)
                ScrollView {
                    Text(releaseNotes)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(height: 220)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                Text(installDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Link("릴리스 페이지 보기", destination: info.releaseURL)
                    .font(.callout)

                HStack {
                    Button("이 버전 건너뛰기", action: onSkip)
                    Spacer()
                    Button("다음에", action: onLater)
                        .keyboardShortcut(.cancelAction)
                    Button("예", action: onInstall)
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(width: 560)
    }

    private var releaseNotes: AttributedString {
        let text = ReleaseNotesFormatter.inlineMarkdown(info.releaseNotes)
        guard !text.isEmpty else { return AttributedString("패치 노트가 없습니다.") }
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    private var installDescription: String {
        switch info.installMethod {
        case .homebrew:
            return "예를 누르면 quickJaso를 종료하고 터미널에서 brew update와 brew upgrade \(InstallMethod.caskFullName)를 실행한 뒤 새 버전을 엽니다."
        case .manual:
            return "예를 누르면 브라우저에서 릴리스 페이지를 엽니다. DMG를 내려받아 응용 프로그램 폴더의 quickJaso.app을 교체하세요."
        }
    }
}
