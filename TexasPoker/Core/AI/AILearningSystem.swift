import Foundation

struct HandPattern: Codable, Equatable {
    let holeCards: [String]
    let position: Int
    let preflopAction: String
    let communityCards: [String]
    let street: String
    let action: String
    let result: String
    let timestamp: Date
    
    init(
        holeCards: [Card],
        position: Int,
        preflopAction: PlayerAction,
        communityCards: [Card],
        street: Street,
        action: PlayerAction,
        result: HandResult
    ) {
        self.holeCards = holeCards.map { "\($0.rank.rawValue)\($0.suit.rawValue)" }
        self.position = position
        self.preflopAction = preflopAction.description
        self.communityCards = communityCards.map { "\($0.rank.rawValue)\($0.suit.rawValue)" }
        self.street = street.rawValue
        self.action = action.description
        self.result = result.rawValue
        self.timestamp = Date()
    }
}

enum HandResult: String, Codable {
    case win
    case loss
    case split
}

class AILearningSystem {
    static let shared = AILearningSystem()
    
    private var handHistory: [HandPattern] = []
    private var playerPatterns: [String: [HandPattern]] = [:]
    private let maxHistorySize = 1000
    
    private let queue = DispatchQueue(label: "com.poker.ai.learning", attributes: .concurrent)
    
    private init() {}
    
    func recordHand(_ pattern: HandPattern) {
        queue.async(flags: .barrier) {
            self.handHistory.append(pattern)
            
            if self.handHistory.count > self.maxHistorySize {
                self.handHistory.removeFirst(self.handHistory.count - self.maxHistorySize)
            }
            
            let playerKey = "\(pattern.position)_\(pattern.preflopAction)"
            self.playerPatterns[playerKey, default: []].append(pattern)
        }
    }
    
    func getPatternsFor(position: Int, preflopAction: String) -> [HandPattern] {
        queue.sync {
            let key = "\(position)_\(preflopAction)"
            return playerPatterns[key] ?? []
        }
    }
    
    func analyzePlayerTendency(playerId: String) -> PlayerTendencyAnalysis {
        queue.sync {
            let playerHands = handHistory.filter { $0.timestamp > Date().addingTimeInterval(-3600) }
            
            guard !playerHands.isEmpty else {
                return PlayerTendencyAnalysis(
                    tendency: .unknown,
                    confidence: 0,
                    sampleSize: 0,
                    recommendedStrategy: .standard
                )
            }
            
            let vpip = Double(playerHands.filter { $0.preflopAction != "fold" }.count) / Double(playerHands.count)
            let betCount = playerHands.filter { $0.action == "bet" || $0.action == "raise" }.count
            let betRatio = Double(betCount) / Double(playerHands.count)
            
            var tendency: PlayerTendency
            var recommendedStrategy: StrategyPlaybook
            
            if vpip > 0.45 && betRatio < 0.15 {
                tendency = .callingStation
                recommendedStrategy = .callingStation
            } else if vpip > 0.35 && betRatio > 0.25 {
                tendency = .lag
                recommendedStrategy = .aggressive
            } else if vpip < 0.20 && betRatio > 0.20 {
                tendency = .tag
                recommendedStrategy = .tight
            } else if vpip < 0.15 {
                tendency = .nit
                recommendedStrategy = .tight
            } else if betRatio > 0.35 {
                tendency = .lag
                recommendedStrategy = .bluffy
            } else {
                tendency = .abc
                recommendedStrategy = .standard
            }
            
            let confidence = min(1.0, Double(playerHands.count) / 100.0)
            
            return PlayerTendencyAnalysis(
                tendency: tendency,
                confidence: confidence,
                sampleSize: playerHands.count,
                recommendedStrategy: recommendedStrategy
            )
        }
    }
    
    func getSuccessfulBluffPatterns() -> [HandPattern] {
        queue.sync {
            handHistory.filter { pattern in
                pattern.action == "bet" || pattern.action == "raise"
            }
        }
    }
    
    func getCallDownPatterns() -> [HandPattern] {
        queue.sync {
            handHistory.filter { pattern in
                pattern.action == "call" && pattern.result == "win"
            }
        }
    }
    
    func clearHistory() {
        queue.async(flags: .barrier) {
            self.handHistory.removeAll()
            self.playerPatterns.removeAll()
        }
    }
}

struct PlayerTendencyAnalysis {
    let tendency: PlayerTendency
    let confidence: Double
    let sampleSize: Int
    let recommendedStrategy: StrategyPlaybook
    
    var isReliable: Bool {
        sampleSize >= 30 && confidence >= 0.3
    }
}

class AdaptiveDifficultyManager {
    static let shared = AdaptiveDifficultyManager()
    
    private var playerWinHistory: [Int] = []
    private var currentDifficulty: DifficultyLevel = .medium
    private let historySize = 20
    
    private init() {}
    
    func recordHandResult(won: Bool, profit: Int) {
        playerWinHistory.append(won ? 1 : 0)
        
        if playerWinHistory.count > historySize {
            playerWinHistory.removeFirst()
        }
        
        adjustDifficultyIfNeeded()
    }
    
    private func adjustDifficultyIfNeeded() {
        guard playerWinHistory.count >= 10 else { return }
        
        let winRate = Double(playerWinHistory.filter { $0 == 1 }.count) / Double(playerWinHistory.count)
        
        if winRate > 0.7 && currentDifficulty.rawValue > 1 {
            currentDifficulty = DifficultyLevel(rawValue: currentDifficulty.rawValue - 1) ?? .easy
        } else if winRate < 0.3 && currentDifficulty.rawValue < 4 {
            currentDifficulty = DifficultyLevel(rawValue: currentDifficulty.rawValue + 1) ?? .expert
        }
    }
    
    func getCurrentDifficulty() -> DifficultyLevel {
        return currentDifficulty
    }
    
    func setDifficulty(_ level: DifficultyLevel) {
        currentDifficulty = level
        playerWinHistory.removeAll()
    }
    
    func reset() {
        playerWinHistory.removeAll()
        currentDifficulty = .medium
    }
}

final class AIDecisionCache {
    private var cache: [String: CachedDecision] = [:]
    private let queue = DispatchQueue(label: "com.poker.ai.cache", attributes: .concurrent)
    private let maxAge: TimeInterval = 30
    
    struct CachedDecision {
        let decision: PlayerAction
        let timestamp: Date
    }
    
    func getDecision(
        for hand: [Card],
        community: [Card],
        position: Int,
        street: Street,
        playerId: String
    ) -> PlayerAction? {
        let key = generateKey(hand: hand, community: community, position: position, street: street, playerId: playerId)
        
        return queue.sync {
            guard let cached = cache[key] else { return nil }
            if Date().timeIntervalSince(cached.timestamp) > maxAge {
                cache.removeValue(forKey: key)
                return nil
            }
            return cached.decision
        }
    }
    
    func cacheDecision(_ decision: PlayerAction, for hand: [Card], community: [Card], position: Int, street: Street, playerId: String) {
        let key = generateKey(hand: hand, community: community, position: position, street: street, playerId: playerId)
        
        queue.async(flags: .barrier) {
            self.cache[key] = CachedDecision(decision: decision, timestamp: Date())
        }
    }
    
    private func generateKey(hand: [Card], community: [Card], position: Int, street: Street, playerId: String) -> String {
        let handStr = hand.map { $0.id }.sorted().joined()
        let communityStr = community.map { $0.id }.sorted().joined()
        return "\(playerId)_\(position)_\(street.rawValue)_\(handStr)_\(communityStr)"
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}
