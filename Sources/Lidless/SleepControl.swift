import Foundation

/// Switches `pmset -a disablesleep` on and off. This is the only privileged thing Lidless does.
///
/// Default: macOS asks for an administrator password on every switch.
/// Opt-in: a sudoers rule limited to the two exact pmset commands, so no password is needed.
enum SleepControl {
    /// No dot in the name: sudo skips files in sudoers.d whose name contains one.
    static let sudoersPath = "/etc/sudoers.d/lidless"

    static var isPasswordlessInstalled: Bool {
        FileManager.default.fileExists(atPath: sudoersPath)
    }

    /// Blocking; call off the main thread. Returns true when the system ends up in the requested state.
    static func setSleepDisabled(_ disabled: Bool, allowPrompt: Bool) -> Bool {
        let value = disabled ? "1" : "0"
        if isPasswordlessInstalled {
            runProcess("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", value])
            if SystemPower.isSleepDisabled == disabled { return true }
        }
        guard allowPrompt else { return false }
        let prompt = disabled
            ? String(localized: "Lidless wants to keep your Mac awake with the lid closed.")
            : String(localized: "Lidless wants to restore normal sleep.")
        runAsAdmin("/usr/bin/pmset -a disablesleep \(value)", prompt: prompt)
        return SystemPower.isSleepDisabled == disabled
    }

    /// Blocking. Installs the sudoers rule after `visudo` has checked it.
    static func installPasswordless() -> Bool {
        let user = NSUserName()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard !user.isEmpty, user.unicodeScalars.allSatisfy(allowed.contains) else { return false }
        let rule = """
        # Installed by Lidless. Lets this user switch lid-closed sleep on and off without a password.
        # Remove it from Lidless > Settings, or delete this file.
        \(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1

        """
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("lidless-sudoers-\(UUID().uuidString)")
        do { try rule.write(to: temp, atomically: true, encoding: .utf8) } catch { return false }
        defer { try? FileManager.default.removeItem(at: temp) }
        let file = shellQuoted(temp.path)
        runAsAdmin(
            "/usr/sbin/visudo -cf \(file) && /usr/bin/install -m 0440 -o root -g wheel \(file) \(sudoersPath)",
            prompt: String(localized: "Lidless wants to switch AI mode without asking for your password each time.")
        )
        return isPasswordlessInstalled
    }

    /// Blocking.
    static func removePasswordless() -> Bool {
        runAsAdmin(
            "/bin/rm -f \(sudoersPath)",
            prompt: String(localized: "Lidless wants to remove its no-password rule.")
        )
        return !isPasswordlessInstalled
    }

    private static func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptQuoted(_ text: String) -> String {
        "\"" + text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    @discardableResult
    private static func runAsAdmin(_ command: String, prompt: String) -> Bool {
        let script = "do shell script \(appleScriptQuoted(command)) "
            + "with prompt \(appleScriptQuoted(prompt)) with administrator privileges"
        return runProcess("/usr/bin/osascript", ["-e", script]) == 0
    }
}
