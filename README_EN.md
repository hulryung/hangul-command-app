# Hangul Key Changer

A lightweight macOS utility that lets you use the **Right Command key** (or any key) to toggle Korean/English input — just like the dedicated key on a Windows keyboard.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/License-MIT-green)

> [한국어 README](README.md)

<p align="center">
  <img src="screenshot.png" alt="Hangul Key Changer" width="400">
</p>

## Why?

Switching between Korean and English on macOS has always been awkward:

- **Caps Lock** has noticeable input delay and you lose its original function
- **Fn key** placement varies by keyboard and feels unnatural
- If you're used to **Windows keyboards**, you expect a dedicated toggle key on the right side

The common workaround is [Karabiner-Elements](https://karabiner-elements.pqrs.org/), which requires installing a kernel-level driver and writing complex JSON rules.

**Hangul Key Changer** takes a different approach — it uses only the built-in macOS `hidutil` command. No drivers, no kernel extensions, no background daemons. Lightweight and safe.

## Features

- **Remap any key** — Right Command, Caps Lock, or any key of your choice
- **One-click setup** — A single button configures both key mapping and system shortcut
- **Persists after reboot** — LaunchAgent applies the mapping at login (no app needed)
- **Menu bar control** — Quick access from the status bar
- **Bilingual UI** — Korean and English, follows system language

## Install

### Homebrew (Recommended)

```bash
brew install hulryung/tap/hangulkeychanger
```

### DMG Download

Download the latest DMG from [Releases](https://github.com/hulryung/HangulKeyChanger/releases), open it, and drag the app to `/Applications`.

The app is signed with Developer ID and notarized by Apple — no security warnings.

## Usage

1. Launch the app
2. Click **Change** to pick your toggle key (default: Right Command)
3. Click **Enable** and enter your admin password
4. Done — the selected key now toggles Korean/English input

<p align="center">
  <code>Right Command ⌘</code> → Input source toggle
</p>

## Uninstall

1. Click **Disable** in the app to remove the key mapping
2. Delete the app

If installed via Homebrew:
```bash
brew uninstall hangulkeychanger
```

## How It Works

Hangul Key Changer operates in three steps:

1. **Key remapping**: Uses macOS built-in `hidutil` to remap your chosen key to F18
2. **System shortcut**: Sets the "Select previous input source" shortcut to F18 via symbolic hotkeys
3. **Persistence**: Registers a LaunchAgent in `/Library/LaunchAgents` so the mapping survives reboots

No external drivers or kernel extensions. No background daemon running. Just native macOS mechanisms.

### Tech Stack

- **Language**: Swift 5
- **UI Framework**: AppKit (pure Cocoa, no SwiftUI)
- **Key Mapping**: `hidutil` (HID Usage Table)
- **Persistence**: LaunchAgent
- **Requirements**: macOS 14.0 Sonoma or later
- **Signing**: Developer ID + Apple Notarization

## Build from Source

```bash
git clone https://github.com/hulryung/HangulKeyChanger.git
cd HangulKeyChanger
xcodebuild -scheme HangulCommandApp build
```

## License

[MIT](LICENSE)

---

<div align="center">

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-☕-yellow)](https://buymeacoffee.com/hulryung)

</div>
