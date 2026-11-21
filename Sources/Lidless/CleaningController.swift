import AppKit
import SwiftUI

private final class ShieldWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Cleaning mode: black screens, locked input, countdown, Cmd+Esc to leave early.
@MainActor
final class CleaningController: ObservableObject {
    @Published private(set) var remaining = 0
    @Published private(set) var total = 1
    /// True when the Accessibility lock is active; false means the lighter kiosk lock only.
    @Published private(set) var fullLock = false
    @Published private(set) var isActive = false

    private var windows: [NSWindow] = []
    private var timer: Timer?
    private var blocker: InputBlocker?
    private var eventMonitor: Any?
    private var watchdog: DispatchSourceTimer?
    private var savedOptions: NSApplication.PresentationOptions = []

    func start(seconds: Int) {
        guard !isActive, seconds > 0 else { return }
        isActive = true
        total = seconds
        remaining = seconds
        let end = Date().addingTimeInterval(TimeInterval(seconds))

        let blocker = InputBlocker(deadline: end) { [weak self] in
            Task { @MainActor in self?.stop() }
        }
        fullLock = blocker.start()
        self.blocker = blocker

        for screen in NSScreen.screens {
            let window = ShieldWindow(
                contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.contentView = NSHostingView(rootView: CleaningView(controller: self))
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            windows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)

        savedOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [
            .hideDock, .hideMenuBar, .disableProcessSwitching,
            .disableForceQuit, .disableSessionTermination, .disableHideApplication,
        ]
        NSCursor.hide()
        CGAssociateMouseAndMouseCursorPosition(0)

        // Works without any permission: our windows are key, so events land here.
        let mask: NSEvent.EventTypeMask = [
            .keyDown, .keyUp, .flagsChanged, .scrollWheel,
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp,
        ]
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            if event.type == .keyDown, event.keyCode == 53, event.modifierFlags.contains(.command) {
                MainActor.assumeIsolated { self?.stop() }
            }
            return nil
        }

        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let left = Int(end.timeIntervalSinceNow.rounded(.up))
                if left <= 0 { self.stop() } else if left != self.remaining { self.remaining = left }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        // Last resort: if the main thread is stuck past the deadline, quit so the kiosk lock ends.
        let watchdog = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        watchdog.schedule(deadline: .now() + .seconds(seconds + 5))
        watchdog.setEventHandler { exit(0) }
        watchdog.resume()
        self.watchdog = watchdog
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        watchdog?.cancel()
        watchdog = nil
        timer?.invalidate()
        timer = nil
        blocker?.stop()
        blocker = nil
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
        CGAssociateMouseAndMouseCursorPosition(1)
        NSCursor.unhide()
        NSApp.presentationOptions = savedOptions
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        remaining = 0
    }
}

struct CleaningView: View {
    @ObservedObject var controller: CleaningController

    private var progress: Double {
        Double(controller.remaining) / Double(max(controller.total, 1))
    }

    private var timeText: String {
        String(format: "%02d:%02d", controller.remaining / 60, controller.remaining % 60)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.07), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.white.opacity(0.32), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)
                    Text(timeText)
                        .font(.system(size: 46, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .frame(width: 200, height: 200)

                VStack(spacing: 6) {
                    Text("Keyboard, trackpad and mouse are locked. Wipe away.")
                    if !controller.fullLock {
                        Text("Brightness and media keys still respond. Allow Accessibility in Settings for a full lock.")
                            .foregroundStyle(Color.white.opacity(0.22))
                    }
                }
                .font(.system(size: 15))
                .foregroundStyle(Color.white.opacity(0.36))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
            }

            VStack {
                HStack(spacing: 7) {
                    Text("Press")
                    KeyCap(label: "⌘")
                    Text("+")
                    KeyCap(label: "esc")
                    Text("to exit")
                }
                .font(.system(size: 14))
                .foregroundStyle(Color.white.opacity(0.36))
                .padding(.top, 96)
                Spacer()
            }
        }
    }
}

private struct KeyCap: View {
    let label: String

    var body: some View {
        Text(verbatim: label)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.6))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}
