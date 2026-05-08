import AppKit
import ApplicationServices
import Foundation

struct PermissionCenter {
    struct Status: Equatable {
        var accessibilityGranted: Bool = false
        var localNetworkStatusText: String = "由系统在首次发现设备时请求"
        var notificationsStatusText: String = "可选"
    }

    func currentStatus() -> Status {
        Status(accessibilityGranted: AXIsProcessTrusted())
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
