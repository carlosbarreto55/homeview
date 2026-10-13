import ServiceManagement
import os

/// Opening the app when the Mac starts.
@MainActor
protocol LoginItem {
    /// What macOS reports now (the person can change it in System Settings).
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

/// `LoginItem` backed by `SMAppService.mainApp`.
struct MainAppLoginItem: LoginItem {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            try service.register()
            if service.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        } else {
            try service.unregister()
        }
    }
}
