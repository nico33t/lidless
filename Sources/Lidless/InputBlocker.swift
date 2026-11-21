import ApplicationServices
import CoreGraphics
import Foundation

/// Swallows every keyboard, trackpad and mouse event until the deadline or until Cmd+Esc.
///
/// Needs the Accessibility permission. The tap runs on its own thread and checks the deadline
/// inside the callback, so input comes back on time even if the main thread is stuck.
final class InputBlocker {
    private static let escapeKeyCode: Int64 = 53

    private let deadline: Date
    private let onExitShortcut: () -> Void
    private let lock = NSLock()
    private var released = false
    private var tap: CFMachPort?
    private var runLoop: CFRunLoop?

    init(deadline: Date, onExitShortcut: @escaping () -> Void) {
        self.deadline = deadline
        self.onExitShortcut = onExitShortcut
    }

    private var isReleased: Bool {
        lock.lock(); defer { lock.unlock() }
        return released
    }

    private func release() {
        lock.lock(); released = true; lock.unlock()
    }

    /// Returns false when the permission is missing or the tap could not be created.
    func start() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let blocker = Unmanaged<InputBlocker>.fromOpaque(refcon).takeUnretainedValue()
            return blocker.handle(type: type, event: event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: ~CGEventMask(0),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        self.tap = tap

        let thread = Thread { [self] in
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            lock.lock(); runLoop = CFRunLoopGetCurrent(); lock.unlock()
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            if !isReleased { CFRunLoopRun() }
        }
        thread.name = "Lidless input lock"
        thread.qualityOfService = .userInteractive
        thread.start()
        return true
    }

    func stop() {
        release()
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        CFMachPortInvalidate(tap)
        lock.lock(); let loop = runLoop; lock.unlock()
        if let loop { CFRunLoopStop(loop) }
        self.tap = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if !isReleased, Date() < deadline, let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return pass
        }
        if isReleased || Date() >= deadline { return pass }
        if type == .keyDown,
           event.getIntegerValueField(.keyboardEventKeycode) == Self.escapeKeyCode,
           event.flags.contains(.maskCommand) {
            release()
            onExitShortcut()
        }
        return nil
    }
}
