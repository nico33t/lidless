import AppKit
import SwiftUI

/// The menu bar popover: the two modes as glass cards.
struct MenuContent: View {
    @ObservedObject var ai: AIModeController
    @ObservedObject var cleaning: CleaningController
    let openSettings: () -> Void
    @AppStorage("cleaningSeconds") private var cleaningSeconds = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GlassGroup(spacing: 10) {
                VStack(spacing: 10) {
                    aiCard
                    cleaningCard
                }
            }

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
            .padding(.horizontal, 6)
        }
        .padding(12)
        .frame(width: 330)
    }

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                IconTile(symbol: "sparkles", active: ai.isOn)
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI mode").font(.headline)
                    Text(ai.isOn ? "Agents keep running with the lid closed" : "Your Mac sleeps normally")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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
                                           : String(localized: "Close the lid: screen goes dark, sound mutes"))
                    if let battery = ai.battery {
                        StatusLine(
                            symbol: battery.onACPower ? "powerplug.fill" : "battery.50",
                            text: battery.onACPower
                                ? String(localized: "Charging, \(battery.percent)%")
                                : String(localized: "On battery, \(battery.percent)%"))
                    }
                }
                .padding(.leading, 46)
            }

            if let error = ai.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.leading, 46)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 18, tint: ai.isOn ? Color.accentColor.opacity(0.3) : nil)
    }

    private var cleaningCard: some View {
        Button {
            cleaning.start(seconds: cleaningSeconds)
        } label: {
            HStack(spacing: 12) {
                IconTile(symbol: "sparkles.rectangle.stack", active: false)
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
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassCard(cornerRadius: 18)
    }
}

private struct IconTile: View {
    let symbol: String
    let active: Bool

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(active ? Color.white : Color.secondary)
            .frame(width: 34, height: 34)
            .background(
                Circle().fill(active ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary)))
    }
}
