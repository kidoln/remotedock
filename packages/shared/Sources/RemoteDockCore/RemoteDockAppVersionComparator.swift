import Foundation

public enum RemoteDockAppVersionMismatch: Equatable, Sendable {
    case localNewer
    case remoteNewer
}

public enum RemoteDockAppVersionComparator {
    public static func mismatch(local localVersion: String?, remote remoteVersion: String?) -> RemoteDockAppVersionMismatch? {
        guard let localComponents = comparableComponents(from: localVersion),
              let remoteComponents = comparableComponents(from: remoteVersion) else {
            return nil
        }

        let componentCount = max(localComponents.count, remoteComponents.count)
        for index in 0..<componentCount {
            let localComponent = localComponents[safe: index] ?? 0
            let remoteComponent = remoteComponents[safe: index] ?? 0

            if localComponent > remoteComponent {
                return .localNewer
            }

            if localComponent < remoteComponent {
                return .remoteNewer
            }
        }

        return nil
    }

    private static func comparableComponents(from version: String?) -> [Int]? {
        guard let version else {
            return nil
        }

        let components = version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ".", omittingEmptySubsequences: false)
            .compactMap { component -> Int? in
                let numericPrefix = component.prefix { $0.isNumber }
                guard !numericPrefix.isEmpty else {
                    return nil
                }

                return Int(numericPrefix)
            }

        guard !components.isEmpty else {
            return nil
        }

        return components
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
