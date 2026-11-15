import Foundation

public struct WeakSpot: Equatable, Sendable {
    public let category: String
    public let displayName: String
    public let count: Int
    public let lastSeen: Date
    public let example: MistakeEntry
}

public struct MistakeTally: Codable, Equatable, Sendable {
    private struct Stat: Codable, Equatable, Sendable {
        var count: Int
        var lastSeen: Date
        var example: MistakeEntry
    }

    private var stats: [String: Stat] = [:]

    public init() {}

    public mutating func record(_ entries: [MistakeEntry], on date: Date) {
        for entry in entries {
            if var stat = stats[entry.category] {
                stat.count += 1
                stat.lastSeen = max(stat.lastSeen, date)
                stats[entry.category] = stat
            } else {
                stats[entry.category] = Stat(count: 1, lastSeen: date, example: entry)
            }
        }
    }

    public func top(_ n: Int = 3) -> [WeakSpot] {
        stats
            .sorted { lhs, rhs in
                if lhs.value.count != rhs.value.count { return lhs.value.count > rhs.value.count }
                if lhs.value.lastSeen != rhs.value.lastSeen { return lhs.value.lastSeen > rhs.value.lastSeen }
                return lhs.key < rhs.key
            }
            .prefix(n)
            .map { WeakSpot(category: $0.key, displayName: Self.displayName(for: $0.key), count: $0.value.count, lastSeen: $0.value.lastSeen, example: $0.value.example) }
    }

    public static func displayName(for category: String) -> String {
        category.replacingOccurrences(of: "_", with: " ")
    }
}
