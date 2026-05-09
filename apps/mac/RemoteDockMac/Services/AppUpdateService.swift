import AppKit
import Foundation
import RemoteDockCore

enum AppUpdateState: Equatable {
    case idle
    case checking
    case updateAvailable(version: String, releaseNotes: String, downloadURL: URL, assetSize: Int64)
    case downloading(progress: Double)
    case readyToInstall(appPath: URL)
    case upToDate(lastChecked: Date)
    case error(message: String)

    static func == (lhs: AppUpdateState, rhs: AppUpdateState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.checking, .checking),
             (.downloading, .downloading),
             (.readyToInstall, .readyToInstall):
            return true
        case let (.updateAvailable(lv, ln, lu, ls), .updateAvailable(rv, rn, ru, rs)):
            return lv == rv && ln == rn && lu == ru && ls == rs
        case let (.upToDate(ld), .upToDate(rd)):
            return ld == rd
        case let (.error(lm), .error(rm)):
            return lm == rm
        default:
            return false
        }
    }
}

// Localized error messages
private extension AppUpdateError {
    var localizedMessage: String {
        switch self {
        case .invalidURL:
            return NSLocalizedString("update.error.invalidURL", comment: "Invalid URL error")
        case .invalidResponse:
            return NSLocalizedString("update.error.invalidResponse", comment: "Invalid response error")
        case .unzipFailed:
            return NSLocalizedString("update.error.unzipFailed", comment: "Unzip failed error")
        case .appNotFound:
            return NSLocalizedString("update.error.appNotFound", comment: "App not found error")
        }
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let name: String
    let body: String
    let htmlURL: URL
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case assets
    }
}

private struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadURL: URL
    let size: Int64

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
    }
}

@MainActor
final class AppUpdateService: ObservableObject {
    @Published private(set) var state: AppUpdateState = .idle

    private let githubRepo = "kidoln/remotedock"
    private let session: URLSession
    private var backgroundCheckTask: Task<Void, Never>?

    private let skippedVersionKey = "remoteDock.mac.update.skippedVersion"
    private let lastCheckDateKey = "remoteDock.mac.update.lastCheckDate"

    var language: RemoteDockLanguage = .simplifiedChinese

    var skippedVersion: String? {
        get { UserDefaults.standard.string(forKey: skippedVersionKey) }
        set { UserDefaults.standard.set(newValue, forKey: skippedVersionKey) }
    }

    var lastCheckDate: Date? {
        get { UserDefaults.standard.object(forKey: lastCheckDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastCheckDateKey) }
    }

    init(session: URLSession = .shared) {
        self.session = session
    }

