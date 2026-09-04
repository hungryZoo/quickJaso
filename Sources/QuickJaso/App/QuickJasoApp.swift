import SwiftUI

@main
struct QuickJasoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        Window("quickJaso", id: "main") {
            MainWindowView()
                .environmentObject(appState)
                .background(MainWindowBridge())
                .background(DetailWindowBridge())
        }
        .defaultSize(width: 680, height: 620)

        Window("상세 결과", id: "detail") {
            ResultDetailView()
                .environmentObject(appState)
        }
        .defaultSize(width: 1_050, height: 600)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
        .commands {
            AppCommands(appState: appState)
        }
    }
}

private struct MainWindowBridge: NSViewRepresentable {
    @Environment(\.openWindow) private var openWindow

    func makeNSView(context: Context) -> NSView {
        AppState.shared.installMainWindowOpener {
            openWindow(id: "main")
        }
        return MainWindowTrackingView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        AppState.shared.mainWindowDidAppear(window)
    }
}

private final class MainWindowTrackingView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        AppState.shared.mainWindowDidAppear(window)
    }
}

private struct DetailWindowBridge: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                AppState.shared.installDetailWindowOpener {
                    openWindow(id: "detail")
                }
            }
    }
}
