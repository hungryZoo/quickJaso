import SwiftUI

struct ConversionConfirmationView: View {
    @Binding var doNotAskAgain: Bool
    let onCancel: () -> Void
    let onConvert: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Windows 호환 파일명으로 변환할까요?")
                .font(.title2.bold())
            Text("선택한 항목에서 NFC가 아닌 파일 및 폴더 이름만 NFC로 변경합니다.\n파일 내용은 변경하지 않습니다.\n이름 충돌, 권한 오류, 동기화 중인 항목은 자동으로 건너뜁니다.")
                .fixedSize(horizontal: false, vertical: true)
            Toggle("앞으로 묻지 않기", isOn: $doNotAskAgain)
            HStack {
                Spacer()
                Button("취소", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("변환", action: onConvert)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}
