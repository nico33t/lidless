import Foundation
import IOKit.hid

/// Reads the lid hinge angle on MacBooks that have the sensor (Apple Silicon MacBook Pro and Air).
final class LidAngleSensor {
    private let manager: IOHIDManager
    private var device: IOHIDDevice?

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDVendorIDKey: 0x05AC,
            kIOHIDProductIDKey: 0x8104,
            kIOHIDPrimaryUsagePageKey: 0x0020,
            kIOHIDPrimaryUsageKey: 0x008A,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        if IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess,
           let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
            device = devices.first
        }
    }

    var isAvailable: Bool { device != nil }

    /// Degrees: about 0 closed, 90 upright, up to about 130 wide open. Nil when unreadable.
    func angle() -> Double? {
        guard let device else { return nil }
        var report = [UInt8](repeating: 0, count: 8)
        var length = CFIndex(report.count)
        guard IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length) == kIOReturnSuccess,
              length >= 3
        else { return nil }
        return Double(Int(report[1]) | Int(report[2]) << 8)
    }
}
