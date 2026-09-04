import AppKit
import QuickJasoCore
import SwiftUI

@MainActor
final class ResultPanelPresentation: ObservableObject {
    @Published private(set) var remainingSeconds: Int?
    var onCancelAutoClose: (() -> Void)?

    init(remainingSeconds: Int?) {
        self.remainingSeconds = remainingSeconds
    }

    func updateRemaining(_ value: Int?) {
        remainingSeconds = value
    }

    func cancelAutoClose() {
        onCancelAutoClose?()
    }
}

@MainActor
final class ResultPanelController {
    static let shared = ResultPanelController()

    private var panel: NSPanel?
    private var timer: Timer?
    private var presentation: ResultPanelPresentation?

    private init() {}

    func show(report: InspectionReport, appState: AppState) {
        close()

        let shouldAutoClose = report.mode == .inspection || (
            report.summary.problems == 0
                && report.summary.skipped == 0
                && report.summary.renamed < 10
        )
        let presentation = ResultPanelPresentation(remainingSeconds: shouldAutoClose ? 4 : nil)
        presentation.onCancelAutoClose = { [weak self] in self?.cancelAutoClose() }
        self.presentation = presentation

        let rootView = ResultPanelView(
            report: report,
            presentation: presentation,
            onDetail: { [weak self, weak appState] filter in
                self?.cancelAutoClose()
                appState?.showDetail(report: report, filter: filter)
            },
            onConvert: { [weak self, weak appState] in
                self?.cancelAutoClose()
                guard let appState else { return }
                Task { await appState.convert(urls: report.rootURLs) }
            },
            onClose: { [weak self] in self?.close() }
        )
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 360, height: 320)

        let panel = NSPanel(
            contentRect: hostingView.frame,
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true

        hostingView.layoutSubtreeIfNeeded()
        let fittingSize = hostingView.fittingSize
        panel.setContentSize(NSSize(width: 360, height: max(220, fittingSize.height)))
        position(panel)
        panel.orderFrontRegardless()
        self.panel = panel

        if shouldAutoClose {
            startAutoCloseTimer()
        }
    }

    func close() {
        timer?.invalidate()
        timer = nil
        presentation?.updateRemaining(nil)
        panel?.orderOut(nil)
        panel = nil
        presentation = nil
    }

    private func startAutoCloseTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self, let remaining = self.presentation?.remainingSeconds else {
                    timer.invalidate()
                    return
                }
                if remaining <= 1 {
                    self.close()
                } else {
                    self.presentation?.updateRemaining(remaining - 1)
                }
            }
        }
    }

    private func cancelAutoClose() {
        timer?.invalidate()
        timer = nil
        presentation?.updateRemaining(nil)
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.maxX - panel.frame.width - 16,
            y: visible.maxY - panel.frame.height - 16
        )
        panel.setFrameOrigin(origin)
    }
}
