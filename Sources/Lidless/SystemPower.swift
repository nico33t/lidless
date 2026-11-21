import CoreGraphics
import Foundation
import IOKit
import IOKit.ps
import IOKit.pwr_mgt

/// Runs a command and waits for it. Returns the exit status, or -1 if it could not start.
@discardableResult
func runProcess(_ path: String, _ arguments: [String]) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do { try process.run() } catch { return -1 }
    process.waitUntilExit()
    return process.terminationStatus
}

/// Read-only view of the Mac's power state, plus the two display actions that need no privileges.
enum SystemPower {
    struct Battery {
        let percent: Int
        let onACPower: Bool
    }

    private static func rootDomainProperty(_ key: String) -> Any? {
        let entry = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard entry != 0 else { return nil }
        defer { IOObjectRelease(entry) }
        return IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue()
    }

    /// What `pmset -g` reports as `SleepDisabled`. This is the single source of truth for AI mode.
    static var isSleepDisabled: Bool {
        (rootDomainProperty("SleepDisabled") as? Bool) ?? false
    }

    static var isLidClosed: Bool {
        (rootDomainProperty("AppleClamshellState") as? Bool) ?? false
    }

    /// True when a display other than the built-in one is connected (desk setup with the lid closed).
    static var hasExternalDisplay: Bool {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return false }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &displays, &count) == .success else { return false }
        return displays.prefix(Int(count)).contains { CGDisplayIsBuiltin($0) == 0 }
    }

    static var battery: Battery? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  (info[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType,
                  let current = info[kIOPSCurrentCapacityKey] as? Int,
                  let max = info[kIOPSMaxCapacityKey] as? Int, max > 0
            else { continue }
            let onAC = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            return Battery(percent: current * 100 / max, onACPower: onAC)
        }
        return nil
    }

    /// Turns the display off right away. Blocking; call off the main thread.
    static func sleepDisplay() {
        runProcess("/usr/bin/pmset", ["displaysleepnow"])
    }

    static func wakeDisplay() {
        var assertion: IOPMAssertionID = 0
        IOPMAssertionDeclareUserActivity("Lidless: lid opened" as CFString, kIOPMUserActiveLocal, &assertion)
    }
}
