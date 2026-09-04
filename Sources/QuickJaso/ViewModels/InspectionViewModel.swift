import Foundation
import QuickJasoCore

@MainActor
final class InspectionViewModel: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastReport: InspectionReport?

    private let pipeline: ConversionPipeline

    init(pipeline: ConversionPipeline = ConversionPipeline()) {
        self.pipeline = pipeline
    }

    func inspect(urls: [URL], options: ScanOptions) async -> InspectionReport {
        isRunning = true
        defer { isRunning = false }

        let pipeline = self.pipeline
        let report = await Task.detached(priority: .userInitiated) {
            pipeline.inspect(urls: urls, options: options)
        }.value
        lastReport = report
        return report
    }
}
