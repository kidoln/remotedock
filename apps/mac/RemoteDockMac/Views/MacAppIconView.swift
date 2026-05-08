import AppKit
import SwiftUI

struct MacAppIconView: View {
    var bundleIdentifier: String
    var appPath: String?
    var isActive = false
    var size: CGFloat = 28

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            iconImage
                .frame(width: size, height: size)

            if isActive {
                Circle()
                    .fill(.green)
                    .frame(width: max(8, size * 0.32), height: max(8, size * 0.32))
                    .overlay {
                        Circle().stroke(.background, lineWidth: 1.5)
                    }
                    .offset(x: size * 0.08, y: size * 0.08)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var iconImage: some View {
        if let image = appIcon {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "app")
                .resizable()
                .scaledToFit()
                .padding(size * 0.18)
                .foregroundStyle(.secondary)
        }
    }

    private var appIcon: NSImage? {
        if let appPath, !appPath.isEmpty {
            return NSWorkspace.shared.icon(forFile: appPath)
        }

        guard !bundleIdentifier.isEmpty,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }

        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
}
