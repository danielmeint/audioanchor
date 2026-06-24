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
            .padding(.bottom, 8)

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

/// One direction's priority list (drag rows to reorder) with an auto-switch toggle.
struct DeviceSection: View {
    @EnvironmentObject var manager: AudioManager
    let direction: AudioDirection
    let title: String
    let systemImage: String

    var body: some View {
        let rows = manager.rows(direction)
        VStack(alignment: .leading, spacing: 1) {
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
                ForEach(rows) { row in
                    DeviceRowView(direction: direction, row: row)
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

/// A single device row. Tap to make it the default now; drag to reorder priority;
/// right-click to forget.
struct DeviceRowView: View {
    @EnvironmentObject var manager: AudioManager
    let direction: AudioDirection
    let row: DeviceRow

    @State private var isTargeted = false
    private let rowHeight: CGFloat = 28

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
        .frame(height: rowHeight)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .background(isTargeted ? Color.accentColor.opacity(0.18) : Color.clear)
        .onTapGesture {
            if row.isConnected { manager.activate(row.device.uid, direction: direction) }
        }
        .draggable(row.device.uid) {
            Text(row.device.name)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .dropDestination(for: String.self) { items, location in
            guard let dragged = items.first else { return false }
            manager.reorder(dragged, direction: direction,
                            target: row.device.uid, after: location.y > rowHeight / 2)
            return true
        } isTargeted: { isTargeted = $0 }
        .contextMenu {
            Button("Forget \u{201C}\(row.device.name)\u{201D}") { manager.forget(row.device.uid) }
        }
    }
}

/// Launch-at-login toggle (with approval hint) and Quit.
struct FooterView: View {
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var needsApproval = LoginItem.status == .requiresApproval

    var body: some View {
        VStack(spacing: 0) {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: launchAtLogin) { newValue in
                    let status = LoginItem.set(newValue)
                    // Keep the toggle on while approval is pending; it isn't "off".
                    launchAtLogin = (status == .enabled || status == .requiresApproval)
                    needsApproval = newValue && status == .requiresApproval
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            if needsApproval {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Enable AudioAnchor under Login Items to finish.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button("Open Login Items settings…") { LoginItem.openSettings() }
                        .buttonStyle(.link)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }

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
