import Foundation

enum QuickActionRequest {
    case inspect([URL])
    case convert([URL])
}

struct QuickActionRouter {
    private let appState: AppState
    private let coalescer: QuickActionRequestCoalescer

    @MainActor
    init(appState: AppState) {
        self.appState = appState
        coalescer = QuickActionRequestCoalescer()
    }

    func parse(url: URL) -> QuickActionRequest? {
        guard url.scheme?.lowercased() == "quickjaso",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let action = (components.host?.isEmpty == false ? components.host : nil)
            ?? components.path.split(separator: "/").first.map(String.init)
        guard action == "inspect" || action == "convert" else { return nil }

        let urls = (components.queryItems ?? []).compactMap { item -> URL? in
            guard item.name == "file", let value = item.value,
                  let fileURL = URL(string: value), fileURL.isFileURL else {
                return nil
            }
            return fileURL.standardizedFileURL
        }
        guard !urls.isEmpty else { return nil }
        return action == "inspect" ? .inspect(urls) : .convert(urls)
    }

    func route(_ request: QuickActionRequest) {
        Task { @MainActor in
            guard coalescer.shouldRoute(request) else {
                NSLog("quickJaso: 1초 이내의 중복 빠른 동작 요청을 무시했습니다.")
                return
            }
            switch request {
            case .inspect(let urls):
                await appState.inspect(urls: urls)
            case .convert(let urls):
                await appState.convert(urls: urls)
            }
        }
    }
}

@MainActor
private final class QuickActionRequestCoalescer {
    private var routedAtByRequest: [RequestKey: TimeInterval] = [:]
    private let interval: TimeInterval = 1

    func shouldRoute(_ request: QuickActionRequest) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        let key = RequestKey(request)
        routedAtByRequest = routedAtByRequest.filter { now - $0.value < interval }
        guard let lastRoutedAt = routedAtByRequest[key], now - lastRoutedAt < interval else {
            routedAtByRequest[key] = now
            return true
        }
        return false
    }

    private struct RequestKey: Hashable {
        let action: String
        let paths: [String]

        init(_ request: QuickActionRequest) {
            switch request {
            case .inspect(let urls):
                action = "inspect"
                paths = urls.map { $0.standardizedFileURL.path }
            case .convert(let urls):
                action = "convert"
                paths = urls.map { $0.standardizedFileURL.path }
            }
        }
    }
}
