import QuickJasoCore
import SwiftUI

struct StatusBadge: View {
    let status: NormalizationStatus
    var compact = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: status.sfSymbolName)
                .foregroundStyle(color)
                .accessibilityLabel(status.koreanLabel)
            if !compact {
                Text(status.koreanLabel)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.koreanLabel)
    }

    private var color: Color {
        switch status.severity {
        case .success: return .green
        case .warning: return .orange
        case .danger: return .red
        case .neutral: return .secondary
        }
    }
}

extension View {
    func resultRowAccessibility(status: NormalizationStatus, message: String?) -> some View {
        accessibilityElement(children: .combine)
            .accessibilityLabel([status.koreanLabel, message].compactMap { $0 }.joined(separator: ", "))
    }
}
