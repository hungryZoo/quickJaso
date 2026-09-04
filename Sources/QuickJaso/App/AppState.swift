import AppKit
import Foundation
import QuickJasoCore
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let settings: AppSettings
    let inspectionViewModel: InspectionViewModel
    let conversionViewModel: ConversionViewModel
    let resultDetailViewModel: ResultDetailViewModel

    @Published private(set) var latestReport: InspectionReport?
    @Published private(set) var history: [InspectionReport] = []
    @Published private(set) var recentOperationRecords: [OperationRecord] = []
    @Published private(set) var isBusy = false
    @Published private(set) var launchedForQuickAction = false
    @Published private(set) var fullDiskAccessStatus: FullDiskAccessChecker.Status

    private var reportsByID: [UUID: InspectionReport] = [:]
    private weak var mainWindow: NSWindow?
    private weak var detailWindow: NSWindow?
    private var fullDiskAccessOnboardingWindow: NSWindow?
    private var openMainWindow: (() -> Void)?
    private var openDetailWindow: (() -> Void)?
    private var pendingConfirmation = false
    private var isLaunchFallbackPending = true
    private var checkedFullDiskAccessOnboardingThisSession = false

    private init() {
        settings = AppSettings()
        inspectionViewModel = InspectionViewModel()
        conversionViewModel = ConversionViewModel()
        resultDetailViewModel = ResultDetailViewModel()
        fullDiskAccessStatus = FullDiskAccessChecker.status()
    }

    func installDetailWindowOpener(_ opener: @escaping () -> Void) {
        openDetailWindow = opener
    }

    func installMainWindowOpener(_ opener: @escaping () -> Void) {
        openMainWindow = opener
    }

    func markLaunchAsQuickAction() {
        launchedForQuickAction = true
        hideMainWindow()
    }

    func markQuickActionRequestReceived() {
        markLaunchAsQuickAction()
    }

    func mainWindowDidAppear(_ window: NSWindow) {
        mainWindow = window
        window.isRestorable = false
        if launchedForQuickAction || isLaunchFallbackPending {
            window.orderOut(nil)
        }
    }

    func detailWindowDidAppear(_ window: NSWindow) {
        detailWindow = window
        window.isRestorable = false
    }

    func hideMainWindow() {
        mainWindow?.orderOut(nil)
        findMainWindow()?.orderOut(nil)
    }

    func completeLaunchFallback() {
        isLaunchFallbackPending = false
        guard !launchedForQuickAction else {
            hideMainWindow()
            return
        }
        showMainWindow()
    }

    func showMainWindow() {
        launchedForQuickAction = false
        isLaunchFallbackPending = false

        if let window = mainWindow ?? findMainWindow() {
            mainWindow = window
            window.isRestorable = false
            window.makeKeyAndOrderFront(nil)
            return
        }

        openMainWindow?()
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.findMainWindow() else { return }
            self.mainWindow = window
            window.isRestorable = false
            window.makeKeyAndOrderFront(nil)
        }
    }

    func inspect(urls: [URL]) async {
        guard !urls.isEmpty, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        let report = await inspectionViewModel.inspect(urls: urls, options: settings.scanOptions)
        accept(report)
    }

    func convert(urls: [URL]) async {
        guard !urls.isEmpty, !isBusy, !pendingConfirmation else { return }
        pendingConfirmation = true
        isBusy = true
        defer {
            pendingConfirmation = false
            isBusy = false
        }

        guard let report = await conversionViewModel.convert(
            urls: urls,
            options: settings.scanOptions,
            settings: settings
        ) else { return }

        if let record = conversionViewModel.lastOperationRecord, !record.renames.isEmpty {
            recentOperationRecords.insert(record, at: 0)
            if recentOperationRecords.count > 20 {
                recentOperationRecords.removeLast(recentOperationRecords.count - 20)
            }
        }
        accept(report)
    }

    func showDetail(report: InspectionReport, filter: StatusFilter = .all) {
        resultDetailViewModel.configure(report: report, filter: filter)
        if let window = detailWindow ?? findDetailWindow() {
            detailWindow = window
            window.isRestorable = false
        }
        openDetailWindow?()
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.findDetailWindow() else { return }
            self.detailWindow = window
            window.isRestorable = false
            window.makeKeyAndOrderFront(nil)
        }
    }

    func showLatestDetail() {
        guard let latestReport else { return }
        showDetail(report: latestReport)
    }

    func showFullDiskAccessOnboardingIfNeeded() {
        guard !checkedFullDiskAccessOnboardingThisSession else { return }
        checkedFullDiskAccessOnboardingThisSession = true
        refreshFullDiskAccessStatus()
        guard !settings.hasDismissedFullDiskAccessOnboarding,
              fullDiskAccessStatus != .granted else { return }
        showFullDiskAccessOnboarding()
    }

    func showFullDiskAccessOnboarding() {
        refreshFullDiskAccessStatus()

        if let window = fullDiskAccessOnboardingWindow, window.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        fullDiskAccessOnboardingWindow?.close()
        let rootView = FullDiskAccessOnboardingView(
            appState: self,
            onClose: { [weak self] in
                self?.closeFullDiskAccessOnboarding()
            }
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "권한 설정 안내"
        window.styleMask = [.titled, .closable]
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.setContentSize(NSSize(width: 620, height: 600))
        window.center()
        fullDiskAccessOnboardingWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func refreshFullDiskAccessStatus() {
        fullDiskAccessStatus = FullDiskAccessChecker.status()
        if fullDiskAccessStatus == .granted {
            settings.hasDismissedFullDiskAccessOnboarding = true
        }
    }

    func report(withID id: UUID) -> InspectionReport? {
        reportsByID[id]
    }

    private func accept(_ report: InspectionReport) {
        latestReport = report
        history.insert(report, at: 0)
        if history.count > 20 {
            let removed = history.dropFirst(20)
            for oldReport in removed {
                reportsByID.removeValue(forKey: oldReport.id)
            }
            history = Array(history.prefix(20))
        }
        reportsByID[report.id] = report
        ResultPanelController.shared.show(report: report, appState: self)
    }

    private func closeFullDiskAccessOnboarding() {
        let window = fullDiskAccessOnboardingWindow
        fullDiskAccessOnboardingWindow = nil
        window?.close()
    }

    private func findMainWindow() -> NSWindow? {
        NSApp.windows.first {
            $0.identifier?.rawValue == "main" || $0.title == "quickJaso"
        }
    }


    private func findDetailWindow() -> NSWindow? {
        NSApp.windows.first {
            $0.identifier?.rawValue == "detail" || $0.title == "상세 결과"
        }
    }
}
