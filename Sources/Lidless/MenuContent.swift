import AppKit
import SwiftUI

struct MenuContent: View {
    @ObservedObject var ai: AIModeController
    @ObservedObject var cleaning: CleaningController
    let openSettings: () -> Void
    @AppStorage("cleaningSeconds") private var cleaningSeconds = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            aiCard
                .padding(12)

            Divider().padding(.horizontal, 12)

            cleaningRow
                .padding(12)

            Divider().padding(.horizontal, 12)

            HStack {
                Button("Settings…") { openSettings() }
                .keyboardShortcut(",")
                Spacer()
                Button("Quit Lidless") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 320)
    }

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                IconTile(symbol: "sparkles", tint: ai.isOn ? .accentColor : .secondary, filled: ai.isOn)
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI mode").font(.headline)
                    Text(ai.isOn ? "Agents keep running with the lid closed" : "Your Mac sleeps normally")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if ai.isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Toggle("AI mode", isOn: Binding(get: { ai.isOn }, set: { ai.setOn($0) }))
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }

            if ai.isOn {
                VStack(alignment: .leading, spacing: 5) {
                    StatusLine(
                        symbol: ai.lidClosed ? "laptopcomputer.slash" : "laptopcomputer",
                        text: ai.lidClosed ? String(localized: "Lid closed, screen off, sound muted")
                                           : String(localized: "Close the lid: screen goes dark, sound mutes")
                    )
                    if let battery = ai.battery {
                        StatusLine(
                            symbol: battery.onACPower ? "powerplug" : "battery.50",
                            text: battery.onACPower
                                ? String(localized: "Charging, \(battery.percent)%")
                                : String(localized: "On battery, \(battery.percent)%")
                        )
                    }
                }
                .padding(.leading, 44)
            }

            if let error = ai.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.leading, 44)
            }
        }
    }

    private var cleaningRow: some View {
        Button {
            cleaning.start(seconds: cleaningSeconds)
        } label: {
            HStack(spacing: 12) {
                IconTile(symbol: "sparkles.rectangle.stack", tint: .secondary, filled: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clean screen and keyboard").font(.headline)
                    Text("Locks input for \(cleaningSeconds / 60) min · ⌘ esc to exit")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct IconTile: View {
    let symbol: String
    let tint: Color
    let filled: Bool

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(filled ? Color.white : tint)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(filled ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary))
            )
    }
}

private struct StatusLine: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol).frame(width: 16)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
