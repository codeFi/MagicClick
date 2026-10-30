import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                HeaderView()
            }

            if !model.trusted {
                Section {
                    PermissionCard()
                }
            }

            Section {
                LivePreview()
            } header: {
                SectionTitle("Live view", symbol: "dot.radiowaves.left.and.right")
            }

            Section {
                Toggle(isOn: $model.fingerClick) {
                    Text("Click with fingers")
                    Text("Press the mouse with \(model.fingerCount) or more fingers on it.")
                }
                Toggle(isOn: $model.fingerTap) {
                    Text("Tap with fingers")
                    Text("Quickly tap \(model.fingerCount) fingers without pressing. Lift them all together.")
                }
                Picker(selection: $model.fingerCount) {
                    Text("2").tag(2)
                    Text("3").tag(3)
                    Text("4").tag(4)
                } label: {
                    Text("Number of fingers")
                    if model.fingerCount == 2 {
                        Text("⚠️ With 2, a normal left click becomes a middle click when another finger rests on the mouse.")
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!model.fingerClick && !model.fingerTap)
                Toggle(isOn: $model.includeTrackpad) {
                    Text("Also on trackpad")
                    Text("Use the same finger click and tap on the trackpad.")
                }
                .disabled(!model.fingerClick && !model.fingerTap)
            } header: {
                SectionTitle("Middle click with fingers", symbol: "hand.raised.fingers.spread")
            }

            Section {
                KeyRecorderRow(role: .middle, title: "Keyboard key",
                               detail: "Hold the key to hold the middle button. Use one key, like F5 or right ⌥, or up to 3 keys together, like ⌃⌥M or ⌃⌥.")
                Picker(selection: $model.extraButton) {
                    Text("Off").tag(0)
                    Text("Button 4 (back)").tag(3)
                    Text("Button 5 (forward)").tag(4)
                } label: {
                    Text("Extra mouse button")
                    Text("For other mice with side buttons. The Magic Mouse has none.")
                }
            } header: {
                SectionTitle("Middle click with a key or button", symbol: "keyboard")
            }

            Section {
                Toggle(isOn: $model.chord) {
                    Text("Touch the left side to left-click")
                    Text("Hold the right click. Then touch the left half with another finger. The left button stays down until you lift that finger.")
                }
            } header: {
                SectionTitle("Left click while right is held", symbol: "rectangle.split.2x1")
            }

            Section {
                Toggle(isOn: $model.pinchZoom) {
                    Text("Pinch to zoom")
                    Text("Move two fingers apart or together on the mouse. Apps zoom where the pointer is, like with a trackpad pinch.")
                }
                Toggle(isOn: $model.rotate) {
                    Text("Rotate")
                    Text("Turn two fingers on the mouse, like turning a dial. Works in apps like Maps, Preview and Photos.")
                }
            } header: {
                SectionTitle("Zoom and rotate", symbol: "arrow.up.left.and.arrow.down.right")
            }

            SpotlightSection()

            Section {
                Toggle("Enabled", isOn: $model.enabled)
                Toggle("Open at login", isOn: $model.launchAtLogin)
            } header: {
                SectionTitle("General", symbol: "gearshape")
            }

            Section {
                HStack {
                    Link(destination: URL(string: "https://github.com/codeFi/MagicClick")!) {
                        Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Spacer()
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                        .foregroundStyle(.secondary)
                    Button("Quit") { NSApp.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
        .overlay(alignment: .top) { TitlebarFade() }
        .frame(minWidth: 520, idealWidth: 580, minHeight: 560, idealHeight: 820)
    }
}

/// Fades the content out under the transparent title bar, so it does not run into the window buttons.
private struct TitlebarFade: View {
    var body: some View {
        let background = Color(nsColor: .windowBackgroundColor)
        LinearGradient(stops: [.init(color: background, location: 0), .init(color: background, location: 0.5),
                               .init(color: background.opacity(0), location: 1)],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: 56)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct SectionTitle: View {
    let title: String
    let symbol: String

    init(_ title: String, symbol: String) {
        self.title = title
        self.symbol = symbol
    }

    var body: some View {
        Label(title, systemImage: symbol)
    }
}

// MARK: Header

private struct HeaderView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                AppIconTile(size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MagicClick")
                        .font(.title2.weight(.bold))
                    Text("Middle click, chord click, gestures and a spotlight for the Magic Mouse")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Enabled", isOn: $model.enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.large)
            }
            HStack(spacing: 8) {
                StatusPill(ok: model.trusted, text: model.trusted ? "Accessibility on" : "Needs Accessibility")
                StatusPill(ok: model.mouseConnected, text: model.mouseConnected ? "Magic Mouse connected" : "No Magic Mouse")
                StatusPill(ok: model.enabled, text: model.enabled ? "Active" : "Paused")
            }
        }
        .padding(.vertical, 4)
    }
}

struct AppIconTile: View {
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(LinearGradient(colors: [Color(red: 0.36, green: 0.42, blue: 1.0), Color(red: 0.62, green: 0.33, blue: 0.96)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Image(systemName: "computermouse.fill")
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
    }
}

private struct StatusPill: View {
    let ok: Bool
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(ok ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(.quaternary))
    }
}

private struct PermissionCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 8) {
                Text("Allow Accessibility access")
                    .font(.headline)
                Text("MagicClick needs this to change clicks and to read the key you choose. Go to System Settings → Privacy & Security → Accessibility and turn on MagicClick. This window updates by itself.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Accessibility Settings") { model.requestAccessibility() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: Live view

private struct LivePreview: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(alignment: .center, spacing: 28) {
            MouseDiagram(live: model.live, middleCount: model.fingerCount)
                .frame(width: 112, height: 196)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Magic Mouse live view")
                .accessibilityValue(liveDescription)
                .accessibilityAddTraits(.updatesFrequently)
            VStack(alignment: .leading, spacing: 10) {
                LegendRow(color: .blue, title: "Left half", detail: "Left click. While right is held, touch here to left-click.")
                LegendRow(color: .orange, title: "Right half", detail: "Right click.")
                LegendRow(color: .purple, title: "\(model.fingerCount)+ fingers", detail: "Middle click.")
                Text("Rest your fingers on the Magic Mouse to see them here.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.yellow)
                    Text(model.lastAction ?? "No clicks yet")
                        .font(.callout.weight(.semibold))
                        .id(model.lastActionID)
                        .transition(.push(from: .bottom))
                }
                .animation(.snappy, value: model.lastActionID)
                .clipped()
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    /// What VoiceOver reads for the mouse drawing.
    private var liveDescription: String {
        let touches = model.live.touches
        var parts = [touches.isEmpty ? "No fingers" : "\(touches.count) finger\(touches.count == 1 ? "" : "s") on the mouse"]
        if model.live.rightHeld { parts.append("right button held") }
        if model.live.chordActive { parts.append("left button pressed") }
        if model.live.gestures.contains(.zoom) { parts.append("zooming") }
        if model.live.gestures.contains(.rotate) { parts.append("rotating") }
        if !model.live.rightHeld, touches.count >= model.fingerCount { parts.append("a click now is a middle click") }
        return parts.joined(separator: ", ")
    }
}

private struct LegendRow: View {
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A top-down Magic Mouse with the fingers drawn where they touch.
struct MouseDiagram: View {
    let live: LiveSnapshot
    let middleCount: Int

    var body: some View {
        Canvas { context, size in
            let body = Path(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1),
                            cornerRadius: size.width / 2 - 1, style: .circular)
            context.fill(body, with: .color(Color(nsColor: .controlBackgroundColor)))

            // Tint the halves; brighter while that side is pressed.
            var halves = context
            halves.clip(to: body)
            let half = size.width / 2
            if let gestureColor {
                halves.fill(body, with: .color(gestureColor.opacity(0.3)))
            } else if isMiddle {
                halves.fill(body, with: .color(.purple.opacity(0.35)))
            } else {
                halves.fill(Path(CGRect(x: 0, y: 0, width: half, height: size.height)),
                            with: .color(.blue.opacity(live.chordActive ? 0.45 : 0.1)))
                halves.fill(Path(CGRect(x: half, y: 0, width: half, height: size.height)),
                            with: .color(.orange.opacity(live.rightHeld ? 0.45 : 0.08)))
            }

            var divider = Path()
            divider.move(to: CGPoint(x: half, y: 6))
            divider.addLine(to: CGPoint(x: half, y: size.height * 0.45))
            context.stroke(divider, with: .color(.secondary.opacity(0.4)), lineWidth: 1)
            context.stroke(body, with: .color(.secondary.opacity(0.5)), lineWidth: 1.5)

            // Join the two fingers, so the zoom or the turn is easy to see.
            if !live.gestures.isEmpty, live.touches.count == 2 {
                var link = Path()
                link.move(to: point(for: live.touches[0], in: size))
                link.addLine(to: point(for: live.touches[1], in: size))
                context.stroke(link, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
            }

            for touch in live.touches {
                let center = point(for: touch, in: size)
                let dot = Path(ellipseIn: CGRect(x: center.x - 12, y: center.y - 12, width: 24, height: 24))
                let color = color(for: touch)
                var glow = context
                glow.addFilter(.shadow(color: color.opacity(0.6), radius: 5))
                glow.fill(dot, with: .color(color))
                context.stroke(dot, with: .color(.white.opacity(0.85)), lineWidth: 2)
            }

            // Say which buttons are down right now.
            let badgeY = size.height * 0.62
            if let gestureColor {
                let names = [live.gestures.contains(.zoom) ? "ZOOM" : nil, live.gestures.contains(.rotate) ? "ROTATE" : nil]
                drawBadge(names.compactMap { $0 }.joined(separator: " + "), color: gestureColor,
                          at: CGPoint(x: half, y: badgeY), in: context)
            } else if isMiddle {
                drawBadge("MIDDLE", color: .purple, at: CGPoint(x: half, y: badgeY), in: context)
            } else {
                if live.chordActive {
                    drawBadge("LEFT", color: .blue, at: CGPoint(x: half / 2 + 2, y: badgeY), in: context)
                }
                if live.rightHeld {
                    drawBadge("RIGHT", color: .orange, at: CGPoint(x: half * 1.5 - 2, y: badgeY), in: context)
                }
            }

            let label = live.touches.isEmpty ? "No fingers" : "\(live.touches.count) finger\(live.touches.count == 1 ? "" : "s")"
            context.draw(Text(label).font(.caption2.weight(.medium)).foregroundStyle(.secondary),
                         at: CGPoint(x: half, y: size.height * 0.88))
        }
    }

    private var isMiddle: Bool {
        !live.rightHeld && live.touches.count >= middleCount
    }

    private var gestureColor: Color? {
        live.gestures.isEmpty ? nil : .teal
    }

    private func point(for touch: Touch, in size: CGSize) -> CGPoint {
        CGPoint(x: CGFloat(touch.x) * size.width, y: (1 - CGFloat(touch.y)) * size.height)
    }

    private func color(for touch: Touch) -> Color {
        if let gestureColor { return gestureColor }
        if isMiddle { return .purple }
        return touch.x < 0.5 ? .blue : .orange
    }

    private func drawBadge(_ text: String, color: Color, at center: CGPoint, in context: GraphicsContext) {
        let label = context.resolve(Text(text).font(.system(size: 9, weight: .heavy)).foregroundStyle(.white))
        let textSize = label.measure(in: CGSize(width: 200, height: 50))
        let rect = CGRect(x: center.x - textSize.width / 2 - 5, y: center.y - textSize.height / 2 - 2.5,
                          width: textSize.width + 10, height: textSize.height + 5)
        context.fill(Path(roundedRect: rect, cornerRadius: rect.height / 2), with: .color(color))
        context.draw(label, at: center)
    }
}

// MARK: Spotlight

private struct SpotlightSection: View {
    @EnvironmentObject private var model: AppModel
    @State private var screens = NSScreen.screens

    var body: some View {
        Section {
            Toggle(isOn: $model.spotlightOn) {
                Text("Show spotlight")
                Text("Darkens the screen around the pointer, or draws a ring around it, so people can follow it in a demo or a recording.")
            }
            Picker("Style", selection: $model.spotlightStyle) {
                Text("Spotlight").tag(SpotlightStyle.spotlight)
                Text("Ring").tag(SpotlightStyle.ring)
            }
            .pickerStyle(.segmented)
            ValueSlider(title: "Size", value: $model.spotlightSize, range: 80...600, text: "\(Int(model.spotlightSize)) pt")
            if model.spotlightStyle == .spotlight {
                ValueSlider(title: "Opacity", value: $model.spotlightDim, range: 0.1...0.95,
                            text: "\(Int((model.spotlightDim * 100).rounded())) %")
                ValueSlider(title: "Soft edge", value: $model.spotlightSoftness, range: 0...150,
                            text: "\(Int(model.spotlightSoftness)) pt")
                ColorPicker("Overlay color", selection: color(\.spotlightColor), supportsOpacity: false)
            } else {
                ColorPicker("Ring color", selection: color(\.ringColor), supportsOpacity: false)
            }
            Toggle(isOn: $model.spotlightPulse) {
                Text("Pulse on click")
                Text("A ring grows on each click, so people see when you click: blue left, orange right, purple middle.")
            }
            KeyRecorderRow(role: .spotlightToggle, title: "On/off key",
                           detail: "Press the key to turn the spotlight on or off. One key or up to 3 keys together, like ⌃⌥S.")
            KeyRecorderRow(role: .spotlightHold, title: "Hold key",
                           detail: "Shows the spotlight only while you hold the key. Point at something, then let go. One key or up to 3 keys together.")
            KeyRecorderRow(role: .windowShot, title: "Window screenshot key",
                           detail: "Saves the window under the pointer with the spotlight, where macOS saves screenshots. One key or up to 3 keys together. The first time, macOS asks for Screen Recording permission.")
            ForEach(screens, id: \.self) { screen in
                Toggle(isOn: shows(screen)) {
                    Label(screen.localizedName, systemImage: "display")
                    Text("\(Int(screen.frame.width)) × \(Int(screen.frame.height)) pt")
                }
            }
        } header: {
            SectionTitle("Spotlight", symbol: "light.max")
        } footer: {
            Text("Screenshots, recordings and whole-screen sharing show the spotlight. A screenshot or a share of one window shows only that window, without the spotlight.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screens = NSScreen.screens
        }
    }

    private func color(_ keyPath: ReferenceWritableKeyPath<AppModel, NSColor>) -> Binding<Color> {
        Binding { Color(nsColor: model[keyPath: keyPath]) } set: { model[keyPath: keyPath] = NSColor($0) }
    }

    private func shows(_ screen: NSScreen) -> Binding<Bool> {
        let id = Spotlight.displayID(of: screen)
        return Binding { !model.spotlightHiddenDisplays.contains(id) } set: { on in
            if on { model.spotlightHiddenDisplays.remove(id) } else { model.spotlightHiddenDisplays.insert(id) }
        }
    }
}

private struct ValueSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let text: String

    var body: some View {
        LabeledContent {
            HStack(spacing: 10) {
                Slider(value: $value, in: range)
                Text(text)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
            }
        } label: {
            Text(title)
        }
    }
}

// MARK: Key recorder

private struct KeyRecorderRow: View {
    @EnvironmentObject private var model: AppModel
    let role: KeyRole
    let title: String
    let detail: String

    private var isRecording: Bool { model.recording == role }
    private var key: KeyTrigger? { model[keyPath: role.keyPath] }

    var body: some View {
        LabeledContent {
            HStack(spacing: 6) {
                Button {
                    isRecording ? model.cancelRecording() : model.startRecording(role)
                } label: {
                    Text(isRecording ? "Press a key…" : (key?.name ?? "Click to set"))
                        .font(.body.weight(.medium))
                        .frame(minWidth: 140)
                }
                .buttonStyle(.bordered)
                .tint(isRecording ? .accentColor : nil)
                if key != nil, !isRecording {
                    Button {
                        model[keyPath: role.keyPath] = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Remove key")
                }
            }
            .disabled(!model.tapRunning)
        } label: {
            Text(title)
            Text(isRecording
                 ? "Press a key or up to 3 keys together, for example F6, ⌃⌥S or ⌃⌥. For modifiers only, press them together, then let go. Esc cancels."
                 : detail)
        }
    }
}
