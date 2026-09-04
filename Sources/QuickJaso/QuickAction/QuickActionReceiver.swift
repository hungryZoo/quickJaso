import AppKit
import Foundation

@MainActor
final class QuickActionReceiver: NSObject {
    private let router: QuickActionRouter

    init(router: QuickActionRouter) {
        self.router = router
        super.init()
    }

    @objc func inspectFiles(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        AppState.shared.markQuickActionRequestReceived()
        let urls = extractURLs(from: pboard)
        guard !urls.isEmpty else {
            error.pointee = "선택된 파일이 없습니다."
            return
        }
        router.route(.inspect(urls))
    }

    @objc func convertFiles(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        AppState.shared.markQuickActionRequestReceived()
        let urls = extractURLs(from: pboard)
        guard !urls.isEmpty else {
            error.pointee = "선택된 파일이 없습니다."
            return
        }
        router.route(.convert(urls))
    }

    private func extractURLs(from pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
           !urls.isEmpty {
            return urls.filter(\.isFileURL)
        }

        let legacyType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        guard let paths = pasteboard.propertyList(forType: legacyType) as? [String] else { return [] }
        return paths.map { URL(fileURLWithPath: $0).standardizedFileURL }
    }
}
