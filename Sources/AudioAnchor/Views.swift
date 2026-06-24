import AppKit
import SwiftUI

/// The popover shown from the menu bar.
struct MenuContentView: View {
    @EnvironmentObject var manager: AudioManager

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                Text("AudioAnchor").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()

            List {
                DeviceSection(direction: .output, title: "Output", systemImage: "speaker.wave.2.fill")
                DeviceSection(direction: .input, title: "Input", systemImage: "mic.fill")
            }
            .listStyle(.inset)
            .environment(\.defaultMinListRowHeight, 26)
            .frame(height: listHeight)

            Divider()
            FooterView()
        }
        .frame(width: 300)
    }

    /// The popover has no intrinsic height for a List, so size it to the content
    /// (capped — past that it scrolls).
    private var listHeight: CGFloat {
        let rowCount = manager.rows(.output).count + manager.rows(.input).count
        let rows = CGFloat(max(rowCount, 2)) * 26
        let headers: CGFloat = 2 * 30
        return min(rows + headers + 20, 440)
    }
}

/// One direction's priority list (drag rows to reorder) with an auto-switch toggle.
struct DeviceSection: View {
    @EnvironmentObject var manager: AudioManager
    let direction: AudioDirection
    let title: String
    let systemImage: String

    var body: some View {
        Section {
            let rows = manager.rows(direction)
            if rows.isEmpty {
                Text("No devices yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows) { row in
                    DeviceRowView(direction: direction, row: row)
                }
                .onMove { source, destination in
                    manager.move(direction, from: source, to: destination)
                }
            }
        } header: {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Toggle("Auto", isOn: autoBinding)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .help("Force the top connected device to stay the default")
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

/// A single device row: status dot, active marker, name, drag affordance.
/// Tap to make it the default now; right-click to forget; drag to reorder.
struct DeviceRowView: View {
    @EnvironmentObject var manager: AudioManager
    let direction: AudioDirection
    let row: DeviceRow

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

            if !row.isConnected {
                Text("offline").font(.caption2).foregroundStyle(.secondary)
            }
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .help("Drag to reorder priority")
        }
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
