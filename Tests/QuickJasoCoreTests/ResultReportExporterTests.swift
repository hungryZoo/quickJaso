import Foundation
import XCTest
@testable import QuickJasoCore

final class ResultReportExporterTests: XCTestCase {
    func testCSVUsesRFC4180Quoting() {
        let parent = URL(fileURLWithPath: "/tmp")
        let item = FilenameInspectionItem(
            originalURL: parent.appendingPathComponent("a,b.txt"),
            originalRelativePath: "Folder/a,b.txt",
            originalName: "a,b.txt",
            normalizedNFCName: "a,b.txt",
            kind: .file,
            status: .error,
            message: "따옴표 \"오류\"\n다음 줄",
            depth: 1,
            parentURL: parent
        )
        let report = InspectionReport(
            mode: .inspection,
            items: [item],
            summary: InspectionSummary(items: [item]),
            rootURLs: [item.originalURL],
            duration: 0
        )

        let csv = ResultReportExporter().csv(report: report)
        XCTAssertTrue(csv.hasPrefix("결과,원래 상대 경로,변환 후 상대 경로,상태,상세 사유\r\n"))
        XCTAssertTrue(csv.contains("\"Folder/a,b.txt\""))
        XCTAssertTrue(csv.contains("\"따옴표 \"\"오류\"\"\n다음 줄\""))
    }
}
