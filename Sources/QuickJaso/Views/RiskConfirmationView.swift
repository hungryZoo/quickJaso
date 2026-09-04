import QuickJasoCore
import SwiftUI

struct RiskConfirmationView: View {
    let risk: RiskAssessment
    let onCancel: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundStyle(.orange)
                    .accessibilityLabel("주의")
                Text("변환 전 미리보기")
                    .font(.title2.bold())
            }

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow { Text("바뀔 항목 수"); Text("\(risk.plannedRenameCount)개").bold() }
                GridRow { Text("이미 NFC라서 유지될 항목 수"); Text("\(risk.keepCount)개").bold() }
                GridRow { Text("충돌·오류로 건너뛸 항목 수"); Text("\(risk.skipCount)개").bold() }
            }

            Text("위험 요약")
                .font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(risk.reasons, id: \.self) { reason in
                        Label(reason.koreanDescription, systemImage: "exclamationmark.triangle")
                            .accessibilityLabel("주의, \(reason.koreanDescription)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 150)

            Text("충돌하거나 확인할 수 없는 항목은 변경하지 않습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("취소", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("계속 변환", action: onContinue)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520, height: 430)
    }
}
