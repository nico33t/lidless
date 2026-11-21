import ApplicationServices
import SwiftUI

/// Main window: the two modes as glass cards on top, every option below.
struct SettingsView: View {
    @ObservedObject var ai: AIModeController
    @ObservedObject var cleaning: CleaningController
    @AppStorage("cleaningSeconds") private var cleaningSeconds = 120
    @AppStorage("showWindowAtLaunch") private var showWindowAtLaunch = true
    @State private var launchAtLogin = Launcher.isEnabled
    @State private var accessibility = AXIsProcessTrusted()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                GlassGroup(spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        aiCard
                        cleaningCard
                    }
                }
                fadeSection
                lidClosedSection
                passwordSection
                cleaningSection
                generalSection
            }
            .padding(.horizontal, 24)
            .padding(.top, 34)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
        .background(AmbientBackground(active: ai.isOn))
        .frame(minWidth: 540, minHeight: 420)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            accessibility = AXIsProcessTrusted()
        }
    }

    // MARK: Header and mode cards

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "Lidless")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("Close the lid. Your AI agents keep working.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image(systemName: ai.isOn ? "laptopcomputer.badge.checkmark" : "laptopcomputer")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(ai.isOn ? Color.accentColor : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                Spacer()
                if ai.isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Toggle("AI mode", isOn: Binding(get: { ai.isOn }, set: { ai.setOn($0) }))
                        .toggleStyle(.switch)
                        .controlSize(.large)
                        .labelsHidden()
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("AI mode").font(.title3.weight(.semibold))
                Text(ai.isOn ? "Agents keep running with the lid closed" : "Your Mac sleeps normally")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 5) {
                if let battery = ai.battery {
                    StatusLine(
                        symbol: battery.onACPower ? "powerplug.fill" : "battery.50",
                        text: battery.onACPower
                            ? String(localized: "Charging, \(battery.percent)%")
                            : String(localized: "On battery, \(battery.percent)%"))
                }
                if let angle = ai.lidAngle {
                    StatusLine(symbol: "angle", text: String(localized: "Lid at \(Int(angle))°"))
                }
            }
            if let error = ai.lastError {
                Text(error).font(.callout).foregroundStyle(.orange)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .glassCard(tint: ai.isOn ? Color.accentColor.opacity(0.35) : nil)
    }

    private var cleaningCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text("Cleaning").font(.title3.weight(.semibold))
                Text("Locks input for \(cleaningSeconds / 60) min · ⌘ esc to exit")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                cleaning.start(seconds: cleaningSeconds)
            } label: {
                Text("Start").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .glassButton(prominent: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .glassCard()
    }

    // MARK: Option sections

    private var fadeSection: some View {
        GlassSection(title: "Lowering the lid",
                     footer: "Brightness and volume follow the lid down from the start angle, and come back when you lift it.") {
            Row("Fade while lowering the lid") {
                Picker("Fade while lowering the lid", selection: Binding(
                    get: { ai.fadeWhen }, set: { ai.fadeWhen = $0 })) {
                    Text("Never").tag(AIModeController.FadeWhen.never)
                    Text("Only in AI mode").tag(AIModeController.FadeWhen.aiModeOnly)
                    Text("Always").tag(AIModeController.FadeWhen.always)
                }
                .labelsHidden()
                .fixedSize()
            }
            if ai.fadeWhen != .never {
                Divider()
                Row("Dim brightness") {
                    Toggle("Dim brightness", isOn: Binding(
                        get: { ai.fadeBrightness }, set: { ai.fadeBrightness = $0 }))
                        .toggleStyle(.switch).labelsHidden()
                }
                Divider()
                Row("Lower volume") {
                    Toggle("Lower volume", isOn: Binding(
                        get: { ai.fadeVolume }, set: { ai.fadeVolume = $0 }))
                        .toggleStyle(.switch).labelsHidden()
                }
                Divider()
                Row("Start at") {
                    Slider(value: Binding(get: { ai.fadeStartAngle }, set: { ai.fadeStartAngle = $0 }),
                           in: 30...110, step: 5)
                        .frame(width: 180)
                    Text(verbatim: "\(Int(ai.fadeStartAngle))°")
                        .monospacedDigit().foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
                }
                Divider()
                Row("Lowest level") {
                    Slider(value: Binding(get: { ai.fadeFloor }, set: { ai.fadeFloor = $0 }),
                           in: 0...0.8, step: 0.05)
                        .frame(width: 180)
                    Text(verbatim: "\(Int(ai.fadeFloor * 100))%")
                        .monospacedDigit().foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
                }
            }
            if !ai.fader.isAvailable {
                Divider()
                Text("This Mac has no lid angle sensor, so fading is not available.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var lidClosedSection: some View {
        GlassSection(title: "AI mode",
                     footer: "With an external display connected, Lidless leaves sound and screen alone. The battery cut-off works only when switching without a password is on.") {
            Row("Mute sound when the lid is closed") {
                Toggle("Mute sound when the lid is closed", isOn: Binding(
                    get: { ai.silenceOnLidClose }, set: { ai.silenceOnLidClose = $0 }))
                    .toggleStyle(.switch).labelsHidden()
            }
            Divider()
            Row("Turn the screen off when the lid is closed") {
                Toggle("Turn the screen off when the lid is closed", isOn: Binding(
                    get: { ai.blankOnLidClose }, set: { ai.blankOnLidClose = $0 }))
                    .toggleStyle(.switch).labelsHidden()
            }
            Divider()
            Row("Turn off on battery at") {
                Picker("Turn off on battery at", selection: Binding(
                    get: { ai.batteryFloor }, set: { ai.batteryFloor = $0 })) {
                    Text("Never").tag(0)
                    Text(verbatim: "10%").tag(10)
                    Text(verbatim: "15%").tag(15)
                    Text(verbatim: "20%").tag(20)
                    Text(verbatim: "30%").tag(30)
                }
                .labelsHidden()
                .fixedSize()
            }
            Divider()
            Row("Restore normal sleep when quitting") {
                Toggle("Restore normal sleep when quitting", isOn: Binding(
                    get: { ai.restoreOnQuit }, set: { ai.restoreOnQuit = $0 }))
                    .toggleStyle(.switch).labelsHidden()
            }
        }
    }

    private var passwordSection: some View {
        GlassSection(title: "Password",
                     footer: "Adds a rule to /etc/sudoers.d/lidless that allows only “pmset -a disablesleep 0” and “pmset -a disablesleep 1” for your user. Turn it off to remove the file.") {
            Row("Switch without asking for a password") {
                Toggle("Switch without asking for a password", isOn: Binding(
                    get: { ai.passwordless }, set: { ai.setPasswordless($0) }))
                    .toggleStyle(.switch).labelsHidden()
                    .disabled(ai.isBusy)
            }
        }
    }

    private var cleaningSection: some View {
        GlassSection(title: "Cleaning mode",
                     footer: "Without Accessibility, brightness and media keys still respond during cleaning.") {
            Row("Duration") {
                Picker("Duration", selection: $cleaningSeconds) {
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("2 minutes").tag(120)
                    Text("3 minutes").tag(180)
                }
                .labelsHidden()
                .fixedSize()
            }
            Divider()
            Row("Full input lock") {
                if accessibility {
                    Label("Allowed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Allow in System Settings…") {
                        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
                        accessibility = AXIsProcessTrustedWithOptions(options)
                    }
                    .glassButton()
                }
            }
        }
    }

    private var generalSection: some View {
        GlassSection(title: "General",
                     footer: "Lidless also lives in the menu bar. If you have many menu bar icons, it may be hidden behind the camera notch: open Lidless again from Applications to bring this window back.") {
            Row("Open at login") {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .toggleStyle(.switch).labelsHidden()
                    .onChange(of: launchAtLogin) { _, value in Launcher.set(value) }
            }
            Divider()
            Row("Show this window when Lidless opens") {
                Toggle("Show this window when Lidless opens", isOn: $showWindowAtLaunch)
                    .toggleStyle(.switch).labelsHidden()
            }
        }
    }
}

// MARK: Building blocks

private struct GlassSection<Content: View>: View {
    let title: LocalizedStringKey
    let footer: LocalizedStringKey?
    @ViewBuilder var content: Content

    init(title: LocalizedStringKey, footer: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.leading, 6)
            VStack(alignment: .leading, spacing: 12) { content }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 18)
            if let footer {
                Text(footer)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
            }
        }
    }
}

private struct Row<Control: View>: View {
    let label: LocalizedStringKey
    @ViewBuilder var control: Control

    init(_ label: LocalizedStringKey, @ViewBuilder control: () -> Control) {
        self.label = label
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
            Spacer(minLength: 12)
            control
        }
    }
}

struct StatusLine: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol).frame(width: 16)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}
