import Foundation

/// Deduplicates rapid-fire events by remembering recently executed keys for a short TTL.
final class DeduplicationStore {
    private struct Entry {
        let key: String
        let timestamp: Date
    }

    private let ttl: TimeInterval
    private let capacity: Int
    private var ring: [Entry] = []
    private var index: Int = 0
    private let queue = DispatchQueue(label: "io.smalllight.dedup", qos: .userInteractive)

    init(ttl: TimeInterval, capacity: Int) {
        self.ttl = ttl
        self.capacity = capacity
        ring.reserveCapacity(capacity)
    }

    /// Returns `true` if the key has been seen within the TTL window.
    func isDuplicate(_ key: String, now: Date = Date()) -> Bool {
        queue.sync {
            purgeExpired(now: now)
            return ring.contains { $0.key == key }
        }
    }

    /// Records execution for the supplied key at `now`.
    func record(_ key: String, now: Date = Date()) {
        queue.sync {
            purgeExpired(now: now)
            let entry = Entry(key: key, timestamp: now)
            if ring.count < capacity {
                ring.append(entry)
            } else {
                ring[index] = entry
                index = (index + 1) % capacity
            }
        }
    }

    /// Removes the given key, allowing the action to re-run before TTL expires.
    func remove(_ key: String) {
        queue.sync {
            ring.removeAll { $0.key == key }
            if index >= ring.count {
                index = 0
            }
        }
    }

    private func purgeExpired(now: Date) {
        guard !ring.isEmpty else { return }
        let threshold = now.addingTimeInterval(-ttl)
        ring.removeAll { $0.timestamp < threshold }
        if index >= ring.count {
            index = 0
        }
    }
}
