import ServiceManagement

/// Launch-at-login via the modern `SMAppService` API (macOS 13+).
///
/// After `register()`, macOS commonly reports `.requiresApproval`: the item is
/// registered but won't run at login until the user enables it under
/// System Settings › General › Login Items. Callers should surface that.
enum LoginItem {
    static var status: SMAppService.Status { SMAppService.mainApp.status }
    static var isEnabled: Bool { status == .enabled }

    /// Register/unregister and return the resulting status.
    @discardableResult
    static func set(_ enabled: Bool) -> SMAppService.Status {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
        } catch {
            NSLog("AudioAnchor: login item update failed: \(error.localizedDescription)")
        }
        return SMAppService.mainApp.status
    }

    /// Open System Settings directly to the Login Items pane.
    static func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
