import Foundation
import Combine

// MARK: - Tournament Statistics Manager
/// Manages real-time tournament statistics and ranking tracking
class TournamentStatsManager: ObservableObject {
    static let shared = TournamentStatsManager()
    
    @Published var currentRankings: [PlayerRanking] = []
    @Published var rankingHistory: [RankingSnapshot] = []
    @Published var playerTrends: [UUID: ChipTrend] = [:]
    @Published var eliminationOrder: [EliminationRecord] = []
    @Published var keyMoments: [TournamentMoment] = []
    
    private var cancellables = Set<AnyCancellable>()
    private var lastSnapshot: RankingSnapshot?
    
    private init() {}
    
    // MARK: - Data Structures
    
    struct PlayerRanking: Identifiable {
        let id = UUID()
        let playerId: UUID
        let name: String
        let avatar: String
        let chips: Int
        let rank: Int
        let change: Int // Change from previous rank (+ is better)
        let isHero: Bool
        let isEliminated: Bool
        let eliminationHand: Int?
    }
    
    struct RankingSnapshot {
        let handNumber: Int
        let timestamp: Date
        let rankings: [UUID: Int] // Player ID to rank
        let chipCounts: [UUID: Int]
    }
    
    struct ChipTrend {
        let playerId: UUID
        var history: [(hand: Int, chips: Int)]
        
        var peakChips: Int {
            history.map { $0.chips }.max() ?? 0
        }
        
        var currentChips: Int {
            history.last?.chips ?? 0
        }
        
        var netProfit: Int {
            guard let first = history.first, let last = history.last else { return 0 }
            return last.chips - first.chips
        }
    }
    
    struct EliminationRecord {
        let playerId: UUID
        let name: String
        let rank: Int
        let handNumber: Int
        let chipsWhenEliminated: Int
    }
    
    struct TournamentMoment {
        enum MomentType {
            case doubleUp
            case badBeat
            case bubbleBurst
            case finalTable
            case headsUp
            case champion
        }
        
        let type: MomentType
        let handNumber: Int
        let description: String
        let playerName: String
        let chips: Int?
    }
    
    // MARK: - Update Methods
    
    /// Call this after each hand to update statistics
    func updateAfterHand(handNumber: Int, players: [Player], engine: PokerEngine) {
        // Create new snapshot
        let sortedPlayers = players.sorted { $0.chips > $1.chips }
        var rankings: [UUID: Int] = [:]
        var chipCounts: [UUID: Int] = [:]
        
        for (index, player) in sortedPlayers.enumerated() {
            rankings[player.id] = index + 1
            chipCounts[player.id] = player.chips
        }
        
        let snapshot = RankingSnapshot(
            handNumber: handNumber,
            timestamp: Date(),
            rankings: rankings,
            chipCounts: chipCounts
        )
        
        // Calculate rank changes
        var newRankings: [PlayerRanking] = []
        for (index, player) in sortedPlayers.enumerated() {
            let currentRank = index + 1
            let previousRank = lastSnapshot?.rankings[player.id] ?? currentRank
            let rankChange = previousRank - currentRank // Positive means improved
            
            // Update chip trend
            updateChipTrend(for: player, handNumber: handNumber)
            
            // Check for elimination
            let isEliminated = player.chips <= 0
            if isEliminated && !eliminationOrder.contains(where: { $0.playerId == player.id }) {
                recordElimination(player: player, rank: currentRank, handNumber: handNumber, config: engine.tournamentConfig)
            }
            
            newRankings.append(PlayerRanking(
                playerId: player.id,
                name: player.name,
                avatar: player.aiProfile?.avatar ?? (player.isHuman ? "🤠" : "🤖"),
                chips: player.chips,
                rank: currentRank,
                change: rankChange,
                isHero: player.isHuman,
                isEliminated: isEliminated,
                eliminationHand: isEliminated ? handNumber : nil
            ))
        }
        
        // Check for key moments
        checkForKeyMoments(handNumber: handNumber, players: players, engine: engine)
        
        // Update published data
        currentRankings = newRankings
        rankingHistory.append(snapshot)
        lastSnapshot = snapshot
        
        // Keep history manageable (last 100 hands)
        if rankingHistory.count > 100 {
            rankingHistory.removeFirst()
        }
    }
    
    private func updateChipTrend(for player: Player, handNumber: Int) {
        if var trend = playerTrends[player.id] {
            trend.history.append((hand: handNumber, chips: player.chips))
            playerTrends[player.id] = trend
        } else {
            playerTrends[player.id] = ChipTrend(
                playerId: player.id,
                history: [(hand: handNumber, chips: player.chips)]
            )
        }
    }
    