    func startPeriodicCheck() {
        backgroundCheckTask?.cancel()

        backgroundCheckTask = Task { [weak self] in
            guard let self else { return }

            // 首次检查延迟 30 秒
            try? await Task.sleep(for: .seconds(30))

            while !Task.isCancelled {
                await checkForUpdates()

                // 每 24 小时检查一次
                let checkInterval: TimeInterval = 24 * 60 * 60
                let deadline = Date().addingTimeInterval(checkInterval)

                while Date() < deadline, !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                }
            }
        }
    }

    func stopPeriodicCheck() {
        backgroundCheckTask?.cancel()
        backgroundCheckTask = nil
    }

    func checkForUpdates() async {
        state = .checking

        do {
            let release = try await fetchLatestRelease()
            guard let latestVersion = parseVersion(from: release.tagName),
                  let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
                state = .idle
                return
            }

            // 检查是否被用户跳过
            if let skipped = skippedVersion, skipped == latestVersion {
                state = .upToDate(lastChecked: Date())
                lastCheckDate = Date()
                return
            }

            // 比较版本
            let mismatch = RemoteDockAppVersionComparator.mismatch(
                local: currentVersion,
                remote: latestVersion
            )

            if mismatch == .remoteNewer {
                // 找到 ZIP 下载链接
                if let asset = findMacAsset(in: release.assets) {
                    state = .updateAvailable(
                        version: latestVersion,
                        releaseNotes: release.body,
                        downloadURL: asset.browserDownloadURL,
                        assetSize: asset.size
                    )
                } else {
                    state = .error(message: language.localizedString("update.error.noMacAsset"))
                }
            } else {
                state = .upToDate(lastChecked: Date())
            }

            lastCheckDate = Date()

        } catch {
            // 使用自定义错误消息，而不是系统的 localizedDescription
            let errorMessage: String
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    errorMessage = language.localizedString("update.error.timeout")
                case .cannotConnectToHost:
                    errorMessage = language.localizedString("update.error.connectionFailed")
                case .notConnectedToInternet:
                    errorMessage = language.localizedString("update.error.noConnection")
                default:
                    errorMessage = language.formattedLocalizedString("update.error.fetchFailed", urlError.localizedDescription)
                }
            } else {
                errorMessage = language.localizedString("update.error.unknown")
            }
            state = .error(message: errorMessage)
        }
    }

    func downloadUpdate() async {
        guard case let .updateAvailable(_, _, downloadURL, _) = state else {
            return
        }

        state = .downloading(progress: 0)

        do {
            let (tempURL, _) = try await session.download(for: URLRequest(url: downloadURL))

            // 创建临时目录
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("RemoteDockMac-update")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let destinationURL = tempDir.appendingPathComponent(downloadURL.lastPathComponent)
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            // 解压 ZIP
            let extractedAppURL = try await unzipArchive(at: destinationURL, to: tempDir)

            // 验证 .app 包存在
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: extractedAppURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                state = .error(message: language.localizedString("update.error.invalidAppPackage"))
                return
            }

            state = .readyToInstall(appPath: extractedAppURL)

        } catch {
            let errorMessage = language.formattedLocalizedString("update.error.downloadFailed", error.localizedDescription)
            state = .error(message: errorMessage)
        }
    }

    func installAndRelaunch() {
        guard case let .readyToInstall(newAppURL) = state else {
            return
        }

        Task {
            do {
                // 获取当前应用路径
                let currentAppURL = Bundle.main.bundleURL

                // 移动旧应用到废纸篓
                try? FileManager.default.trashItem(at: currentAppURL, resultingItemURL: nil)

                // 移动新应用到原位置
                let finalAppURL = currentAppURL.deletingLastPathComponent()
                    .appendingPathComponent(newAppURL.lastPathComponent)
                try FileManager.default.moveItem(at: newAppURL, to: finalAppURL)

                // 启动新应用
                NSWorkspace.shared.openApplication(at: finalAppURL, configuration: .init())

                // 退出当前应用
                NSApplication.shared.terminate(nil)

            } catch {
                let errorMessage = language.formattedLocalizedString("update.error.installFailed", error.localizedDescription)
                state = .error(message: errorMessage)
            }
        }
    }

    func skipCurrentVersion() {
        if case let .updateAvailable(version, _, _, _) = state {
            skippedVersion = version
            state = .idle
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        let urlString = "https://api.github.com/repos/\(githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else {
            throw AppUpdateError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AppUpdateError.invalidResponse
        }

        let decoder = JSONDecoder()
        return try decoder.decode(GitHubRelease.self, from: data)
    }

    private func parseVersion(from tagName: String) -> String? {
        // 移除 "v" 前缀（如 "v1.0.0" -> "1.0.0"）
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }

    private func findMacAsset(in assets: [GitHubAsset]) -> GitHubAsset? {
        // 查找 RemoteDockMac-*.zip 格式的文件
        assets.first { $0.name.hasPrefix("RemoteDockMac-") && $0.name.hasSuffix(".zip") }
    }

    private func unzipArchive(at sourceURL: URL, to destinationURL: URL) async throws -> URL {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", sourceURL.path, "-d", destinationURL.path]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw AppUpdateError.unzipFailed
        }

        // 查找解压后的 .app 包
        let contents = try FileManager.default.contentsOfDirectory(at: destinationURL, includingPropertiesForKeys: nil)
        if let appURL = contents.first(where: { $0.pathExtension == "app" }) {
            return appURL
        }

        throw AppUpdateError.appNotFound
    }
}

private enum AppUpdateError: Error {
    case invalidURL
    case invalidResponse
    case unzipFailed
    case appNotFound
}
