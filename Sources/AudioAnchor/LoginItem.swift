import ServiceManagement

/// Launch-at-login via the modern `SMAppService` API (macOS 13+).
/// Note: registration only sticks for a signed app bundle; ad-hoc builds may report
/// `.requiresApproval` and need a manual toggle in System Settings › Login Items.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
            return true
        } catch {
            NSLog("AudioAnchor: login item update failed: \(error.localizedDescription)")
            return false
        }
    }
}
