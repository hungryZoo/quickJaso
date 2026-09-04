import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    enum Action: String, CaseIterable, Identifiable {
        case inspect = "검사"
        case convert = "변환"

        var id: String { rawValue }
    }

    let isDisabled: Bool
    let onInspect: ([URL]) -> Void
    let onConvert: ([URL]) -> Void

    @State private var action: Action = .inspect
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 14) {
            Picker("작업", selection: $action) {
                ForEach(Action.allCases) { action in
                    Text(action.rawValue).tag(action)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)

            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 34))
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
                .accessibilityLabel("파일 및 폴더 놓기")
            Text(action == .inspect ? "검사할 파일 및 폴더를 여기에 놓으세요" : "변환할 파일 및 폴더를 여기에 놓으세요")
                .font(.headline)
            Text("여러 항목을 한 번에 놓을 수 있습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isTargeted ? Color.accentColor.opacity(0.09) : Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [7]))
        )
        .opacity(isDisabled ? 0.55 : 1)
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
            guard !isDisabled else { return false }
            loadURLs(from: providers)
            return !providers.isEmpty
        }
    }

    private func loadURLs(from providers: [NSItemProvider]) {
        let group = DispatchGroup()
        let lock = NSLock()
        var loadedURLs: [URL] = []

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                defer { group.leave() }
                if let error {
                    NSLog("quickJaso: 드롭 항목을 읽지 못했습니다: %@", error.localizedDescription)
                    return
                }
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let itemURL = item as? URL {
                    url = itemURL
                } else if let itemURL = item as? NSURL {
                    url = itemURL as URL
                } else {
                    url = nil
                }
                guard let url, url.isFileURL else { return }
                lock.lock()
                loadedURLs.append(url)
                lock.unlock()
            }
        }

        group.notify(queue: .main) {
            let urls = loadedURLs
            guard !urls.isEmpty else { return }
            if action == .inspect {
                onInspect(urls)
            } else {
                onConvert(urls)
            }
        }
    }
}
