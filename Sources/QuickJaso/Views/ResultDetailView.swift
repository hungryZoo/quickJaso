import AppKit
import QuickJasoCore
import SwiftUI

struct ResultDetailView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ResultDetailContent(viewModel: appState.resultDetailViewModel)
            .background(DetailWindowRestorationBridge())
    }
}

private struct DetailWindowRestorationBridge: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DetailWindowTrackingView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        AppState.shared.detailWindowDidAppear(window)
    }
}

private final class DetailWindowTrackingView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        AppState.shared.detailWindowDidAppear(window)
    }
}

private struct ResultDetailContent: View {
    @ObservedObject var viewModel: ResultDetailViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Picker("필터", selection: $viewModel.filter) {
                    ForEach(StatusFilter.allCases) { filter in
                        Text(filter.koreanLabel).tag(filter)
                    }
                }
                .frame(width: 170)

                TextField("경로 또는 상태 검색", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 180)

                Spacer()

                Button("Finder에서 보기") { viewModel.revealSelection() }
                    .disabled(viewModel.selection.isEmpty)
                Button("변경 내역 복사") { viewModel.copyChangeLog() }
                    .disabled(viewModel.report == nil)
                Button("CSV 내보내기") { viewModel.exportCSV() }
                    .disabled(viewModel.report == nil)
                Button("닫기") { closeDetailWindow() }
            }
            .padding(12)

            Divider()

            Table(viewModel.filteredItems, selection: $viewModel.selection) {
                TableColumn("결과") { item in
                    StatusBadge(status: item.status)
                        .onTapGesture(count: 2) { viewModel.revealInFinder(item) }
                        .resultRowAccessibility(status: item.status, message: item.message)
                }
                .width(min: 150, ideal: 190)

                TableColumn("원래 상대 경로") { item in
                    Text(item.originalRelativePath)
                        .lineLimit(2)
                }
                .width(min: 180, ideal: 260)

                TableColumn("변환 후 상대 경로") { item in
                    Text(viewModel.relativeResultPath(for: item))
                        .lineLimit(2)
                }
                .width(min: 180, ideal: 260)

                TableColumn("상태") { item in
                    Text(item.status.koreanLabel)
                }
                .width(min: 150, ideal: 190)

                TableColumn("상세 사유") { item in
                    Text(item.message ?? "")
                        .lineLimit(2)
                }
                .width(min: 160, ideal: 260)
            }
            .contextMenu {
                Button("Finder에서 보기") { viewModel.revealSelection() }
                    .disabled(viewModel.selection.isEmpty)
            }

            Divider()
            footer
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(minWidth: 900, minHeight: 500)
    }

    @ViewBuilder
    private var footer: some View {
        if let report = viewModel.report {
            let summary = report.summary
            HStack {
                Text("총 \(summary.total)개")
                Text("이미 NFC \(summary.alreadyNFC)개")
                Text("변환 필요 \(summary.needsRename)개")
                Text("변환됨 \(summary.renamed)개")
                Text("충돌 \(summary.collisions)개")
                Text("오류·확인 불가 \(summary.inaccessible + summary.errors + summary.skipped)개")
                Spacer()
                Text("표시 \(viewModel.filteredItems.count)개")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
            HStack {
                Text("표시할 결과가 없습니다.")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func closeDetailWindow() {
        NSApp.windows.first(where: { $0.identifier?.rawValue == "detail" || $0.title == "상세 결과" })?.close()
    }
}
