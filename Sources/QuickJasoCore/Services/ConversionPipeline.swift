import Foundation

public struct ConversionPipeline {
    private let scanner: FileTreeScanner
    private let planner: RenamePlanner
    private let executor: RenameExecutor
    private let riskAnalyzer: VolumeRiskAnalyzer

    public init(
        scanner: FileTreeScanner = FileTreeScanner(),
        planner: RenamePlanner = RenamePlanner(),
        executor: RenameExecutor = RenameExecutor(),
        riskAnalyzer: VolumeRiskAnalyzer = VolumeRiskAnalyzer()
    ) {
        self.scanner = scanner
        self.planner = planner
        self.executor = executor
        self.riskAnalyzer = riskAnalyzer
    }

    public func inspect(urls: [URL], options: ScanOptions = .default) -> InspectionReport {
        let start = Date()
        let scan = scanner.scan(roots: urls, options: options)
        let plan = planner.makePlan(from: scan, options: options)
        let risk = riskAnalyzer.assess(plan: plan, options: options)
        return InspectionReport(
            mode: .inspection,
            items: plan.items,
            summary: plan.summary,
            rootURLs: plan.rootURLs,
            duration: Date().timeIntervalSince(start),
            risk: risk
        )
    }

    public func plan(urls: [URL], options: ScanOptions = .default) -> (RenamePlan, RiskAssessment) {
        let scan = scanner.scan(roots: urls, options: options)
        let plan = planner.makePlan(from: scan, options: options)
        return (plan, riskAnalyzer.assess(plan: plan, options: options))
    }

    public func execute(plan: RenamePlan) -> InspectionReport {
        let start = Date()
        let result = executor.execute(plan: plan)
        return InspectionReport(
            mode: .conversion,
            items: result.items,
            summary: InspectionSummary(items: result.items),
            rootURLs: plan.rootURLs,
            duration: Date().timeIntervalSince(start)
        )
    }
}
