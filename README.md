<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="MagicClick icon">
</p>

<h1 align="center">MagicClick</h1>

<p align="center">
  <b>Middle click, chord click, pinch to zoom and rotate for the Apple Magic Mouse.</b><br>
  A tiny, free and open-source menu bar app for macOS.
</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-blue">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6-orange">
  <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-green">
</p>

---

The Magic Mouse has one physical button. macOS looks at where your finger is and decides if a press is a left or a right click. That leaves two gaps:

1. **There is no middle click.** You need it to open links in a new tab, close tabs, paste on Linux machines over remote desktop, pan in Blender, CAD and map apps, and more.
2. **You cannot left-click while you hold the right button.** The button is already down, so a second press is impossible. Games and some pro apps need this "chord".

MagicClick fixes both. It reads your fingers on the touch surface of the mouse and turns the right gestures into the right clicks.

<p align="center">
  <img src="docs/demo.gif" width="640" alt="MagicClick demo: a 3-finger middle click, a left click while the right button is held, then two-finger zoom and rotate">
</p>

<p align="center">
  <img src="docs/screenshot.png" width="580" alt="MagicClick settings window">
</p>

## Features

### Middle click
- **Click with fingers** – Press the mouse with 3 fingers on it (2, 3 or 4, you choose). Hold and move to middle-drag.
- **Tap with fingers** – Optional. Tap with 3 fingers without pressing.
- **Keyboard key** – Pick any key to act as the middle button. Hold the key and move the mouse to middle-drag. It works with:
  - normal keys and shortcuts, for example `F13` or `⌥F5`
  - a modifier on its own, for example **Right ⌥ Option**, **Right ⌘ Command** or **fn / 🌐**
  - media and special keys, for example **Play/Pause**, **Mute** or **Volume Up**
  - Mission Control, Spotlight, Dictation and other top-row keys
- **Extra mouse button** – For other mice: turn button 4 or button 5 into a middle click.
- **Also on trackpad** – Optional. Use the same finger click and tap on your trackpad.

### Left click while the right button is held
Hold the right click. Then touch the **left half** of the mouse with another finger. MagicClick sends a left button press. The left button stays down until you lift that finger, so you can click or hold.

Fingers that were already on the mouse when you pressed the right button are ignored. A finger that lands on the right half is ignored too, even if it slides left.

### Pinch to zoom and rotate
- **Zoom** – Move two fingers apart or together on the mouse, like a pinch on the trackpad. It works in Safari, Preview, Photos, Maps, most browsers and other apps that support trackpad pinch.
- **Rotate** – Turn two fingers on the mouse, like turning a dial. It works in Maps, Preview, Photos and other apps that support trackpad rotation.

MagicClick sends the same gesture events that a trackpad sends, so apps zoom and rotate **where the pointer is**. A gesture is a zoom or a rotation, not both: the first clear movement decides.

Two fingers that slide the same way still scroll or swipe as usual. During a gesture, the mouse does not scroll the page.

### The rest
- **Live view** – The settings window shows your fingers on the mouse in real time. Use it to learn the gestures.
- **Menu bar app** – No Dock icon. Turn it off and on from the menu bar.
- **Open at login** – One switch.
- **Double clicks work** – The clicks that MagicClick sends count as double and triple clicks when you click fast.
- **Hot-plug** – Connect or disconnect the mouse, or sleep and wake the Mac. MagicClick finds the mouse again.
- **Private** – No network access, no analytics, no data collection. Everything stays on your Mac.

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon or Intel Mac
- Magic Mouse or Magic Mouse 2 (USB-C models too). Trackpad support is optional.

## Download

