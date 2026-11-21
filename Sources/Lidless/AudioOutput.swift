import AudioToolbox
import CoreAudio

/// What the output device looked like before Lidless silenced it.
struct AudioSnapshot {
    let device: AudioObjectID
    let muted: UInt32?
    let volume: Float32?
}

enum AudioOutput {
    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    static func defaultDevice() -> AudioObjectID? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &device)
        return status == noErr && device != 0 ? device : nil
    }

    private static func get<T: BitwiseCopyable>(
        _ device: AudioObjectID, _ selector: AudioObjectPropertySelector, _ initial: T
    ) -> T? {
        var addr = address(selector)
        guard AudioObjectHasProperty(device, &addr) else { return nil }
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutableBytes(of: &value) { raw in
            AudioObjectGetPropertyData(device, &addr, 0, nil, &size, raw.baseAddress!)
        }
        return status == noErr ? value : nil
    }

    private static func set<T: BitwiseCopyable>(
        _ device: AudioObjectID, _ selector: AudioObjectPropertySelector, _ newValue: T
    ) -> Bool {
        var addr = address(selector)
        var settable: DarwinBoolean = false
        guard AudioObjectHasProperty(device, &addr),
              AudioObjectIsPropertySettable(device, &addr, &settable) == noErr,
              settable.boolValue
        else { return false }
        var value = newValue
        let status = withUnsafeBytes(of: &value) { raw in
            AudioObjectSetPropertyData(device, &addr, 0, nil, UInt32(raw.count), raw.baseAddress!)
        }
        return status == noErr
    }

    /// Output volume 0...1, or nil when the device has no software volume.
    static func volume(of device: AudioObjectID) -> Float32? {
        get(device, kAudioHardwareServiceDeviceProperty_VirtualMainVolume, Float32(0))
    }

    @discardableResult
    static func setVolume(_ value: Float32, on device: AudioObjectID) -> Bool {
        set(device, kAudioHardwareServiceDeviceProperty_VirtualMainVolume, min(max(value, 0), 1))
    }

    /// Mutes the current output device (or drops its volume to zero when it has no mute switch).
    static func silence() -> AudioSnapshot? {
        guard let device = defaultDevice() else { return nil }
        if let muted = get(device, kAudioDevicePropertyMute, UInt32(0)),
           set(device, kAudioDevicePropertyMute, UInt32(1)) {
            return AudioSnapshot(device: device, muted: muted, volume: nil)
        }
        if let volume = volume(of: device), setVolume(0, on: device) {
            return AudioSnapshot(device: device, muted: nil, volume: volume)
        }
        return nil
    }

    static func restore(_ snapshot: AudioSnapshot) {
        if let muted = snapshot.muted {
            _ = set(snapshot.device, kAudioDevicePropertyMute, muted)
        }
        if let volume = snapshot.volume {
            setVolume(volume, on: snapshot.device)
        }
    }
}
