import AppKit
import Foundation

/// AI mode: keep the Mac awake with the lid closed so agents keep running,
/// and when the lid closes, blank the display and silence the speakers.
@MainActor
final class AIModeController: ObservableObject {
    /// Mirrors `SleepDisabled` from the system, never a stored flag.
    @Published private(set) var isOn = SystemPower.isSleepDisabled
    @Published private(set) var isBusy = false
    @Published private(set) var lidClosed = SystemPower.isLidClosed
    @Published private(set) var battery = SystemPower.battery
    @Published private(set) var passwordless = SleepControl.isPasswordlessInstalled
    @Published var lastError: String?

    private let defaults = UserDefaults.standard
    private var timer: Timer?
    private var audioSnapshot: AudioSnapshot?
    private var displayWasBlanked = false

    var silenceOnLidClose: Bool {
        get { defaults.object(forKey: "silenceOnLidClose") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "silenceOnLidClose"); objectWillChange.send() }
    }

    var blankOnLidClose: Bool {
        get { defaults.object(forKey: "blankOnLidClose") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "blankOnLidClose"); objectWillChange.send() }
    }

    /// Battery percentage at which AI mode turns itself off so the Mac can sleep. 0 = never.
    var batteryFloor: Int {
        get { defaults.object(forKey: "batteryFloor") as? Int ?? 15 }
        set { defaults.set(newValue, forKey: "batteryFloor"); objectWillChange.send() }
    }

    var restoreOnQuit: Bool {
        get { defaults.object(forKey: "restoreOnQuit") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "restoreOnQuit"); objectWillChange.send() }
    }

    // MARK: Fade while lowering the lid

    enum FadeWhen: Int, CaseIterable, Identifiable {
        case never = 0, aiModeOnly = 1, always = 2
        var id: Int { rawValue }
    }

    var fadeWhen: FadeWhen {
        get { FadeWhen(rawValue: defaults.object(forKey: "fadeWhen") as? Int ?? 1) ?? .aiModeOnly }
        set { defaults.set(newValue.rawValue, forKey: "fadeWhen"); objectWillChange.send() }
    }

    var fadeBrightness: Bool {
        get { defaults.object(forKey: "fadeBrightness") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "fadeBrightness"); objectWillChange.send() }
    }

    var fadeVolume: Bool {
        get { defaults.object(forKey: "fadeVolume") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "fadeVolume"); objectWillChange.send() }
    }

    /// Angle in degrees where fading begins.
    var fadeStartAngle: Double {
        get { defaults.object(forKey: "fadeStartAngle") as? Double ?? 70 }
        set { defaults.set(newValue, forKey: "fadeStartAngle"); objectWillChange.send() }
    }

    /// Lowest level, 0...1, reached when the lid is almost shut.
    var fadeFloor: Double {
        get { defaults.object(forKey: "fadeFloor") as? Double ?? 0 }
        set { defaults.set(newValue, forKey: "fadeFloor"); objectWillChange.send() }
    }

    @Published private(set) var lidAngle: Double?
    let fader = LidFader()
    private var fadeTimer: Timer?

    private var fadeIsActive: Bool {
        switch fadeWhen {
        case .never: false
        case .aiModeOnly: isOn
        case .always: true
        }
    }

    func startMonitoring() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        let fadeTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.fadeTick() }
        }
        RunLoop.main.add(fadeTimer, forMode: .common)
        self.fadeTimer = fadeTimer
        tick()
    }

    private func fadeTick() {
        guard fader.isAvailable else { return }
        let angle = fader.currentAngle()
        if let angle, lidAngle.map({ abs($0 - angle) >= 1 }) ?? true { lidAngle = angle }
        guard fadeIsActive, !lidClosed, !SystemPower.hasExternalDisplay,
              fadeBrightness || fadeVolume
        else {
            fader.restore()
            return
        }
        fader.update(
            startAngle: fadeStartAngle,
            fadeBrightness: fadeBrightness,
            fadeVolume: fadeVolume,
            floor: fadeFloor
        )
    }

    func setOn(_ on: Bool) {
        guard !isBusy, on != isOn else { return }
        isBusy = true
        lastError = nil
        Task.detached(priority: .userInitiated) {
            let ok = SleepControl.setSleepDisabled(on, allowPrompt: true)
            await MainActor.run {
                self.isBusy = false
                self.isOn = SystemPower.isSleepDisabled
                if !ok {
                    self.lastError = String(localized: "The change was cancelled or not allowed.")
                }
                if !self.isOn { self.restoreAfterLid() }
            }
        }
    }

    func setPasswordless(_ enabled: Bool) {
        guard !isBusy else { return }
        isBusy = true
        Task.detached(priority: .userInitiated) {
            _ = enabled ? SleepControl.installPasswordless() : SleepControl.removePasswordless()
            await MainActor.run {
                self.isBusy = false
                self.passwordless = SleepControl.isPasswordlessInstalled
            }
        }
    }

    /// Called at quit. Only restores without a prompt when the no-password rule is installed;
    /// otherwise asks once, because leaving sleep disabled by surprise drains batteries.
    func restoreForQuit() {
        fader.restore()
        restoreAfterLid()
        guard restoreOnQuit, SystemPower.isSleepDisabled else { return }
        _ = SleepControl.setSleepDisabled(false, allowPrompt: true)
    }

    private func tick() {
        isOn = SystemPower.isSleepDisabled
        passwordless = SleepControl.isPasswordlessInstalled
        battery = SystemPower.battery
        let closed = SystemPower.isLidClosed
        if closed != lidClosed {
            lidClosed = closed
            if closed { onLidClosed() } else { restoreAfterLid() }
        }
        checkBatteryFloor()
    }

    private func onLidClosed() {
        // The fader saved the original levels; hand them back before muting so restore is exact.
        fader.restore()
        // With an external display the user is working in clamshell mode: leave everything alone.
        guard isOn, !SystemPower.hasExternalDisplay else { return }
        if silenceOnLidClose, audioSnapshot == nil {
            audioSnapshot = AudioOutput.silence()
        }
        if blankOnLidClose {
            displayWasBlanked = true
            DispatchQueue.global(qos: .userInitiated).async { SystemPower.sleepDisplay() }
        }
    }

    private func restoreAfterLid() {
        if let snapshot = audioSnapshot {
            AudioOutput.restore(snapshot)
            audioSnapshot = nil
        }
        if displayWasBlanked {
            displayWasBlanked = false
            SystemPower.wakeDisplay()
        }
    }

    /// Battery level seen on the previous check while AI mode was on and on battery.
    private var lastBatteryPercent: Int?

    private func checkBatteryFloor() {
        guard isOn, batteryFloor > 0, let battery, !battery.onACPower else {
            lastBatteryPercent = nil
            return
        }
        let previous = lastBatteryPercent
        lastBatteryPercent = battery.percent
        // Fire only when the level drops through the floor. If the user turned AI mode on
        // while already below it, that was deliberate: leave it on.
        guard !isBusy, let previous, previous > batteryFloor, battery.percent <= batteryFloor else { return }
        // No prompt here: nobody may be at the Mac. Works only with the no-password rule.
        isBusy = true
        let percent = battery.percent
        Task.detached(priority: .userInitiated) {
            _ = SleepControl.setSleepDisabled(false, allowPrompt: false)
            await MainActor.run {
                self.isBusy = false
                self.isOn = SystemPower.isSleepDisabled
                if !self.isOn {
                    self.lastError = String(localized: "Turned off: battery at \(percent)%.")
                }
            }
        }
    }
}
