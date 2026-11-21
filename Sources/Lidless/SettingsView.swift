import ApplicationServices
import SwiftUI

struct SettingsView: View {
    @ObservedObject var ai: AIModeController
    @AppStorage("cleaningSeconds") private var cleaningSeconds = 120
    @State private var launchAtLogin = Launcher.isEnabled
    @State private var accessibility = AXIsProcessTrusted()

    var body: some View {
        Form {
            Section {
                Picker("Fade while lowering the lid", selection: Binding(
                    get: { ai.fadeWhen }, set: { ai.fadeWhen = $0 })) {
                    Text("Never").tag(AIModeController.FadeWhen.never)
                    Text("Only in AI mode").tag(AIModeController.FadeWhen.aiModeOnly)
                    Text("Always").tag(AIModeController.FadeWhen.always)
                }
                if ai.fadeWhen != .never {
                    Toggle("Dim brightness", isOn: Binding(
                        get: { ai.fadeBrightness }, set: { ai.fadeBrightness = $0 }))
                    Toggle("Lower volume", isOn: Binding(
                        get: { ai.fadeVolume }, set: { ai.fadeVolume = $0 }))
                    LabeledContent("Start at") {
                        HStack {
                            Slider(value: Binding(get: { ai.fadeStartAngle }, set: { ai.fadeStartAngle = $0 }),
                                   in: 30...110, step: 5)
                            Text("\(Int(ai.fadeStartAngle))°").monospacedDigit().frame(width: 40, alignment: .trailing)
                        }
                    }
                    LabeledContent("Lowest level") {
                        HStack {
                            Slider(value: Binding(get: { ai.fadeFloor }, set: { ai.fadeFloor = $0 }),
                                   in: 0...0.8, step: 0.05)
                            Text("\(Int(ai.fadeFloor * 100))%").monospacedDigit().frame(width: 40, alignment: .trailing)
                        }
                    }
                }
                if let angle = ai.lidAngle {
                    LabeledContent("Lid angle now", value: "\(Int(angle))°")
                } else if !ai.fader.isAvailable {
                    Text("This Mac has no lid angle sensor, so fading is not available.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Lowering the lid")
            } footer: {
                Text("Brightness and volume follow the lid down from the start angle, and come back when you lift it.")
            }

            Section {
                Toggle("Mute sound when the lid is closed", isOn: Binding(
                    get: { ai.silenceOnLidClose }, set: { ai.silenceOnLidClose = $0 }))
                Toggle("Turn the screen off when the lid is closed", isOn: Binding(
                    get: { ai.blankOnLidClose }, set: { ai.blankOnLidClose = $0 }))
                Picker("Turn off on battery at", selection: Binding(
                    get: { ai.batteryFloor }, set: { ai.batteryFloor = $0 })) {
                    Text("Never").tag(0)
                    Text("10%").tag(10)
                    Text("15%").tag(15)
                    Text("20%").tag(20)
                    Text("30%").tag(30)
                }
                Toggle("Restore normal sleep when quitting", isOn: Binding(
                    get: { ai.restoreOnQuit }, set: { ai.restoreOnQuit = $0 }))
            } header: {
                Text("AI mode")
            } footer: {
                Text("With an external display connected, Lidless leaves sound and screen alone. The battery cut-off works only when switching without a password is on.")
            }

            Section {
                Toggle("Switch without asking for a password", isOn: Binding(
                    get: { ai.passwordless }, set: { ai.setPasswordless($0) }))
                    .disabled(ai.isBusy)
            } header: {
                Text("Password")
            } footer: {
                Text("Adds a rule to /etc/sudoers.d/lidless that allows only “pmset -a disablesleep 0” and “pmset -a disablesleep 1” for your user. Turn it off to remove the file.")
            }

            Section {
                Picker("Duration", selection: $cleaningSeconds) {
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("2 minutes").tag(120)
                    Text("3 minutes").tag(180)
                }
                LabeledContent("Full input lock") {
                    if accessibility {
                        Label("Allowed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Allow in System Settings…") {
                            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
                            accessibility = AXIsProcessTrustedWithOptions(options)
                        }
                    }
                }
            } header: {
                Text("Cleaning mode")
            } footer: {
                Text("Without Accessibility, brightness and media keys still respond during cleaning.")
            }

            Section {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, value in Launcher.set(value) }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            accessibility = AXIsProcessTrusted()
        }
    }
}
