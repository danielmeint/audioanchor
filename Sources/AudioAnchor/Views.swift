import AppKit
import SwiftUI

/// The popover shown from the menu bar.
struct MenuContentView: View {
    @EnvironmentObject var manager: AudioManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                Text("AudioAnchor").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()
            DeviceSection(direction: .output, title: "Output", systemImage: "speaker.wave.2.fill")
            Divider()
            DeviceSection(direction: .input, title: "Input", systemImage: "mic.fill")
            Divider()
            FooterView()
        }
        .frame(width: 300)
    }
}

/// One direction's priority list with an auto-switch toggle.
struct DeviceSection: View {
    @EnvironmentObject var manager: AudioManager
    let direction: AudioDirection
    let title: String
    let systemImage: String

    var body: some View {
        let rows = manager.rows(direction)
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Toggle("Auto", isOn: autoBinding)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .help("Force the top connected device to stay the default")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if rows.isEmpty {
                Text("No devices yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    DeviceRowView(
                        direction: direction,
                        row: row,
                        canMoveUp: index > 0,
                        canMoveDown: index < rows.count - 1
                    )
                }
                .padding(.bottom, 4)
            }
        }
    }

    private var autoBinding: Binding<Bool> {
        switch direction {
        case .output: return Binding(get: { manager.autoOutput }, set: { manager.autoOutput = $0 })
        case .input: return Binding(get: { manager.autoInput }, set: { manager.autoInput = $0 })
        }
    }
}

/// A single device row: status dot, active marker, name, and reorder controls.
struct DeviceRowView: View {
    @EnvironmentObject var manager: AudioManager
    let direction: AudioDirection
    let row: DeviceRow
    let canMoveUp: Bool
    let canMoveDown: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(row.isConnected ? Color.green : Color.secondary.opacity(0.35))
                .frame(width: 8, height: 8)
                .help(row.isConnected ? "Connected" : "Not connected")

            Image(systemName: row.isActive ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(row.isActive ? Color.accentColor : Color.secondary.opacity(0.3))

            Text(row.device.name)
                .lineLimit(1)
                .foregroundStyle(row.isConnected ? .primary : .secondary)

            Spacer()

            Button { manager.moveUp(row.device.uid, direction: direction) } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(!canMoveUp)

            Button { manager.moveDown(row.device.uid, direction: direction) } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(!canMoveDown)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture {
            if row.isConnected { manager.activate(row.device.uid, direction: direction) }
        }
        .contextMenu {
            Button("Forget \u{201C}\(row.device.name)\u{201D}") { manager.forget(row.device.uid) }
        }
    }
}

/// Launch-at-login toggle and Quit.
struct FooterView: View {
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        VStack(spacing: 0) {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: launchAtLogin) { newValue in
                    LoginItem.set(newValue)
                    launchAtLogin = LoginItem.isEnabled
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Text("Quit AudioAnchor")
                    Spacer()
                    Text("⌘Q").foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("q")
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}
