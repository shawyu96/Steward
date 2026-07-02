import SwiftUI

@main
struct StewardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var serviceManager = ServiceManager()
    @StateObject private var remoteServerManager: RemoteServerManager = {
        let m = RemoteServerManager()
        m.load()
        return m
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serviceManager)
                .environmentObject(remoteServerManager)
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentMinSize)
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Refresh All") {
                    serviceManager.refreshAll()
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Add Service...") {
                    serviceManager.showingAddService = true
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Toggle(isOn: .init(get: { serviceManager.isAutoStartEnabled },
                                   set: { serviceManager.isAutoStartEnabled = $0 })) {
                    Text("Launch at Login")
                }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        if let window = NSApp.windows.first {
            window.title = "Steward"
            window.setContentSize(NSSize(width: 1180, height: 740))
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.center()
        }
    }
}
