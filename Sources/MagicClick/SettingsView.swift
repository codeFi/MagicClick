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
                KeyRecorderRow()
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
        .frame(minWidth: 520, idealWidth: 580, minHeight: 560, idealHeight: 820)
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
                    Text("Middle click and chord click for the Magic Mouse")
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
private struct MouseDiagram: View {
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
            if isMiddle {
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

            for touch in live.touches {
                let center = CGPoint(x: CGFloat(touch.x) * size.width, y: (1 - CGFloat(touch.y)) * size.height)
                let dot = Path(ellipseIn: CGRect(x: center.x - 12, y: center.y - 12, width: 24, height: 24))
                let color = color(for: touch)
                var glow = context
                glow.addFilter(.shadow(color: color.opacity(0.6), radius: 5))
                glow.fill(dot, with: .color(color))
                context.stroke(dot, with: .color(.white.opacity(0.85)), lineWidth: 2)
            }

            // Say which buttons are down right now.
            let badgeY = size.height * 0.62
            if isMiddle {
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

    private func color(for touch: Touch) -> Color {
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

// MARK: Key recorder

private struct KeyRecorderRow: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        LabeledContent {
            HStack(spacing: 6) {
                Button {
                    model.isRecording ? model.cancelRecording() : model.startRecording()
                } label: {
                    Text(model.isRecording ? "Press a key…" : (model.trigger?.name ?? "Click to set"))
                        .font(.body.weight(.medium))
                        .frame(minWidth: 140)
                }
                .buttonStyle(.bordered)
                .tint(model.isRecording ? .accentColor : nil)
                if model.trigger != nil, !model.isRecording {
                    Button {
                        model.trigger = nil
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
            Text("Keyboard key")
            Text(model.isRecording
                 ? "Press any key. For a modifier on its own, press and release it. Esc cancels."
                 : "Hold the key to hold the middle button. Works with F-keys, media keys, fn, and right ⌘ ⌥ ⌃ ⇧.")
        }
    }
}
