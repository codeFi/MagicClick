Middle click, left-click-while-right-held, pinch to zoom, rotate and a pointer spotlight for the Apple Magic Mouse.

## New in 1.2.0

- **Spotlight.** The screen gets darker, except a soft circle around the pointer, so people can follow it in a demo, a recording or a call. Or choose a **Ring** around the pointer. Set the size, opacity, soft edge and color, and choose the displays.
- **Pulse on click.** A ring grows on each click: blue left, orange right, purple middle. It also shows the middle and chord clicks that MagicClick makes.
- **On/off key and Hold key** for the spotlight. The menu bar menu has a **Spotlight** item too.
- **Screenshots and recordings show the spotlight** as you see it. While you drag an area with `⌘⇧4`, it stays still. When you pick one window with `⌘⇧4` and Space, it gets out of the way.
- **Window screenshot key.** Saves one window **with** the spotlight on top, without the cursor. Needs the Screen Recording permission.
- **Key combinations.** Every key setting takes up to 3 keys together, for example `⌃⌥S`, or only modifiers like `⌃⌥`.
- The settings window fades its content under the window buttons.
- New README guide: [Use the spotlight](https://github.com/codeFi/MagicClick#use-the-spotlight), with fixes for common screenshot and recording problems.

1.1.x added **pinch to zoom** and **rotate** with two fingers, at the pointer.

**Updating?** Quit MagicClick, replace the app, and do the first-open steps again. Then go to **System Settings → Privacy & Security → Accessibility**, remove MagicClick with **–**, and turn it on again. See [README → Updating](https://github.com/codeFi/MagicClick#updating).

## Install

1. Download **MagicClick-1.2.0.dmg** below.
2. Open it and drag **MagicClick** into **Applications**.
3. Open MagicClick. macOS blocks it the first time, because the app is not notarized. Click **Done**.
4. Go to **System Settings → Privacy & Security**, scroll to **Security**, and click **Open Anyway** next to *"MagicClick" was blocked*. Enter your password and click **Open Anyway** again.
5. In the MagicClick window, click **Open Accessibility Settings** and turn on **MagicClick**.

Prefer Terminal? Instead of steps 3–4, run:

```bash
xattr -dr com.apple.quarantine /Applications/MagicClick.app
```

Full guide: [README → Download](https://github.com/codeFi/MagicClick#download)

## What's inside

- **Middle click** with a 3-finger click (or 2 or 4), an optional 3-finger tap, any key or combination of up to 3 keys, or button 4/5 on other mice
- **Left click while the right button is held:** hold right, touch the left half of the mouse
- **Pinch to zoom and rotate** with two fingers, at the pointer
- **Spotlight or ring** around the pointer, with click pulses, keys, and a window screenshot key
- **Live view** of your fingers with LEFT / RIGHT / MIDDLE / ZOOM / ROTATE badges
- Open at login, pause from the menu bar, works after sleep and reconnecting

Universal app for Apple Silicon and Intel. Needs macOS 14 or later.

The app is signed ad hoc and not notarized. You can check the code and build it yourself, see [Build from source](https://github.com/codeFi/MagicClick#build-from-source).
