import Foundation

public actor CommandInbox<Result: Sendable> {
    private var results: [String: Result] = [:]
    private var insertionOrder: [String] = []
    private let capacity: Int

    public init(capacity: Int = 200) {
        self.capacity = max(capacity, 1)
    }

    public func cachedResult(for commandId: String) -> Result? {
        results[commandId]
    }

    public func store(_ result: Result, for commandId: String) {
        if results[commandId] == nil {
            insertionOrder.append(commandId)
        }
        results[commandId] = result
        trimIfNeeded()
    }

    private func trimIfNeeded() {
        while insertionOrder.count > capacity {
            let removedId = insertionOrder.removeFirst()
            results.removeValue(forKey: removedId)
        }
    }
}
