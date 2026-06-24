import CoreAudio

/// A live audio device currently present on the system.
struct AudioDevice: Identifiable, Hashable {
    /// CoreAudio object id. Transient — it can change across reconnects, so never persist it.
    let audioObjectID: AudioDeviceID
    /// Stable identifier that survives reconnects. This is what we persist priorities against.
    let uid: String
    let name: String
    let hasOutput: Bool
    let hasInput: Bool

    var id: String { uid }
}

/// A device we've seen at least once, remembered even while disconnected (device memory).
struct KnownDevice: Codable, Identifiable, Hashable {
    let uid: String
    var name: String
    var hasOutput: Bool
    var hasInput: Bool

    var id: String { uid }
}

/// A row shown in the UI: a known device plus its live state.
struct DeviceRow: Identifiable {
    let device: KnownDevice
    let isConnected: Bool
    let isActive: Bool

    var id: String { device.uid }
}

/// Output vs input, with the CoreAudio scope/selector mapping for each.
enum AudioDirection: CaseIterable {
    case output
    case input

    var scope: AudioObjectPropertyScope {
        switch self {
        case .output: return kAudioObjectPropertyScopeOutput
        case .input: return kAudioObjectPropertyScopeInput
        }
    }

    var defaultSelector: AudioObjectPropertySelector {
        switch self {
        case .output: return kAudioHardwarePropertyDefaultOutputDevice
        case .input: return kAudioHardwarePropertyDefaultInputDevice
        }
    }
}
