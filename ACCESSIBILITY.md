# Accessibility

MagicClick exists to make the Magic Mouse easier to use. We want it to work for people with different abilities, including people who cannot do multi-finger gestures.

## Our commitment

- Every feature has a way to use it that does not need a hard gesture.
- The settings window is built to work with VoiceOver, Full Keyboard Access, larger text, and Increase Contrast.
- We treat accessibility problems as bugs, not as feature requests.

## Supported environments

- macOS 14 Sonoma or later, on Apple Silicon and Intel Macs
- Built for VoiceOver, Full Keyboard Access, Voice Control, Increase Contrast, Reduce Motion, and light and dark appearance. We have not tested every combination yet, so please [report](#report-a-barrier) anything that does not work.
- Magic Mouse (all models). The trackpad and other mice are supported for some features.

## Alternatives to gestures

| Feature | Gesture | Way without the gesture |
| --- | --- | --- |
| Middle click | Click with 3 fingers | Choose **any keyboard key** as the middle button. This includes a single modifier key, an F-key, or a media key. Hold the key to hold the middle button. |
| Middle click | Click with 3 fingers | Turn on **Tap with fingers**, so you do not need to press the mouse |
| Middle click | Click with 3 fingers | Use **button 4 or 5** on another mouse |
| Left click while right is held | Hold right, touch the left half | Use a mouse with two physical buttons. MagicClick does not get in the way. |

With **Number of fingers** you can choose 2, 3 or 4 fingers. Fewer fingers is easier to do. More fingers gives fewer accidental clicks.

## How the app supports assistive technology

- The settings window uses standard macOS controls, so VoiceOver reads every switch, picker and button with its name and its description.
- The live mouse drawing has a VoiceOver label. It reads the number of fingers on the mouse and which buttons are down, for example *"2 fingers on the mouse, right button held, left button pressed"*.
- Text uses system fonts and colors, so it follows your text size, contrast and appearance settings.
- The menu bar menu is a standard macOS menu, so it works with VoiceOver and Full Keyboard Access.

## Known limitations

- **The live view shows finger positions only as a picture.** VoiceOver reads a summary, not the exact position of each finger.
- **The chord click needs a two-finger action** on the Magic Mouse. There is no keyboard way to do it yet.
- **The key recorder needs a real key press.** Voice Control cannot press a key for you while the recorder waits.
- **Colors have meaning in the live view** (blue = left, orange = right, purple = middle). The LEFT, RIGHT and MIDDLE badges say the same thing in text.

## Report a barrier

If something in MagicClick is hard or impossible for you to use, please tell us:

- Open an issue with the **Bug report** template and add "Accessibility" to the title, or
- Email **razvantanase@me.com** with "MagicClick accessibility" in the subject.

Tell us what you tried to do, which assistive technology you use, and your macOS version. We reply within 7 days.
