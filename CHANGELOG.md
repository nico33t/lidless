# Changelog

## 0.2.1 · 2026-11-21

- Build copies are kept out of Spotlight, so searching for Lidless shows only the installed app.

## 0.2.0 · 2026-11-21

- Liquid Glass design on macOS 26 and later: the main window and the menu bar popover use glass cards, with a soft backdrop that lights up when AI mode is on. Earlier macOS versions get the translucent material look.
- Main window redesigned: AI mode and Cleaning side by side at the top, options grouped below. The AI mode card also shows the battery and the live lid angle.
- New app icon: a MacBook with its lid almost shut, light spilling from the gap, and an AI sparkle above.

## 0.1.2 · 2026-11-21

- Restart, shutdown and logout no longer ask for the administrator password: AI mode stays as it is and is still on after the restart. "Restore normal sleep when quitting" now applies only when you quit Lidless yourself.

## 0.1.1 · 2026-11-21

- Main window: opening Lidless shows a window with every control and setting, and the app appears in the Dock while it is open. Before, the only way in was the menu bar icon, which can hide behind the camera notch.
- Opening Lidless again from Applications while it runs brings the window back.
- New option: show the window when Lidless opens (on by default).
- Release script for Developer ID signing and Apple notarization (`Scripts/notarize.sh`).

## 0.1.0 · 2026-11-21

First version.

- AI mode: one switch keeps the Mac awake with the lid closed (`pmset -a disablesleep`), so AI agents keep running. The switch always shows the real system state.
- Lid closed in AI mode: screen off and sound muted, both restored when the lid opens. Skipped when an external display is connected.
- Fade while lowering the lid: brightness and volume follow the lid angle down and come back when it is lifted. Never, only in AI mode, or always; start angle and lowest level adjustable.
- Cleaning mode: black screens, keyboard, trackpad and mouse locked, countdown, ⌘ esc to leave early. Full lock with the Accessibility permission, lighter lock without it.
- Optional switching without a password: a sudoers rule limited to the two pmset commands, removable from Settings.
- Battery cut-off: AI mode turns itself off below a chosen battery level (needs switching without a password).
- Normal sleep restored on quit, optional.
- English and Italian.
