import CoreAudio
import SwiftUI

/// Owns app state: the priority lists, device memory, auto-switch flags, and the
/// logic that forces the highest-priority connected device to be the default.
@MainActor
final class AudioManager: ObservableObject {
    private let service = CoreAudioService()
    private let defaults = UserDefaults.standard

    @Published private(set) var connected: [AudioDevice] = []
    @Published private(set) var known: [String: KnownDevice] = [:]
    @Published private(set) var outputOrder: [String] = []
    @Published private(set) var inputOrder: [String] = []
    @Published private(set) var currentOutputUID: String?
    @Published private(set) var currentInputUID: String?

    @Published var autoOutput: Bool {
        didSet { defaults.set(autoOutput, forKey: Keys.autoOutput); if autoOutput { apply(.output) } }
    }
    @Published var autoInput: Bool {
        didSet { defaults.set(autoInput, forKey: Keys.autoInput); if autoInput { apply(.input) } }
    }

    init() {
        autoOutput = defaults.object(forKey: Keys.autoOutput) as? Bool ?? true
        autoInput = defaults.object(forKey: Keys.autoInput) as? Bool ?? true
        outputOrder = defaults.stringArray(forKey: Keys.outputOrder) ?? []
        inputOrder = defaults.stringArray(forKey: Keys.inputOrder) ?? []
        known = Self.loadKnown(defaults)

        refresh()
        service.startListening { [weak self] in self?.refresh() }
    }

    // MARK: - Snapshot / reconcile

    /// Re-read the system, fold new devices into memory, and re-assert priority if auto is on.
    func refresh() {
        let devices = service.allDevices()
        connected = devices
        currentOutputUID = uid(forDeviceID: service.defaultDeviceID(.output))
        currentInputUID = uid(forDeviceID: service.defaultDeviceID(.input))

        // Empty lists mean a first-ever launch (or everything was forgotten).
        let seedOutput = outputOrder.isEmpty
        let seedInput = inputOrder.isEmpty

        var changed = false
        for device in devices {
            let entry = KnownDevice(uid: device.uid, name: device.name,
                                    hasOutput: device.hasOutput, hasInput: device.hasInput)
            if known[device.uid] != entry { known[device.uid] = entry; changed = true }
            // New devices go to the BOTTOM so plugging something in never hijacks
            // your default — auto-switch then pulls it back to your top device.
            if device.hasOutput, !outputOrder.contains(device.uid) { outputOrder.append(device.uid); changed = true }
            if device.hasInput, !inputOrder.contains(device.uid) { inputOrder.append(device.uid); changed = true }
        }

        // First-ever population: keep whatever is already the default on top so
        // launching the app changes nothing until you reorder things yourself.
        if seedOutput, let uid = currentOutputUID, outputOrder.first != uid {
            outputOrder.removeAll { $0 == uid }; outputOrder.insert(uid, at: 0); changed = true
        }
        if seedInput, let uid = currentInputUID, inputOrder.first != uid {
            inputOrder.removeAll { $0 == uid }; inputOrder.insert(uid, at: 0); changed = true
        }

        if changed { persist() }

        if autoOutput { apply(.output) }
        if autoInput { apply(.input) }
    }

    /// Force the highest-priority connected device for `direction` to be the system default.
    private func apply(_ direction: AudioDirection) {
        let order = order(direction)
        let candidates = connected.filter { direction == .output ? $0.hasOutput : $0.hasInput }
        let byUID = Dictionary(candidates.map { ($0.uid, $0) }, uniquingKeysWith: { first, _ in first })

        guard let targetUID = order.first(where: { byUID[$0] != nil }),
              let target = byUID[targetUID] else { return }

        if service.defaultDeviceID(direction) != target.audioObjectID {
            service.setDefaultDevice(direction, target.audioObjectID)
        }
        setCurrent(target.uid, direction)
    }

    // MARK: - UI queries