    private func recordElimination(player: Player, rank: Int, handNumber: Int, config: TournamentConfig?) {
        let record = EliminationRecord(
            playerId: player.id,
            name: player.name,
            rank: rank,
            handNumber: handNumber,
            chipsWhenEliminated: player.chips
        )
        eliminationOrder.append(record)

        // Check for bubble (使用传入的 config 参数)
        if let config = config,
           eliminationOrder.count == config.totalEntrants - config.payoutStructure.count {
            keyMoments.append(TournamentMoment(
                type: .bubbleBurst,
                handNumber: handNumber,
                description: "\(player.name) 成为泡沫男孩",
                playerName: player.name,
                chips: player.chips
            ))
        }
    }
    
    private func checkForKeyMoments(handNumber: Int, players: [Player], engine: PokerEngine) {
        let activePlayers = players.filter { $0.chips > 0 }
        
        // Final table (9 players left)
        if activePlayers.count == 9 && !keyMoments.contains(where: { $0.type == .finalTable && $0.handNumber == handNumber }) {
            keyMoments.append(TournamentMoment(
                type: .finalTable,
                handNumber: handNumber,
                description: "进入决赛桌",
                playerName: "",
                chips: nil
            ))
        }
        
        // Heads up (2 players left)
        if activePlayers.count == 2 && !keyMoments.contains(where: { $0.type == .headsUp && $0.handNumber == handNumber }) {
            keyMoments.append(TournamentMoment(
                type: .headsUp,
                handNumber: handNumber,
                description: "进入单挑",
                playerName: "",
                chips: nil
            ))
        }
        
        // Champion (1 player left)
        if activePlayers.count == 1,
           let winner = activePlayers.first,
           !keyMoments.contains(where: { $0.type == .champion }) {
            keyMoments.append(TournamentMoment(
                type: .champion,
                handNumber: handNumber,
                description: "\(winner.name) 获得冠军！",
                playerName: winner.name,
                chips: winner.chips
            ))
        }
    }
    
    // MARK: - Query Methods
    
    /// Get rank change for a specific player over last N hands
    func rankChange(for playerId: UUID, overHands: Int = 5) -> Int {
        guard rankingHistory.count >= 2 else { return 0 }
        
        let recent = rankingHistory.suffix(overHands)
        guard let current = recent.last?.rankings[playerId],
              let previous = recent.first?.rankings[playerId] else {
            return 0
        }
        
        return previous - current // Positive means improved
    }
    
    /// Get chip trend data for charting
    func chipTrendData(for playerId: UUID) -> [(hand: Int, chips: Int)] {
        return playerTrends[playerId]?.history ?? []
    }
    
    /// Get biggest movers in last N hands
    func biggestMovers(overHands: Int = 5) -> [(playerId: UUID, name: String, change: Int)] {
        var movers: [(playerId: UUID, name: String, change: Int)] = []
        
        for ranking in currentRankings where !ranking.isEliminated {
            let change = rankChange(for: ranking.playerId, overHands: overHands)
            if abs(change) >= 2 { // Only significant changes
                movers.append((playerId: ranking.playerId, name: ranking.name, change: change))
            }
        }
        
        return movers.sorted { abs($0.change) > abs($1.change) }
    }
    
    /// Get tournament summary statistics
    func tournamentSummary() -> TournamentSummary {
        let totalHands = rankingHistory.last?.handNumber ?? 0
        let avgStack = currentRankings.filter { !$0.isEliminated }.map { $0.chips }.reduce(0, +) / max(1, currentRankings.filter { !$0.isEliminated }.count)
        
        return TournamentSummary(
            totalHands: totalHands,
            averageStack: avgStack,
            eliminations: eliminationOrder.count,
            keyMoments: keyMoments
        )
    }
    
    struct TournamentSummary {
        let totalHands: Int
        let averageStack: Int
        let eliminations: Int
        let keyMoments: [TournamentMoment]
    }
    
    // MARK: - Reset
    
    func reset() {
        currentRankings = []
        rankingHistory = []
        playerTrends = [:]
        eliminationOrder = []
        keyMoments = []
        lastSnapshot = nil
    }
}

// MARK: - Tournament Config Extension
/// 注意：不再使用静态变量追踪当前配置
/// 配置应该通过参数传递或依赖注入
extension TournamentConfig {
    // 已移除：static var current: TournamentConfig?
    // 如需追踪当前配置，请通过 PokerEngine 或其他上下文传递
}
