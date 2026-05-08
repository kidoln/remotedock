import AppKit
import Foundation
import RemoteDockCore
import RemoteDockProtocol

final class AppIconAssetService {
    private let pixelDimension = 128

    func manifest(for pinnedApps: [PinnedApp], runningApps: [RunningApp]) -> IconManifestPayload {
        let assets = iconDescriptors(for: pinnedApps, runningApps: runningApps)
            .compactMap { asset(for: $0) }

        return IconManifestPayload(assets: assets)
    }

    func payloads(
        for hashes: [String],
        pinnedApps: [PinnedApp],
        runningApps: [RunningApp]
    ) -> [IconPayload] {
        let descriptorsByHash = Dictionary(
            uniqueKeysWithValues: iconDescriptors(for: pinnedApps, runningApps: runningApps).map { ($0.hash, $0) }
        )

        return hashes.compactMap { hash in
            guard let descriptor = descriptorsByHash[hash],
                  let icon = renderedIcon(for: descriptor) else {
                return nil
            }

            let asset = AppIconAsset(
                hash: hash,
                pixelWidth: pixelDimension,
                pixelHeight: pixelDimension,
                bytesLength: icon.count
            )

            return IconPayload(asset: asset, base64PNGData: icon.base64EncodedString())
        }
    }

    private func asset(for descriptor: IconDescriptor) -> AppIconAsset? {
        guard let icon = renderedIcon(for: descriptor) else {
            return nil
        }

        return AppIconAsset(
            hash: descriptor.hash,
            pixelWidth: pixelDimension,
            pixelHeight: pixelDimension,
            bytesLength: icon.count
        )
    }

    private func iconDescriptors(for pinnedApps: [PinnedApp], runningApps: [RunningApp]) -> [IconDescriptor] {
        var descriptorsByHash: [String: IconDescriptor] = [:]

        for app in pinnedApps {
            guard let hash = app.iconAssetHash, !hash.isEmpty else {
                continue
            }

            descriptorsByHash[hash] = IconDescriptor(
                hash: hash,
                bundleIdentifier: app.bundleIdentifier,
                appPath: app.appPath
            )
        }

        for app in runningApps {
            guard let hash = app.iconAssetHash, !hash.isEmpty else {
                continue
            }

            if descriptorsByHash[hash]?.appPath?.isEmpty == false {
                continue
            }

            descriptorsByHash[hash] = IconDescriptor(
                hash: hash,
                bundleIdentifier: app.bundleIdentifier,
                appPath: nil
            )
        }

        return descriptorsByHash.values.sorted {
            $0.hash.localizedCaseInsensitiveCompare($1.hash) == .orderedAscending
        }
    }

    private func renderedIcon(for descriptor: IconDescriptor) -> Data? {
        guard let image = appIcon(for: descriptor) else {
            return nil
        }

        let size = NSSize(width: pixelDimension, height: pixelDimension)
        let renderedImage = NSImage(size: size)

        renderedImage.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.draw(in: NSRect(origin: .zero, size: size))
        renderedImage.unlockFocus()

        guard let tiffData = renderedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }

    private func appIcon(for descriptor: IconDescriptor) -> NSImage? {
        if let runningIcon = runningApplicationIcon(bundleIdentifier: descriptor.bundleIdentifier) {
            return runningIcon
        }

        if let appPath = descriptor.appPath, !appPath.isEmpty, FileManager.default.fileExists(atPath: appPath) {
            return NSWorkspace.shared.icon(forFile: appPath)
        }

        guard !descriptor.bundleIdentifier.isEmpty,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: descriptor.bundleIdentifier) else {
            return nil
        }

        return NSWorkspace.shared.icon(forFile: appURL.path)
    }

    private func runningApplicationIcon(bundleIdentifier: String) -> NSImage? {
        guard !bundleIdentifier.isEmpty else {
            return nil
        }

        return NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == bundleIdentifier
        }?.icon
    }
}

private struct IconDescriptor: Hashable {
    var hash: String
    var bundleIdentifier: String
    var appPath: String?
}
