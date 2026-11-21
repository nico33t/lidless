import AppKit
import ServiceManagement
import SwiftUI

@main
struct LidlessApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(ai: appDelegate.ai, cleaning: appDelegate.cleaning)
        } label: {
            MenuBarIcon(ai: appDelegate.ai)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(ai: appDelegate.ai)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let ai = AIModeController()
    let cleaning = CleaningController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        ai.startMonitoring()
        // `--clean-seconds N` starts cleaning mode straight away (used for quick tests).
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--clean-seconds"), index + 1 < args.count,
           let seconds = Int(args[index + 1]) {
            cleaning.start(seconds: seconds)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        cleaning.stop()
        ai.restoreForQuit()
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
