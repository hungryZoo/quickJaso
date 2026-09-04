import AppKit
import Carbon
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var servicesProvider: QuickActionReceiver?
    private let router = QuickActionRouter(appState: .shared)

    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        detectQuickActionLaunch()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        detectQuickActionLaunch()
        if AppState.shared.launchedForQuickAction {
            orderOutRestoredWindows()
        }

        let receiver = QuickActionReceiver(router: router)
        servicesProvider = receiver
        NSApp.servicesProvider = receiver
        NSUpdateDynamicServices()

        // Always start hidden. A normal launch is revealed after the one-second
        // fallback window unless a service, URL, or document request arrives.
        DispatchQueue.main.async {
            AppState.shared.hideMainWindow()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            AppState.shared.completeLaunchFallback()
        }
        AppState.shared.showFullDiskAccessOnboardingIfNeeded()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        AppState.shared.markQuickActionRequestReceived()
        var files: [URL] = []
        for url in urls {
            if url.isFileURL {
                files.append(url)
            } else if url.scheme?.lowercased() == "quickjaso" {
                routeURL(url)
            }
        }
        if !files.isEmpty {
            router.route(.inspect(files))
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func application(_ app: NSApplication, willEncodeRestorableState coder: NSCoder) {}

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        orderOutAllWindows()
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        orderOutAllWindows()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppState.shared.showMainWindow()
        return true
    }

    private func detectQuickActionLaunch() {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return }

        let eventID = event.eventID
        let isServiceLaunch = event.paramDescriptor(forKeyword: keyAELaunchedAsServiceItem) != nil
            || event.paramDescriptor(forKeyword: Self.legacyServiceItemKeyword) != nil
        let isLoginItemLaunch = event.paramDescriptor(forKeyword: keyAELaunchedAsLogInItem) != nil
        let isUserLaunch = eventID == kAEOpenApplication
            && !isServiceLaunch
            && !isLoginItemLaunch

        // GURL/odoc and service/login-item oapp events all take this path.
        // Unknown launch events are also kept hidden: only a plain oapp is a
        // deliberate user launch.
        if !isUserLaunch {
            AppState.shared.markLaunchAsQuickAction()
        }
    }

    // Some launch paths have historically used 'lsvc' instead of Carbon's
    // keyAELaunchedAsServiceItem ('svit'), so accept both descriptors.
    private static let legacyServiceItemKeyword: AEKeyword = 0x6C73_7663

    private func orderOutRestoredWindows() {
        for window in NSApp.windows where !(window is NSPanel) {
            window.orderOut(nil)
        }
    }

    private func orderOutAllWindows() {
        for window in NSApp.windows {
            window.orderOut(nil)
        }
    }

    private func routeURL(_ url: URL) {
        guard let request = router.parse(url: url) else {
            NSLog("quickJaso: 지원하지 않거나 안전하지 않은 URL 요청입니다: %@", url.absoluteString)
            return
        }
        router.route(request)
    }
}
