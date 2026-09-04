import Foundation

public enum StatusSeverity: String, Codable, CaseIterable, Sendable {
    case success
    case warning
    case danger
    case neutral
}

public enum NormalizationStatus: String, Codable, CaseIterable, Sendable {
    case alreadyNFC
    case needsRename
    case renamed
    case collision
    case skipped
    case inaccessible
    case error

    public var koreanLabel: String {
        switch self {
        case .alreadyNFC: return "Windows 호환 (NFC)"
        case .needsRename: return "NFC 변환 필요"
        case .renamed: return "Windows 호환으로 변환됨"
        case .collision: return "변환 불가 — 이름 충돌"
        case .skipped: return "확인 불가"
        case .inaccessible: return "변환 불가 — 접근 오류"
        case .error: return "변환 불가 — 오류"
        }
    }

    public var sfSymbolName: String {
        switch self {
        case .alreadyNFC, .renamed: return "checkmark.circle.fill"
        case .needsRename: return "exclamationmark.triangle.fill"
        case .collision, .inaccessible, .error: return "xmark.octagon.fill"
        case .skipped: return "questionmark.circle"
        }
    }

    public var severity: StatusSeverity {
        switch self {
        case .alreadyNFC, .renamed: return .success
        case .needsRename: return .warning
        case .collision, .inaccessible, .error: return .danger
        case .skipped: return .neutral
        }
    }
}
