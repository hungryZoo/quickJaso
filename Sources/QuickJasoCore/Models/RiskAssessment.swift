import Foundation

public enum RiskReason: String, Codable, CaseIterable, Sendable {
    case manyItems
    case manyRenames
    case hasCollisions
    case syncedLocation
    case externalOrNetworkVolume
    case gitRepository
    case packageRecursionEnabled

    public var koreanDescription: String {
        switch self {
        case .manyItems: return "검사 대상이 100개 이상입니다"
        case .manyRenames: return "변경할 이름이 50개 이상입니다"
        case .hasCollisions: return "이름 충돌 항목이 있습니다"
        case .syncedLocation: return "동기화 저장소의 항목입니다"
        case .externalOrNetworkVolume: return "외장 또는 네트워크 볼륨의 항목입니다"
        case .gitRepository: return "Git 저장소 내부의 항목입니다"
        case .packageRecursionEnabled: return "패키지 내부 재귀 변환이 켜져 있습니다"
        }
    }
}

public struct RiskAssessment: Codable, Hashable, Sendable {
    public let reasons: [RiskReason]
    public let plannedRenameCount: Int
    public let keepCount: Int
    public let skipCount: Int
    public let totalCount: Int

    public var isRisky: Bool { !reasons.isEmpty }

    public init(
        reasons: [RiskReason],
        plannedRenameCount: Int,
        keepCount: Int,
        skipCount: Int,
        totalCount: Int
    ) {
        self.reasons = reasons
        self.plannedRenameCount = plannedRenameCount
        self.keepCount = keepCount
        self.skipCount = skipCount
        self.totalCount = totalCount
    }
}
