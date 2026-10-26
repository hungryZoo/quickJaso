import AppKit
import QuickJasoCore

/// Dock 아이콘 표시 전환과 자동 종료. 판정 규칙은 `AppPresencePolicy`.
@MainActor
final class AppLifecycleController {
    static let shared = AppLifecycleController()

    private var pendingEvaluation: Task<Void, Never>?
    private var windowCloseObserver: NSObjectProtocol?

    private init() {}

    func start() {
        guard windowCloseObserver == nil else { return }
        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AppLifecycleController.shared.scheduleEvaluation()
            }
        }
    }

    /// 창이 닫히는 중에는 아직 보이는 상태로 집계되므로 잠시 뒤에 판정한다.
    func scheduleEvaluation(after delay: TimeInterval = 0.5) {
        pendingEvaluation?.cancel()
        pendingEvaluation = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.evaluate()
        }
    }

    /// 직접 실행 세션에서 창을 열기 직전에 호출. Dock 아이콘과 앱 메뉴를 바로 표시한다.
    func showDockIconForUserWindow() {
        applyDockIcon(visible: true)
    }

    private func evaluate() {
        let state = AppState.shared
        let openWindows = NSApp.windows.filter { $0.isVisible || $0.isMiniaturized }
        let input = AppPresencePolicy.Input(
            isUserSession: !state.launchedForQuickAction && !state.isLaunchFallbackPending,
            openWindowCount: openWindows.filter { !($0 is NSPanel) }.count,
            openPanelCount: openWindows.filter { $0 is NSPanel }.count,
            isBusy: state.isBusy || NSApp.modalWindow != nil || UpdateController.shared.isChecking,
            isLaunchPending: state.isLaunchFallbackPending,
            isHidden: NSApp.isHidden
        )

        if AppPresencePolicy.shouldTerminate(input) {
            // 서비스 실행은 결과 패널이 닫힌 뒤, 종료 직전에 새 버전을 알린다.
            if UpdateController.shared.presentPendingUpdateIfNeeded() { return }
            NSApp.terminate(nil)
            return
        }
        if !input.isHidden {
            applyDockIcon(visible: AppPresencePolicy.showsDockIcon(input))
        }
    }

    private func applyDockIcon(visible: Bool) {
        let policy: NSApplication.ActivationPolicy = visible ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        if visible {
            // .accessory에서 .regular로 바뀐 직후에는 활성화해야 메뉴 막대에 앱 메뉴가 나타난다.
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
