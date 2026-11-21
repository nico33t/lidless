import AudioToolbox
import Foundation

/// As the lid goes down past a start angle, brightness and volume fall in step with it;
/// lifting the lid brings them back to where they were.
@MainActor
final class LidFader {
    /// Below this angle the fade is complete.
    static let endAngle = 15.0

    private let sensor = LidAngleSensor()
    private var savedBrightness: Float?
    private var savedVolume: (device: AudioObjectID, value: Float32)?
    private var lastLevel: Double = 1

    var isAvailable: Bool { sensor.isAvailable }

    func currentAngle() -> Double? { sensor.angle() }

    /// - Parameters:
    ///   - startAngle: angle where fading begins.
    ///   - floor: lowest level reached at `endAngle`, 0...1.
    func update(startAngle: Double, fadeBrightness: Bool, fadeVolume: Bool, floor: Double) {
        guard let angle = sensor.angle() else { return }
        let span = max(startAngle - Self.endAngle, 1)
        let t = min(max((angle - Self.endAngle) / span, 0), 1)
        let level = floor + (1 - floor) * t

        if level >= 0.999 {
            restore()
            return
        }
        guard abs(level - lastLevel) >= 0.01 else { return }
        lastLevel = level

        if fadeBrightness {
            if savedBrightness == nil { savedBrightness = Brightness.get() }
            if let base = savedBrightness { Brightness.set(base * Float(level)) }
        } else if let base = savedBrightness {
            Brightness.set(base)
            savedBrightness = nil
        }

        if fadeVolume {
            if savedVolume == nil, let device = AudioOutput.defaultDevice(),
               let value = AudioOutput.volume(of: device) {
                savedVolume = (device, value)
            }
            if let saved = savedVolume {
                AudioOutput.setVolume(saved.value * Float32(level), on: saved.device)
            }
        } else if let saved = savedVolume {
            AudioOutput.setVolume(saved.value, on: saved.device)
            savedVolume = nil
        }
    }

    func restore() {
        lastLevel = 1
        if let base = savedBrightness {
            Brightness.set(base)
            savedBrightness = nil
        }
        if let saved = savedVolume {
            AudioOutput.setVolume(saved.value, on: saved.device)
            savedVolume = nil
        }
    }
}
