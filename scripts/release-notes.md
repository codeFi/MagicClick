Middle click, left-click-while-right-held, pinch to zoom and rotate for the Apple Magic Mouse.

## New in 1.1.1

- **Zoom and rotate no longer fight.** Fingers on the curved mouse change their spacing while they turn, so in 1.1.0 a turn also zoomed and the rotation could spring back. Now MagicClick splits the movement into a spread part and a turn part. The larger part starts first. The other joins only when you clearly do it too.
- **Zoom and rotate together**, like on the trackpad: turn and spread at the same time.
- Distances and angles use the real size of the touch surface.
- The live view shows **ZOOM + ROTATE** when both run.
- Fixed a crash that could happen if the mouse reported the same finger twice.

1.1.0 added **pinch to zoom** and **rotate** with two fingers, at the pointer.

**Updating?** Quit MagicClick, replace the app, and do the first-open steps again. Then go to **System Settings → Privacy & Security → Accessibility**, remove MagicClick with **–**, and turn it on again. See [README → Updating](https://github.com/codeFi/MagicClick#updating).

## Install

1. Download **MagicClick-1.1.1.dmg** below.
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

- **Middle click** with a 3-finger click (or 2 or 4), an optional 3-finger tap, any keyboard key (F-keys, media keys, fn, right ⌘ ⌥ ⌃ ⇧), or button 4/5 on other mice
- **Left click while the right button is held:** hold right, touch the left half of the mouse
- **Pinch to zoom and rotate** with two fingers, at the pointer
- **Live view** of your fingers with LEFT / RIGHT / MIDDLE / ZOOM / ROTATE badges
- Open at login, pause from the menu bar, works after sleep and reconnecting

Universal app for Apple Silicon and Intel. Needs macOS 14 or later.

The app is signed ad hoc and not notarized. You can check the code and build it yourself, see [Build from source](https://github.com/codeFi/MagicClick#build-from-source).
