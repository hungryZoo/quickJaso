import Foundation

public enum ReportMode: String, Codable, CaseIterable, Sendable {
    case inspection
    case conversion
}

public struct InspectionReport: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let mode: ReportMode
    public let createdAt: Date
    public let items: [FilenameInspectionItem]
    public let summary: InspectionSummary
    public let rootURLs: [URL]
    public let duration: TimeInterval
    public let risk: RiskAssessment?

    public init(
        id: UUID = UUID(),
        mode: ReportMode,
        createdAt: Date = Date(),
        items: [FilenameInspectionItem],
        summary: InspectionSummary,
        rootURLs: [URL],
        duration: TimeInterval,
        risk: RiskAssessment? = nil
    ) {
        self.id = id
        self.mode = mode
        self.createdAt = createdAt
        self.items = items
        self.summary = summary
        self.rootURLs = rootURLs
        self.duration = duration
        self.risk = risk
    }
}
