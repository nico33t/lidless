import AppKit
import ServiceManagement
import SwiftUI

@main
struct LidlessApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(ai: appDelegate.ai, cleaning: appDelegate.cleaning) {
                appDelegate.showMainWindow()
            }
        } label: {
            MenuBarIcon(ai: appDelegate.ai)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let ai = AIModeController()
    let cleaning = CleaningController()
    private var mainWindow: NSWindow?

    /// Set when macOS is logging out, restarting or shutting down.
    private var systemIsPoweringOff = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        ai.startMonitoring()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.systemIsPoweringOff = true }
        }
        // `--clean-seconds N` starts cleaning mode straight away (used for quick tests).
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--clean-seconds"), index + 1 < args.count,
           let seconds = Int(args[index + 1]) {
            cleaning.start(seconds: seconds)
            return
        }
        // Menu bar icons can hide behind the notch, so the window is the reliable way in.
        if UserDefaults.standard.object(forKey: "showWindowAtLaunch") as? Bool ?? true {
            showMainWindow()
        }
    }

    /// Double-clicking the app in Finder or Launchpad while it is running.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return false
    }

    func showMainWindow() {
        if mainWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false)
            window.title = "Lidless"
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.contentMinSize = NSSize(width: 460, height: 420)
            window.contentView = NSHostingView(rootView: SettingsView(ai: ai, cleaning: cleaning))
            window.setFrameAutosaveName("LidlessMain")
            if !window.setFrameUsingName("LidlessMain") { window.center() }
            window.delegate = self
            mainWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === mainWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        cleaning.stop()
        // On shutdown or logout a password prompt would hold up the system, and the
        // setting is meant to survive a restart anyway: only restore on a real quit.
        if systemIsPoweringOff {
            ai.fader.restore()
        } else {
            ai.restoreForQuit()
        }
    }
}

private struct MenuBarIcon: View {
    @ObservedObject var ai: AIModeController

    var body: some View {
        Image(systemName: ai.isOn ? "laptopcomputer.badge.checkmark" : "laptopcomputer")
            .accessibilityLabel(ai.isOn ? Text("Lidless, AI mode on") : Text("Lidless"))
    }
}

enum Launcher {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Lidless: login item change failed: \(error.localizedDescription)")
        }
    }
}
