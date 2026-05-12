# haptic-bridge

The iOS Simulator silently eats every haptic you fire. `UIImpactFeedbackGenerator`, `UISelectionFeedbackGenerator`, `UINotificationFeedbackGenerator` — all no-ops. Same for `CHHapticEngine`. Apple's been told about it since 2016 (rdar://28788551, still open) and the workaround has always been "plug a phone in."

That's annoying. So this is a small thing that gets you halfway there: it intercepts the simulator's silent haptic calls and replays a rough approximation on your Mac's Force Touch trackpad. You click around your simulator app and feel a tick where you should, on the same trackpad your hand is already resting on. Not great fidelity — the trackpad just doesn't have it — but enough to catch "oh I forgot to wire a haptic on this button" during dev without grabbing a device.

## How it works

Two pieces:

- **`HapticBridge`** — a Swift package you drop into your iOS target. On launch you call `HapticBridge.install()`. In simulator builds it swizzles the three feedback generator methods, captures every call, and fires a tiny JSON POST at `127.0.0.1:49374`. On device, on Catalyst, in release builds — it's a no-op.
- **`haptic-bridge-host`** — a small Mac CLI that listens on that port and replays the event using `NSHapticFeedbackManager`.

The mapping has to be lossy. iOS gives you five impact styles, three notification types, plus arbitrary Core Haptics curves. The trackpad gives you `.generic`, `.alignment`, and `.levelChange`. So `.heavy` and `.rigid` become a double-tap on `.generic`, `.light` and `.soft` become a single `.alignment`, `notification(.error)` becomes a triple-tap, and so on. You won't feel an AHAP curve. You will feel something fire in the right place at the right time.

## Setup

### Build the Mac host once

```sh
git clone https://github.com/MobileMage/haptic-bridge.git
cd haptic-bridge
swift build -c release
cp .build/release/haptic-bridge-host /usr/local/bin/
```

### Run it while you're developing

```sh
haptic-bridge-host --verbose
```

Leave it in a terminal tab. It logs every event it gets. If your machine has a Force Touch trackpad, you'll feel them. If it doesn't, you'll just see the log.

### Add the package to your iOS app

```swift
dependencies: [
    .package(url: "https://github.com/MobileMage/haptic-bridge.git", from: "0.1.0"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "HapticBridge", condition: .when(platforms: [.iOS])),
        ]
    )
]
```

### Call install() somewhere early

```swift
import HapticBridge

@main
struct MyApp: App {
    init() {
        #if DEBUG
        HapticBridge.install()
        #endif
    }
    // ...
}
```

Every existing `UIImpactFeedbackGenerator().impactOccurred()` and friends now also fire the trackpad. You don't have to change any call sites.

## Manual events

If you want to fire something without going through UIKit's generators (handy when poking at Core Haptics or testing the bridge itself):

```swift
HapticBridge.fire(.impact(.heavy))
HapticBridge.fire(.selection)
HapticBridge.fire(.notification(.error))
HapticBridge.fire(.coreHaptic(intensity: 0.8, sharpness: 0.4))
```

You can also smoke-test the host without an iOS project at all:

```sh
curl -X POST http://127.0.0.1:49374/haptic \
  -H 'Content-Type: application/json' \
  -d '{"type":"impact","style":"heavy"}'
```

## Mapping

| iOS call                                  | Mac trackpad                              |
| ----------------------------------------- | ----------------------------------------- |
| `impactOccurred()` with `.light` / `.soft`  | `.alignment`                              |
| `impactOccurred()` with `.medium`           | `.generic`                                |
| `impactOccurred()` with `.heavy` / `.rigid` | `.generic` × 2                            |
| `selectionChanged()`                      | `.alignment`                              |
| `notificationOccurred(.success)`          | `.alignment` × 2                          |
| `notificationOccurred(.warning)`          | `.levelChange`                            |
| `notificationOccurred(.error)`            | `.generic` × 3                            |
| `.coreHaptic(intensity:sharpness:)` manual call | bucketed `.alignment` / `.levelChange` / `.generic` by intensity |

Change `Sources/HapticBridgeHost/HapticPlayer.swift` if you want a different feel — there's nothing magical about my choices, I just picked combinations that read distinctly from each other on my own MacBook.

## What this isn't

- **Not a Core Haptics emulator.** AHAP files, intensity/sharpness curves, and `CHHapticEngine` continuous events aren't replayed faithfully. The trackpad has three patterns, that's the ceiling. Use this for sanity-checking that calls fire, not for designing how a haptic should feel.
- **Not a substitute for a real device.** If you're tuning a haptic for feel, plug in your phone. This is for "did I remember to call it?"
- **Not for production.** Wrap `install()` in `#if DEBUG` and forget about it. The swizzles only do anything inside the simulator anyway, but it's still a debug-only thing.

## Why I built it

Most of the time when I'm working on haptics in an iOS app, what I actually want to know is "did the call happen on this tap" — not "what does this haptic feel like." Round-tripping to a real device every time I want to verify that first question is slow. This handles it and stays out of the way for the second.

## Credits

- [lapfelix/ForceTouchVibrationCLI](https://github.com/lapfelix/ForceTouchVibrationCLI) — proves you can drive the trackpad from a CLI in about ten lines of Swift.
- [niw/HapticKey](https://github.com/niw/HapticKey) — full menu-bar app around `NSHapticFeedbackManager`. Worth reading for the AppKit details.
- rdar://28788551 — Apple radar from 2016 asking for simulator haptics. Still open in 2026.

## License

MIT. See [LICENSE](LICENSE).
