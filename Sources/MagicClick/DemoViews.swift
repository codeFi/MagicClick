import SwiftUI

// Views for the showcase GIF (`--gesture-frames`). They are only drawn offscreen, never in the app.

/// The right side of a click scene in the demo GIF: what the click is good for.
struct DemoCard: View {
    let symbol: String
    let title: String
    let lines: [String]
    let key: String?
    let active: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: symbol)
                .font(.system(size: 60, weight: .semibold))
                .foregroundStyle(active ? Color.yellow : Color.white.opacity(0.85))
            if let key {
                Text(key)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(active ? 0.3 : 0.12)))
            }
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(lines, id: \.self) { line in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text(line).foregroundStyle(Color.white.opacity(0.85))
                    }
                    .font(.system(size: 19, weight: .medium))
                }
            }
        }
        .frame(width: 624, height: 464)
        .background(DemoBackground())
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(active ? Color.yellow : Color.white.opacity(0.08), lineWidth: active ? 3 : 1))
    }
}

/// A wide scene without the mouse: the title, the spotlight tools, or the closing card.
struct DemoWideCard: View {
    enum Kind { case intro, spotlight, outro }
    let kind: Kind

    var body: some View {
        Group {
            switch kind {
            case .intro: intro
            case .spotlight: spotlight
            case .outro: outro
            }
        }
        .frame(width: 825, height: 464)
        .background(DemoBackground(glow: kind != .spotlight))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var intro: some View {
        VStack(spacing: 18) {
            AppIconTile(size: 96)
            Text("MagicClick")
                .font(.system(size: 50, weight: .bold))
                .foregroundStyle(.white)
            Text("The clicks, gestures and spotlight\nyour Magic Mouse is missing")
                .font(.system(size: 22, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.7))
            HStack(spacing: 8) {
                Chip(symbol: "hand.raised.fingers.spread", text: "Middle click")
                Chip(symbol: "rectangle.split.2x1", text: "Left + right")
                Chip(symbol: "keyboard", text: "Any key")
                Chip(symbol: "arrow.up.left.and.arrow.down.right", text: "Zoom")
                Chip(symbol: "rotate.right", text: "Rotate")
                Chip(symbol: "light.max", text: "Spotlight")
            }
            .padding(.top, 6)
        }
    }

    private var spotlight: some View {
        VStack(spacing: 20) {
            Text("More spotlight tools")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
            Grid(horizontalSpacing: 14, verticalSpacing: 14) {
                GridRow {
                    Tile(symbol: "circle.circle", tint: .yellow, title: "Ring style", line: "A colored ring. The screen stays bright.")
                    Tile(symbol: "cursorarrow.click.2", tint: .blue, title: "Click pulses", line: "Blue left, orange right, purple middle.",
                         dots: [.blue, .orange, .purple])
                    Tile(symbol: "keyboard", tint: .green, title: "On/off and hold keys", line: "One key, or up to 3 together, like ⌃⌥.")
                }
                GridRow {
                    Tile(symbol: "macwindow", tint: .pink, title: "Window screenshot", line: "One key saves a window with the spotlight.")
                    Tile(symbol: "display.2", tint: .cyan, title: "Every display", line: "Pick the displays that show it.")
                    Tile(symbol: "record.circle", tint: .red, title: "Captures show it", line: "⌘⇧3, ⌘⇧4 and ⌘⇧5 recordings.")
                }
            }
        }
    }

    private var outro: some View {
        VStack(spacing: 16) {
            AppIconTile(size: 76)
            Text("Free and open source")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
            Text("github.com/codeFi/MagicClick")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(LinearGradient(colors: [Color(red: 0.36, green: 0.42, blue: 1.0),
                                                                   Color(red: 0.62, green: 0.33, blue: 0.96)],
                                                          startPoint: .leading, endPoint: .trailing)))
            Text("macOS 14 or later · Apple silicon and Intel")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.6))
            HStack(spacing: 8) {
                Chip(symbol: "menubar.rectangle", text: "Menu bar app")
                Chip(symbol: "dot.radiowaves.left.and.right", text: "Live view")
                Chip(symbol: "power", text: "Open at login")
                Chip(symbol: "lock.shield", text: "No tracking")
                Chip(symbol: "cable.connector", text: "Hot-plug")
            }
            .padding(.top, 8)
        }
    }

    private struct Chip: View {
        let symbol: String
        let text: String

        var body: some View {
            Label(text, systemImage: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.1)))
                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    private struct Tile: View {
        let symbol: String
        let tint: Color
        let title: String
        let line: String
        var dots: [Color] = []

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 11).fill(tint.opacity(0.16)))
                    Spacer()
                    HStack(spacing: 5) {
                        ForEach(dots.indices, id: \.self) { Circle().stroke(dots[$0], lineWidth: 3).frame(width: 16, height: 16) }
                    }
                }
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Text(line)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: 240, height: 152, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }
}

/// Dark card background with an optional soft glow in the app colors.
private struct DemoBackground: View {
    var glow = false

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(white: 0.16))
            .overlay {
                if glow {
                    RadialGradient(colors: [Color(red: 0.5, green: 0.38, blue: 1.0).opacity(0.28), .clear],
                                   center: .top, startRadius: 0, endRadius: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
    }
}
