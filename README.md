# AudioAnchor

A tiny, open-source macOS menu bar app that keeps your **preferred audio input and
output devices** as the system default — no matter what macOS tries to do when you
plug things in or out.

It's a free, [MIT-licensed](LICENSE) clone of the idea behind apps like *SoundAnchor*.
You set a priority order for your speakers/headphones and microphones; AudioAnchor
makes sure the highest-priority *connected* device is always the default.

> The classic annoyance: you connect AirPods and macOS switches your input to the
> AirPods' awful mic, tanking the audio quality. AudioAnchor pins your real mic back.

## Features

- 🎚️ **Priority-based auto-switching** — rank devices; the top connected one wins.
- 🎧 **Separate input & output lists**, each with its own auto-switch toggle.
- 🧠 **Device memory** — remembers devices even while unplugged, so you can pre-rank them.
- 🖱️ **Click to activate** a device now (it jumps to the top of the list).
- 🚀 **Launch at login** (via `SMAppService`).
- 🪶 Native Swift / SwiftUI, lives entirely in the menu bar. macOS 13+.

## Install

### Homebrew (once released)

```sh
brew tap danielmeint/tap
brew install --cask audioanchor
```

### Build from source

Requires Xcode 15+ (Swift 5.9+) on macOS 13+.

```sh
git clone https://github.com/danielmeint/audioanchor.git
cd audioanchor
./build.sh --run        # builds dist/AudioAnchor.app and launches it
```

## How it works

`CoreAudioService` wraps the CoreAudio HAL: it enumerates devices
(`kAudioHardwarePropertyDevices`), reads channel counts to classify input/output, and
gets/sets the default device (`kAudioHardwarePropertyDefaultOutputDevice` /
`…DefaultInputDevice` / `…DefaultSystemOutputDevice`). It registers property listeners
so the app reacts the instant a device is connected, removed, or the default changes.

`AudioManager` holds the priority lists (persisted in `UserDefaults`, keyed by the
device **UID** so they survive reconnects) and, on every change, forces the
highest-priority connected device to be the default when auto-switch is on.

```
Sources/AudioAnchor/
├── AudioAnchorApp.swift    # @main, MenuBarExtra scene
├── AudioDevice.swift       # models + AudioDirection (CoreAudio scope/selector mapping)
├── CoreAudioService.swift  # CoreAudio HAL wrapper
├── AudioManager.swift      # state, persistence, priority/switching logic
├── LoginItem.swift         # launch-at-login (SMAppService)
└── Views.swift             # SwiftUI menu UI
```

## Releasing (signed + notarized)

GUI apps distributed outside the App Store must be Developer ID–signed and notarized,
or Gatekeeper blocks them (Homebrew quarantines casks by default). Once you have an
Apple Developer account:

```sh
SIGN_ID="Developer ID Application: Your Name (TEAMID)" ./build.sh --universal
# then: notarytool submit (zip) --wait, and staple the ticket, then ship the zip + cask
```

A starter cask lives in [`Casks/audioanchor.rb`](Casks/audioanchor.rb).

## License

MIT — see [LICENSE](LICENSE). Built fresh, with
[tobi/AudioPriorityBar](https://github.com/tobi/AudioPriorityBar) and
[deweller/switchaudio-osx](https://github.com/deweller/switchaudio-osx) as references.
