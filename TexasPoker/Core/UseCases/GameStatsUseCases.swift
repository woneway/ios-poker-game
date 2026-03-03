import Foundation

final class SaveGameStatsUseCase {
    private let statisticsCalculator: StatisticsCalculator
    private let dataAnalysisEngine: DataAnalysisEngine

    init(
        statisticsCalculator: StatisticsCalculator = .shared,
        dataAnalysisEngine: DataAnalysisEngine = .shared
    ) {
        self.statisticsCalculator = statisticsCalculator
        self.dataAnalysisEngine = dataAnalysisEngine
    }

    func execute(
        playerName: String,
        gameMode: GameMode,
        action: PlayerAction,
        won: Bool,
        amount: Int,
        profileId: String? = nil
    ) {
        statisticsCalculator.incrementalUpdate(
            playerName: playerName,
            playerUniqueId: nil,
            gameMode: gameMode,
            action: action,
            won: won,
            amount: amount,
            profileId: profileId
        )
    }

    func executeRecordHand(_ hand: DataAnalysisEngine.HandRecord) {
        dataAnalysisEngine.recordHand(hand)
    }
}

// MARK: - Leaderboard Cache

final class LeaderboardCache {
    static let shared = LeaderboardCache()

    private var cache: [String: CachedEntry] = [:]
    private let queue = DispatchQueue(label: "com.poker.leaderboard.cache", attributes: .concurrent)
    private let maxAge: TimeInterval = 30 // 30 seconds cache

    struct CachedEntry {
        let entries: [LeaderboardEntry]
        let timestamp: Date
    }

    func getEntries(for key: String) -> [LeaderboardEntry]? {
        queue.sync {
            guard let cached = cache[key] else { return nil }
            if Date().timeIntervalSince(cached.timestamp) > maxAge {
                cache.removeValue(forKey: key)
                return nil
            }
            return cached.entries
        }
    }

    func setEntries(_ entries: [LeaderboardEntry], for key: String) {
        queue.async(flags: .barrier) {
            self.cache[key] = CachedEntry(entries: entries, timestamp: Date())
        }
    }

    func invalidate(key: String) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
        }
    }

    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}

final class GetLeaderboardUseCase {
    private let statisticsCalculator: StatisticsCalculator

    init(statisticsCalculator: StatisticsCalculator = .shared) {
        self.statisticsCalculator = statisticsCalculator
    }

    func execute(gameMode: GameMode, limit: Int = 10, useCache: Bool = true) -> [LeaderboardEntry] {
        let cacheKey = "\(gameMode.rawValue)_\(limit)"

        // Check cache first
        if useCache, let cached = LeaderboardCache.shared.getEntries(for: cacheKey) {
            return cached
        }

        let allStats = statisticsCalculator.fetchAllPlayersStats(gameMode: gameMode)

        let entries = allStats
            .map { name, stats in
                LeaderboardEntry(
                    rank: 0,
                    playerName: name,
                    totalHands: stats.totalHands,
                    winRate: stats.totalHands > 0 ? Double(stats.handsWon) / Double(stats.totalHands) * 100 : 0,
                    totalProfit: stats.totalWinnings
                )
            }
            .sorted { $0.totalProfit > $1.totalProfit }
            .prefix(limit)
            .enumerated()
            .map { index, entry in
                var updated = entry
                updated.rank = index + 1
                return updated
            }

        // Cache the result
        if useCache {
            LeaderboardCache.shared.setEntries(entries, for: cacheKey)
        }

        return entries
    }

    /// Async version for background processing
    func executeAsync(gameMode: GameMode, limit: Int = 10) async -> [LeaderboardEntry] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let entries = self?.execute(gameMode: gameMode, limit: limit, useCache: false) ?? []
                continuation.resume(returning: entries)
            }
        }
    }

    /// Invalidate cache (call after data changes)
    func invalidateCache(gameMode: GameMode, limit: Int = 10) {
        let cacheKey = "\(gameMode.rawValue)_\(limit)"
        LeaderboardCache.shared.invalidate(key: cacheKey)
    }
}

struct LeaderboardEntry: Identifiable {
    var id: String { "\(rank)-\(playerName)" }
    var rank: Int
    var playerName: String
    var totalHands: Int
    var winRate: Double
    var totalProfit: Int
}
