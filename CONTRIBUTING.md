# Contributing to MagicClick

Thank you for helping! Bug reports, ideas, documentation fixes and code are all welcome.

Please follow the [Code of Conduct](CODE_OF_CONDUCT.md) in all project spaces.

## Report a bug

1. Search the [issues](https://github.com/codeFi/MagicClick/issues) first. Somebody may have reported it already.
2. Open a new issue with the **Bug report** template.
3. Tell us your macOS version, your Mac, your mouse model, and the MagicClick version (shown at the bottom of the settings window).
4. Write the steps that make the bug happen. A short screen recording of the live view helps a lot.

Do not report security problems in a public issue. See [SECURITY.md](SECURITY.md).

## Suggest a feature

Open an issue with the **Feature request** template. Say what you want to do and why. A real example is better than a general idea.

## Change the code

### Set up

You need macOS 14 or later and the Xcode Command Line Tools (`xcode-select --install`). Xcode is optional.

```bash
git clone https://github.com/codeFi/MagicClick.git
cd MagicClick
swift build                    # debug build
./scripts/build.sh install     # build the .app, install it to ~/Applications and open it
```

The app needs Accessibility permission. An ad hoc build gets a new signature each time, so after each rebuild you must remove MagicClick from **System Settings → Privacy & Security → Accessibility** and add it again. To skip this, sign with your own certificate:

```bash
SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" ./scripts/build.sh install
```

### Where things are

| File | What it does |
| --- | --- |
| `Multitouch.swift` | Reads finger positions from the private MultitouchSupport framework |
| `Engine.swift` | Event tap: middle click, chord click, key trigger, zoom and rotate |
| `KeyTrigger.swift` | Keyboard trigger model and key names |
| `AppModel.swift` | Saved settings and live status |
| `AppDelegate.swift` | Menu bar item, settings window, screenshot and demo modes |
| `SettingsView.swift` | SwiftUI settings window |

The README has a longer [How it works](README.md#how-it-works) section.

### Rules for code

- Match the style of the code around your change: names, comments, and structure.
- Keep the app small. It has no dependencies, and we want to keep it that way.
- The event tap runs for every mouse and key event on the Mac. Keep that path fast, and do not block it.
- Data that both the event tap and the multitouch thread read must stay behind `Engine.lock`.
- Never add network access or analytics.

### Test your change

There are no automated tests for the event tap, because it needs a real mouse and real permissions. Test by hand on a real Magic Mouse:

- [ ] A normal left click and right click still work, also with a finger resting on the mouse
- [ ] A 3-finger click gives a middle click (open a link in a browser: it should open in a new tab)
- [ ] Hold right, touch the left half: the live view shows **LEFT** and **RIGHT**
- [ ] Two fingers apart or together zoom in Safari or Preview, at the pointer. Two fingers sliding the same way still scroll.
- [ ] Two fingers that turn rotate the map in Maps
- [ ] The keyboard key works, if your change touches it
- [ ] Turning MagicClick off in the menu bar gives the normal mouse behavior back

If you change the settings window, add a new screenshot:

```bash
./scripts/build.sh
build/MagicClick.app/Contents/MacOS/MagicClick --snapshot docs/screenshot.png --demo middle
```

### Send a pull request

1. Fork the repo and make a branch from `main`.
2. Make one change per pull request. Small pull requests are reviewed faster.
3. Write a clear commit message that says what changed and why.
4. Open the pull request and fill in the template.

By sending a pull request, you agree that your code is published under the [MIT License](LICENSE).
