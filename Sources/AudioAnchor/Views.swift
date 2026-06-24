import AppKit
import SwiftUI

private let rowHeight: CGFloat = 28

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

/// One direction's priority list. Rows are reordered with a `DragGesture` (the
/// OS drag session doesn't work inside a menu-bar popover, but in-view gestures
/// do). The dragged row follows the cursor; an accent line shows where it lands.
struct DeviceSection: View {
    @EnvironmentObject var manager: AudioManager
    let direction: AudioDirection
    let title: String
    let systemImage: String

    @State private var draggingUID: String?
    @State private var dragY: CGFloat = 0
    @State private var startIndex = 0

    var body: some View {
        let rows = manager.rows(direction)
        VStack(alignment: .leading, spacing: 0) {
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
                deviceList(rows)
                    .padding(.bottom, 4)
            }
        }
    }

    @ViewBuilder
    private func deviceList(_ rows: [DeviceRow]) -> some View {
        let line = insertionLine(count: rows.count)
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    DeviceRowView(row: row, isDragging: draggingUID == row.device.uid)
                        .offset(y: draggingUID == row.device.uid ? dragY : 0)
                        .zIndex(draggingUID == row.device.uid ? 1 : 0)
                        .contextMenu {
                            Button("Forget \u{201C}\(row.device.name)\u{201D}") { manager.forget(row.device.uid) }
                        }
                        .gesture(rowDrag(uid: row.device.uid, index: index,
                                         count: rows.count, isConnected: row.isConnected))
                }
            }
            if let line, draggingUID != nil {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(height: 2)
                    .padding(.horizontal, 10)
                    .offset(y: CGFloat(line) * rowHeight - 1)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.12), value: line)
            }
        }
    }

    /// Gap index (0...count) where the dragged row will land, or nil if unchanged.
    private func insertionLine(count: Int) -> Int? {
        guard draggingUID != nil else { return nil }
        let target = targetIndex(count: count)
        if target == startIndex { return nil }
        return target > startIndex ? target + 1 : target
    }

    private func targetIndex(count: Int) -> Int {
        let slots = Int((dragY / rowHeight).rounded())
        return max(0, min(startIndex + slots, count - 1))
    }

    private func rowDrag(uid: String, index: Int, count: Int, isConnected: Bool) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if draggingUID != uid {
                    draggingUID = uid
                    startIndex = index
                }
                dragY = value.translation.height
            }
            .onEnded { value in
                let moved = abs(value.translation.height) >= 4 || abs(value.translation.width) >= 4
                if moved {
                    let target = targetIndex(count: count)
                    if target != startIndex {
                        manager.move(uid, direction: direction, toIndex: target)
                    }
                } else if isConnected {
                    manager.activate(uid, direction: direction)
                }
                draggingUID = nil
                dragY = 0
            }
    }

    private var autoBinding: Binding<Bool> {
        switch direction {
        case .output: return Binding(get: { manager.autoOutput }, set: { manager.autoOutput = $0 })
        case .input: return Binding(get: { manager.autoInput }, set: { manager.autoInput = $0 })
        }
    }
}

/// A single device row (presentation only). Status dot, active marker, name,
/// grip. Tap/drag handling lives in `DeviceSection`.
struct DeviceRowView: View {
    let row: DeviceRow
    let isDragging: Bool

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
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isDragging ? Color(nsColor: .controlBackgroundColor) : .clear)
                .shadow(color: isDragging ? .black.opacity(0.25) : .clear,
                        radius: isDragging ? 4 : 0, y: isDragging ? 2 : 0)
                .padding(.horizontal, 6)
        )
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
