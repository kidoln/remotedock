import AppKit
import Foundation
import RemoteDockCore

struct CatalogApp: Identifiable, Equatable {
    var id: String { bundleIdentifier }
    var bundleIdentifier: String
    var displayName: String
    var appPath: String

    func pinnedApp(sortOrder: Int) -> PinnedApp {
        PinnedApp(
            id: bundleIdentifier,
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            appPath: appPath,
            iconAssetHash: bundleIdentifier,
            sortOrder: sortOrder
        )
    }
}

final class AppCatalogService {
    private let fileManager: FileManager
    private let searchURLs: [URL]

    init(
        fileManager: FileManager = .default,
        searchURLs: [URL]? = nil
    ) {
        self.fileManager = fileManager
        self.searchURLs = searchURLs ?? Self.defaultSearchURLs(fileManager: fileManager)
    }

    func installedApplications() -> [CatalogApp] {
        var appsByBundleId: [String: CatalogApp] = [:]

        for rootURL in searchURLs {
            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey, .localizedNameKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let appURL as URL in enumerator where appURL.pathExtension == "app" {
                guard let bundle = Bundle(url: appURL),
                      let bundleIdentifier = bundle.bundleIdentifier,
                      !bundleIdentifier.isEmpty else {
                    continue
                }

                let displayName = displayName(for: bundle, appURL: appURL)
                guard !displayName.isEmpty else {
                    continue
                }

                appsByBundleId[bundleIdentifier] = CatalogApp(
                    bundleIdentifier: bundleIdentifier,
                    displayName: displayName,
                    appPath: appURL.path
                )
            }
        }

        return appsByBundleId.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private func displayName(for bundle: Bundle, appURL: URL) -> String {
        if let localizedName = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String {
            return localizedName
        }

        if let localizedName = bundle.localizedInfoDictionary?["CFBundleName"] as? String {
            return localizedName
        }

        if let displayName = bundle.infoDictionary?["CFBundleDisplayName"] as? String {
            return displayName
        }

        if let name = bundle.infoDictionary?["CFBundleName"] as? String {
            return name
        }

        return appURL.deletingPathExtension().lastPathComponent
    }

    private static func defaultSearchURLs(fileManager: FileManager) -> [URL] {
        var urls = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Library/CoreServices")
        ]

        if let userApplicationsURL = fileManager.urls(for: .applicationDirectory, in: .userDomainMask).first {
            urls.append(userApplicationsURL)
        }

        return urls
    }
}