    /// Devices for a direction in priority order, each tagged connected/active. Includes
    /// remembered-but-disconnected devices so you can pre-rank things you'll plug in later.
    func rows(_ direction: AudioDirection) -> [DeviceRow] {
        let connectedUIDs = Set(connected.map(\.uid))
        let current = direction == .output ? currentOutputUID : currentInputUID
        return order(direction).compactMap { uid in
            guard let device = known[uid] else { return nil }
            guard direction == .output ? device.hasOutput : device.hasInput else { return nil }
            return DeviceRow(device: device,
                             isConnected: connectedUIDs.contains(uid),
                             isActive: current == uid)
        }
    }

    // MARK: - Mutations

    /// Make `uid` the default now and bump it to the top of its priority list.
    func activate(_ uid: String, direction: AudioDirection) {
        var ordered = rows(direction).map(\.device.uid)
        ordered.removeAll { $0 == uid }
        ordered.insert(uid, at: 0)
        rebuild(direction, displayed: ordered)

        if let device = connected.first(where: { $0.uid == uid }) {
            service.setDefaultDevice(direction, device.audioObjectID)
            setCurrent(uid, direction)
        }
    }

    func moveUp(_ uid: String, direction: AudioDirection) {
        var ordered = rows(direction).map(\.device.uid)
        guard let index = ordered.firstIndex(of: uid), index > 0 else { return }
        ordered.swapAt(index, index - 1)
        rebuild(direction, displayed: ordered)
        if autoEnabled(direction) { apply(direction) }
    }

    func moveDown(_ uid: String, direction: AudioDirection) {
        var ordered = rows(direction).map(\.device.uid)
        guard let index = ordered.firstIndex(of: uid), index < ordered.count - 1 else { return }
        ordered.swapAt(index, index + 1)
        rebuild(direction, displayed: ordered)
        if autoEnabled(direction) { apply(direction) }
    }

    /// Forget a device entirely (drops it from memory and both priority lists).
    func forget(_ uid: String) {
        known[uid] = nil
        outputOrder.removeAll { $0 == uid }
        inputOrder.removeAll { $0 == uid }
        persist()
    }

    // MARK: - Helpers

    private func order(_ direction: AudioDirection) -> [String] {
        direction == .output ? outputOrder : inputOrder
    }

    private func autoEnabled(_ direction: AudioDirection) -> Bool {
        direction == .output ? autoOutput : autoInput
    }

    private func setCurrent(_ uid: String, _ direction: AudioDirection) {
        if direction == .output { currentOutputUID = uid } else { currentInputUID = uid }
    }

    private func uid(forDeviceID id: AudioDeviceID) -> String? {
        connected.first { $0.audioObjectID == id }?.uid
    }

    /// Rewrite an order list from the displayed sequence, preserving any hidden uids at the end.
    private func rebuild(_ direction: AudioDirection, displayed: [String]) {
        let hidden = order(direction).filter { !displayed.contains($0) }
        let newOrder = displayed + hidden
        if direction == .output { outputOrder = newOrder } else { inputOrder = newOrder }
        persist()
    }

    private func persist() {
        defaults.set(outputOrder, forKey: Keys.outputOrder)
        defaults.set(inputOrder, forKey: Keys.inputOrder)
        if let data = try? JSONEncoder().encode(Array(known.values)) {
            defaults.set(data, forKey: Keys.known)
        }
    }

    private static func loadKnown(_ defaults: UserDefaults) -> [String: KnownDevice] {
        guard let data = defaults.data(forKey: Keys.known),
              let list = try? JSONDecoder().decode([KnownDevice].self, from: data) else { return [:] }
        return Dictionary(list.map { ($0.uid, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private enum Keys {
        static let autoOutput = "autoOutput"
        static let autoInput = "autoInput"
        static let outputOrder = "outputOrder"
        static let inputOrder = "inputOrder"
        static let known = "knownDevices"
    }
}