1. Download **`MagicClick-x.y.z.dmg`** from the [latest release](https://github.com/codeFi/MagicClick/releases/latest).
2. Open the DMG and drag **MagicClick** into the **Applications** folder.
3. Do the [first open](#first-open) steps below. You do this only one time.

### First open

MagicClick is free and open source, but it is **not notarized** by Apple. Notarization is a paid Apple check. Without it, macOS blocks the app the first time you open it. You allow it one time, like this:

1. Open **MagicClick** from the Applications folder. macOS says *"MagicClick" Not Opened* or *Apple could not verify "MagicClick"*. Click **Done**. Do not click *Move to Trash*.
2. Open the Apple menu → **System Settings** → **Privacy & Security**.
3. Scroll down to the **Security** section. You see *"MagicClick" was blocked to protect your Mac.* Click **Open Anyway**.
4. Enter your password or use Touch ID. Then click **Open Anyway** again in the dialog.
5. MagicClick opens and shows its settings window. Click **Open Accessibility Settings** and turn on **MagicClick** in the list. MagicClick needs this permission to change clicks. The window updates by itself when the permission is on.
6. Look for the mouse icon in the menu bar. Click it and choose **Settings…** to change anything.

> **Do you not see "Open Anyway"?** It shows only for about an hour after you try to open the app. Do step 1 again, then go back to Privacy & Security.

**Or use Terminal instead of steps 1–4.** This removes the "downloaded from the internet" mark from the app:

```bash
xattr -dr com.apple.quarantine /Applications/MagicClick.app
```

Then open MagicClick and do step 5.

### Updating

1. Quit MagicClick from the menu bar.
2. Drag the new version into Applications, and choose **Replace**.
3. Do the [first open](#first-open) steps again.
4. Go to **System Settings → Privacy & Security → Accessibility**. Select **MagicClick**, click the **–** button to remove it, then open MagicClick and turn the permission on again. The download is signed *ad hoc*, so macOS sees each version as a new app.

### Is it safe?

The whole source code is in this repo. MagicClick has no network access and collects no data. The DMG is built from this code with [`scripts/make-dmg.sh`](scripts/make-dmg.sh). If you do not want to trust a download, [build it yourself](#build-from-source). It takes about a minute.

## Build from source

1. Install the Xcode Command Line Tools if you do not have them:

   ```bash
   xcode-select --install
   ```

2. Get the code and build the app:

   ```bash
   git clone https://github.com/codeFi/MagicClick.git
   cd MagicClick
   ./scripts/build.sh install
   ```

   This builds `MagicClick.app`, copies it to `~/Applications`, and opens it. An app you build yourself is not blocked by macOS, so you can skip the first open steps.

3. Give MagicClick **Accessibility** permission. The settings window shows a button for this. You can also go to **System Settings → Privacy & Security → Accessibility** and turn on **MagicClick**. The window updates by itself when the permission is on.

4. Look for the mouse icon in the menu bar. Click it and choose **Settings…** to change anything.

To make the DMG yourself, run `./scripts/make-dmg.sh`. It writes `build/MagicClick-<version>.dmg`.

### Keep the permission across rebuilds

macOS ties the Accessibility permission to the app's code signature. The build script signs the app *ad hoc* by default. An ad hoc signature changes on each build, so after a rebuild you must turn the permission off and on again.

If you have an Apple developer certificate, sign with it and the permission stays:

```bash
security find-identity -v -p codesigning     # list your certificates
SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" ./scripts/build.sh install
```

## How to use it

| You want | Do this |
| --- | --- |
| Middle click | Press the mouse with 3 fingers on it |
| Middle drag | Press with 3 fingers, hold, and move |
| Middle click without pressing | Turn on **Tap with fingers**, then tap with 3 fingers |
| Middle click from the keyboard | Set a **Keyboard key**, then press it |
| Middle drag from the keyboard | Hold the key and move the mouse |
| Left click while right is held | Hold right click, then touch the left half with another finger |
| Zoom in or out | Move two fingers apart or together on the mouse |
| Rotate | Turn two fingers on the mouse |
| Pause MagicClick | Menu bar icon → **Enabled** |

### Tips
- **Too easy to trigger by accident?** Set **Number of fingers** to 4.
- **3 fingers feel crowded on the mouse?** Set it to 2. Note that 2 fingers then always give a middle click.
- **The fn / 🌐 key opens the emoji picker** or starts dictation. Go to **System Settings → Keyboard** and set *Press 🌐 key to* **Do Nothing**.
- **Media keys** on a Mac keyboard work only while they act as media keys. If you set *Use F1, F2, etc. keys as standard function keys*, record the F-key instead.

## How it works

MagicClick has four parts:

1. **Touch reader** (`Multitouch.swift`). It loads Apple's private `MultitouchSupport` framework at run time and gets a callback about 100 times a second with the position of each finger. It tells the Magic Mouse apart from trackpads by the device family ID.
2. **Event tap** (`Engine.swift`). A `CGEventTap` sees every mouse and keyboard event before apps do. When you press the mouse and 3 or more fingers are on it, the tap changes the event into a middle-button event. When your chosen key goes down or up, the tap removes the key event and sends a middle-button event instead.
3. **Chord logic** (`Engine.swift`). When the right button goes down, MagicClick remembers which fingers are on the mouse. A *new* finger on the left half sends a left button press. Lifting that finger sends the release.
4. **Zoom and rotate** (`Engine.swift`). When two fingers move apart or together, MagicClick sends a zoom gesture event at the pointer. When they turn, it sends a rotation gesture event. These are the same private event types that the trackpad driver sends. While a gesture runs, the tap drops the mouse's own scroll events.

Events that MagicClick sends carry a marker, so its own tap lets them through and never loops.

### Project layout

```
Sources/MagicClick/
  main.swift          App entry point
  AppDelegate.swift   Menu bar item, settings window, permission checks
  AppModel.swift      Saved settings and live status for the UI
  Engine.swift        Event tap, middle click, chord click, key trigger, zoom and rotate
  Multitouch.swift    Reads fingers from MultitouchSupport.framework
  KeyTrigger.swift    Keyboard trigger model and key names
  SettingsView.swift  SwiftUI settings window
scripts/
  build.sh            Builds, signs and installs the .app
  make-dmg.sh         Builds the DMG for a GitHub release
  release.sh          Signed and notarized build (needs a Developer ID)
  make-gif.swift      Turns demo frames into the README GIF
  make-icon.swift     Draws the app icon
Resources/
  Info.plist
  AppIcon.icns
```

### Build for development

```bash
swift build                     # debug build
swift build -c release          # release build
./scripts/build.sh              # release .app in build/, no install
```

## Troubleshooting

**Nothing happens when I click with 3 fingers.**
- Check that the menu bar menu says *Active*.
- Open **Settings…** and look at the live view. If you see no fingers when you touch the mouse, MagicClick does not get touch data. Choose **Quit** and open the app again.
- Check the Accessibility permission. If you rebuilt the app, turn the permission off and on again.

**The live view shows no Magic Mouse.**
Turn the mouse off and on, or connect it with the cable. MagicClick restarts its touch reader when a device connects. You can also quit and open the app again.

**I removed the permission and now the mouse is stuck.**
macOS can freeze input when an app loses Accessibility while its event tap is active. Quit MagicClick from the menu bar, or press `⌘⌥⎋` and force quit it.

**A macOS update broke it.**
`MultitouchSupport` is a private Apple framework. Apple can change it without notice. Please [open an issue](https://github.com/codeFi/MagicClick/issues) with your macOS version.

## Limits

- The Magic Mouse cannot report a second physical press while the button is down. The chord left click uses a **touch**, not a press, for this reason.
- Zoom and rotate work only in apps that support the trackpad gestures. Apps that zoom only with `⌘+` and `⌘−` do not respond to them.
- Rotation starts after the fingers turn about 15°, so small movements of resting fingers do nothing.
- For 2 seconds after a zoom or rotation, MagicClick drops leftover scroll momentum. A scroll wheel on another mouse is also ignored in that time.
- MagicClick uses a private framework, so it can never be on the Mac App Store.
- The app is not sandboxed. An event tap that changes events cannot run in the App Sandbox.

## Contributing

Bug reports, ideas and pull requests are welcome. Read the [contributing guide](CONTRIBUTING.md) to get started.

- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Security policy](SECURITY.md): report security problems privately
- [Accessibility](ACCESSIBILITY.md): alternatives to gestures and known limits

## Credits

Inspired by [MiddleClick](https://github.com/artginzburg/MiddleClick), which showed that the Magic Mouse touch surface can drive a middle click. MagicClick is a new app written from scratch.

## License

[MIT](LICENSE) © 2026 Razvan Tanase
