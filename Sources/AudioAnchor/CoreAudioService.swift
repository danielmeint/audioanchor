import CoreAudio
import Foundation

/// Thin wrapper over the CoreAudio HAL: enumerate devices, read/write the system
/// default input & output devices, and observe changes.
///
/// References for the property selectors used here:
///   - deweller/switchaudio-osx (C reference for get/set default device)
///   - Apple AudioHardware.h
final class CoreAudioService {
    private let systemObject = AudioObjectID(kAudioObjectSystemObject)
    private var listeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []

    // MARK: - Address helper

    private func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    // MARK: - Enumeration

    /// All devices that expose at least one input or output channel.
    func allDevices() -> [AudioDevice] {
        var addr = address(kAudioHardwarePropertyDevices)
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &addr, 0, nil, &dataSize) == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return [] }

        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(systemObject, &addr, 0, nil, &dataSize, &ids) == noErr else { return [] }

        return ids.compactMap { id in
            guard let uid = deviceUID(id), let name = deviceName(id) else { return nil }
            let hasOutput = channelCount(id, scope: kAudioObjectPropertyScopeOutput) > 0
            let hasInput = channelCount(id, scope: kAudioObjectPropertyScopeInput) > 0
            guard hasOutput || hasInput else { return nil }
            return AudioDevice(audioObjectID: id, uid: uid, name: name, hasOutput: hasOutput, hasInput: hasInput)
        }
    }

    private func deviceUID(_ id: AudioDeviceID) -> String? {
        var addr = address(kAudioDevicePropertyDeviceUID)
        return stringProperty(id, &addr)
    }

    private func deviceName(_ id: AudioDeviceID) -> String? {
        var addr = address(kAudioObjectPropertyName)
        return stringProperty(id, &addr)
    }

    private func stringProperty(_ id: AudioObjectID, _ addr: inout AudioObjectPropertyAddress) -> String? {
        var size = UInt32(MemoryLayout<CFString?>.size)
        var result: CFString?
        let status = withUnsafeMutablePointer(to: &result) {
            AudioObjectGetPropertyData(id, &addr, 0, nil, &size, $0)
        }
        guard status == noErr else { return nil }
        return result as String?
    }

    /// Total channels in the given scope; 0 means the device can't be used in that direction.
    private func channelCount(_ id: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int {
        var addr = address(kAudioDevicePropertyStreamConfiguration, scope: scope)
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &dataSize) == noErr, dataSize > 0 else { return 0 }

        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { buffer.deallocate() }

        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &dataSize, buffer) == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(buffer.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    // MARK: - Defaults

    func defaultDeviceID(_ direction: AudioDirection) -> AudioDeviceID {
        var addr = address(direction.defaultSelector)
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(systemObject, &addr, 0, nil, &size, &deviceID)
        return deviceID
    }

    @discardableResult
    func setDefaultDevice(_ direction: AudioDirection, _ id: AudioDeviceID) -> Bool {
        var addr = address(direction.defaultSelector)
        var deviceID = id
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let ok = AudioObjectSetPropertyData(systemObject, &addr, 0, nil, size, &deviceID) == noErr

        // Keep system sound effects (alerts, UI sounds) on the same speaker as the main output.
        if ok, direction == .output {
            var sysAddr = address(kAudioHardwarePropertyDefaultSystemOutputDevice)
            AudioObjectSetPropertyData(systemObject, &sysAddr, 0, nil, size, &deviceID)
        }
        return ok
    }

    // MARK: - Change observation

    /// Fires `handler` (on the main queue) whenever the device list or a default device changes.
    func startListening(_ handler: @escaping () -> Void) {
        let selectors: [AudioObjectPropertySelector] = [
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultOutputDevice,
            kAudioHardwarePropertyDefaultInputDevice,
        ]
        let block: AudioObjectPropertyListenerBlock = { _, _ in handler() }
        for selector in selectors {
            var addr = address(selector)
            if AudioObjectAddPropertyListenerBlock(systemObject, &addr, DispatchQueue.main, block) == noErr {
                listeners.append((addr, block))
            }
        }
    }

    func stopListening() {
        for (addr, block) in listeners {
            var addr = addr
            AudioObjectRemovePropertyListenerBlock(systemObject, &addr, DispatchQueue.main, block)
        }
        listeners.removeAll()
    }
}
