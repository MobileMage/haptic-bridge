# haptic-bridge

I was wiring a haptic into a button last week. Ran the app in the simulator, tapped the button, felt nothing. Tapped it again. Still nothing. It took me longer than I want to admit to remember why.

The iOS Simulator doesn't play haptics. Never has. Every `UIImpactFeedbackGenerator`, every `UISelectionFeedbackGenerator`, every `CHHapticEngine` call gets silently dropped. The radar for it ([rdar://28788551](https://openradar.appspot.com/28788551)) was filed in 2016, and as of writing it is still open. Apple's guidance has always been the same line: use a real device. That is a fine answer when a real device is plugged in next to you. Most of the time I am heads down in the simulator and reaching for the phone every few minutes to confirm a single call broke my flow worse than the missing feedback ever did.

So I went looking. The trackpad on every MacBook since 2015 has a Taptic Engine inside it. You can drive that engine from any AppKit process with three lines on `NSHapticFeedbackManager`. People have known this for years. There are tiny CLIs out there that prove it works, like [ForceTouchVibrationCLI](https://github.com/lapfelix/ForceTouchVibrationCLI), and full menu bar apps built around it like [HapticKey](https://github.com/niw/HapticKey). What I could not find anywhere was something that wired the simulator's silent haptic calls onto the trackpad I already had my palm resting on.

This is that.

It is two pieces. The first is a Swift package you drop into your iOS target. At app launch you call `HapticBridge.install()`. In simulator builds the package swizzles the three feedback generators, captures every fire, and POSTs a small JSON event to `127.0.0.1:49374`. On device, in Mac Catalyst, in release builds, it does nothing at all. The second piece is a small Mac CLI that listens on that port and replays each event using `NSHapticFeedbackManager`. You leave it running in a terminal tab while you develop.

The mapping is lossy on purpose. iOS gives you five impact styles, three notification types, and arbitrary Core Haptics curves on top of that. The trackpad gives you exactly three patterns: `.generic`, `.alignment`, `.levelChange`. So I had to fake the rest. Heavy impacts become a `.generic` twice in quick succession. Notification errors become `.generic` three times. Successes become `.alignment` twice. The point is not to recreate the feel of a real device. The point is to feel that something fired, in the right spot, with enough distinction between patterns that you can tell them apart blindly.

## Setup

Clone and build the Mac host once.

```sh
git clone https://github.com/MobileMage/haptic-bridge.git
cd haptic-bridge
swift build -c release
cp .build/release/haptic-bridge-host /usr/local/bin/
```

Run it while you develop.

```sh
haptic-bridge-host --verbose
```

It logs every event it sees. By default it waits 35 ms before firing each haptic, so the tick lands a beat after your tap instead of stamping on top of it. Pass `--delay 0` to fire instantly, or `--delay 80` for more anticipation, or whatever feels right on your hardware.

If your Mac has a Force Touch trackpad you will feel the ticks. If it doesn't (external keyboard, a desktop Mac without a Magic Trackpad 2) the bridge still wires up, you just won't feel anything on the way out.

Add the package to your iOS app.

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

Call `install()` early in app startup.

```swift
import HapticBridge

@main
struct MyApp: App {
    init() {
        #if DEBUG
        HapticBridge.install()
        #endif
    }
}
```

Every existing `UIImpactFeedbackGenerator().impactOccurred()`, every `UISelectionFeedbackGenerator().selectionChanged()`, every `UINotificationFeedbackGenerator().notificationOccurred(_:)` now also fires the trackpad. You do not change any call sites.

## Manual events

I did not try to swizzle `CHHapticEngine`. Its API surface is too wide for a weekend project and the trackpad cannot reproduce arbitrary intensity and sharpness curves anyway. If you want a rough proxy, or if you want to test the bridge itself without going through UIKit's generators, you can fire events directly:

```swift
HapticBridge.fire(.impact(.heavy))
HapticBridge.fire(.selection)
HapticBridge.fire(.notification(.error))
HapticBridge.fire(.coreHaptic(intensity: 0.8, sharpness: 0.4))
```

You can also smoke test the host without an iOS project at all:

```sh
curl -X POST http://127.0.0.1:49374/haptic \
  -H 'Content-Type: application/json' \
  -d '{"type":"impact","style":"heavy"}'
```

## How calls map onto the trackpad

| iOS call                                       | Trackpad                             |
| ---------------------------------------------- | ------------------------------------ |
| `impactOccurred()` with `.light` or `.soft`    | `.alignment`                         |
| `impactOccurred()` with `.medium`              | `.generic`                           |
| `impactOccurred()` with `.heavy` or `.rigid`   | `.generic` twice in quick succession |
| `selectionChanged()`                           | `.alignment`                         |
| `notificationOccurred(.success)`               | `.alignment` twice                   |
| `notificationOccurred(.warning)`               | `.levelChange`                       |
| `notificationOccurred(.error)`                 | `.generic` three times               |
| Manual `coreHaptic(intensity:sharpness:)`      | bucketed by intensity                |

If a mapping does not feel right on your machine, change `Sources/HapticBridgeHost/HapticPlayer.swift`. There is nothing precious about my choices. I picked combinations I could tell apart blindly on a MacBook Pro and shipped those.

## Example app

There is a SwiftUI demo under `Examples/HapticBridgeExample`. It depends on the package as a local path and exposes every supported haptic as a button in a list. From the repo root:

```sh
brew install xcodegen
cd Examples/HapticBridgeExample
xcodegen generate
open HapticBridgeExample.xcodeproj
```

Run it on any iOS simulator. With the host running and your palm on the trackpad, every row turns into a tick.

## What this isn't

A Core Haptics emulator. AHAP files, sharpness curves, continuous `CHHapticEngine` events will not come through faithfully. The trackpad has three patterns. That is the whole instrument.

A substitute for a real device. If you are tuning a haptic for feel, plug your phone in. This handles the much more boring question of "did my call fire at all on this tap" so that you don't have to grab the phone for that one.

A production dependency. Wrap `install()` in `#if DEBUG` and stop thinking about it. The swizzles only take effect inside the simulator, but the spirit is still debug only.

## Credits

[ForceTouchVibrationCLI](https://github.com/lapfelix/ForceTouchVibrationCLI) was the first thing I read that proved the Taptic Engine could be driven from a CLI in about ten lines of Swift.

[HapticKey](https://github.com/niw/HapticKey) is a full menu bar app built on top of `NSHapticFeedbackManager`. Worth reading for the AppKit details.

[rdar://28788551](https://openradar.appspot.com/28788551) is the Apple radar from 2016 asking for simulator haptics. Open at time of writing.

## License

MIT. See [LICENSE](LICENSE).
