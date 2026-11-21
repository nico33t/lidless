# Lidless

**Close the lid. Your AI agents keep working.**

Lidless is a small, native macOS menu bar app for people who build with AI agents.
Close your MacBook and long-running agents, builds and terminals keep going, while the
screen goes dark and the speakers go quiet. It also has a cleaning mode that locks the
keyboard and trackpad so you can wipe them down.

Written in Swift and SwiftUI. No Electron, no background services, no network access.

[**Download the latest version**](https://github.com/nico33t/lidless/releases/latest) · macOS 14 Sonoma or later · Apple Silicon and Intel

*Italiano più sotto.*

---

## Features

### AI mode
- **One switch** keeps the Mac awake with the lid closed. Under the hood it is the same
  `sudo pmset -a disablesleep 1` you would type in Terminal, and `0` to turn it off.
- **Always truthful.** The switch reads the real system state, so it stays correct even if
  you change the setting from Terminal.
- **Lid closed:** the screen turns off and sound is muted. Both come back when you open the lid.
- **External display connected?** Lidless leaves sound and screen alone, so clamshell desk
  setups work as usual.
- **Battery cut-off:** AI mode switches itself off below a battery level you pick, so the Mac
  can sleep before it runs flat.
- **Restore on quit:** quitting Lidless puts normal sleep back (can be turned off).

### Fade while lowering the lid
On MacBooks with a lid angle sensor, brightness and volume follow the lid down as you close it,
and come back when you lift it.
- Choose **never**, **only in AI mode** or **always**.
- Fade brightness, volume, or both.
- Set the angle where fading starts and the lowest level it reaches.

### Cleaning mode
- Every screen goes black, and keyboard, trackpad and mouse are locked.
- Countdown of 30 seconds to 3 minutes (2 minutes by default).
- Press **⌘ esc** to leave early.
- **Full lock** with the Accessibility permission. Without it, a lighter lock is used and
  brightness and media keys still respond.
- **Safety net:** input always comes back at the end of the countdown, even if something goes wrong.

Every option can be changed in **Settings**, and each mode works on its own. You can use Lidless
only for cleaning, or use AI mode without any fading or muting.

## Install

1. Download `Lidless-<version>.zip` from [Releases](https://github.com/nico33t/lidless/releases/latest) and unzip it.
2. Move **Lidless.app** to **Applications**.
3. Open it. It lives in the menu bar (laptop icon), not in the Dock.

> **First launch.** Current builds are not yet notarized by Apple, so macOS may say it cannot
> check the app. Right-click **Lidless.app** and choose **Open**, or go to
> **System Settings › Privacy & Security** and click **Open Anyway**. Notarized builds are planned.

### Permissions

| What | Why | When it is asked |
|---|---|---|
| Administrator password | `pmset -a disablesleep` needs it | Each time you flip AI mode, unless you turn on switching without a password |
| Accessibility | Full keyboard and trackpad lock during cleaning | Only if you click **Allow** in Settings |

### Switching without a password (optional)

In **Settings › Password** you can let Lidless switch AI mode without asking every time.
It installs `/etc/sudoers.d/lidless`, checked with `visudo` first, which allows **only** these
two commands for your user:

```
/usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -a disablesleep 1
```

Turn the option off to remove the file. You can also remove it yourself:

```sh
sudo rm /etc/sudoers.d/lidless
```

The battery cut-off needs this option, because nobody may be at the Mac to type a password.

## Good to know

- **Heat.** A closed MacBook dissipates heat less well. Avoid leaving it in a bag with AI mode on.
- **Battery.** With the lid closed and AI mode on, the Mac keeps using power. Use the battery
  cut-off, or keep it plugged in.
- **Manual reset.** If anything is ever left in the wrong state, this restores normal sleep:
  ```sh
  sudo pmset -a disablesleep 0
  ```

## Build from source

Requires Xcode 15 or later (Swift 5.10+).

```sh
git clone https://github.com/nico33t/lidless.git
cd lidless
./Scripts/build-app.sh      # builds build/Lidless.app
open build/Lidless.app
```

The script signs with a Developer ID or Apple Development certificate if it finds one,
otherwise ad hoc. To test cleaning mode quickly:

```sh
build/Lidless.app/Contents/MacOS/Lidless --clean-seconds 10
```

## Privacy

Lidless does not connect to the internet, collect data or include analytics. Settings are stored
locally in macOS user defaults.

## License

[MIT](LICENSE) © 2026 Nicola Tomassini

---

## Italiano

**Chiudi lo schermo. I tuoi agenti AI continuano a lavorare.**

Lidless è un'app nativa per la barra dei menu di macOS, pensata per chi sviluppa con
l'intelligenza artificiale.

- **Modalità AI:** un interruttore tiene il Mac acceso a schermo chiuso (lo stesso
  `sudo pmset -a disablesleep 1` del Terminale). A schermo chiuso il display si spegne e l'audio
  va in muto; tutto torna come prima quando lo riapri. Con un monitor esterno non tocca nulla.
  Si spegne da sola sotto la soglia di batteria che scegli.
- **Sfumatura abbassando lo schermo:** luminosità e volume scendono insieme allo schermo e
  tornano quando lo rialzi. Mai, solo in modalità AI o sempre; angolo di partenza e livello
  minimo regolabili.
- **Modalità pulizia:** schermi neri, tastiera, trackpad e mouse bloccati, conto alla rovescia,
  **⌘ esc** per uscire prima.
- **Tutto personalizzabile** dalle Impostazioni. Ogni modalità funziona da sola.

**Installazione:** scarica lo zip da [Releases](https://github.com/nico33t/lidless/releases/latest),
sposta Lidless.app in Applicazioni e aprilo. Al primo avvio, se macOS lo blocca: tasto destro ›
**Apri**, oppure **Impostazioni di Sistema › Privacy e sicurezza › Apri comunque**.

**Ripristino manuale:** `sudo pmset -a disablesleep 0`

Lingue: italiano e inglese. Licenza [MIT](LICENSE) © 2026 Nicola Tomassini.
