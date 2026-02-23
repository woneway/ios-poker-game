import Foundation

enum BettingPattern {
    case tight
    case loose
    case aggressive
    case passive
    case balanced
    
    var description: String {
        switch self {
        case .tight: return "紧"
        case .loose: return "松"
        case .aggressive: return "凶"
        case .passive: return "弱"
        case .balanced: return "平衡"
        }
    }
}

struct BettingHistory {
    var playerId: String
    var handNumber: Int
    var street: Street
    var action: PlayerAction
    var amount: Int
    var potSize: Int
}

class BettingPatternRecognizer {
    static let shared = BettingPatternRecognizer()
    
    private var history: [BettingHistory] = []
    private var patternCache: [String: BettingPattern] = [:]
    
    private init() {}
    
    func recordAction(playerId: String, handNumber: Int, street: Street, action: PlayerAction, potSize: Int) {
        let betAmount: Int
        switch action {
        case .raise(let amount):
            betAmount = amount
        default:
            betAmount = 0
        }
        
        let entry = BettingHistory(
            playerId: playerId,
            handNumber: handNumber,
            street: street,
            action: action,
            amount: betAmount,
            potSize: potSize
        )
        
        history.append(entry)
        patternCache.removeValue(forKey: playerId)
    }
    
    func recognizePattern(for playerId: String) -> BettingPattern {
        if let cached = patternCache[playerId] {
            return cached
        }
        
        let playerActions = history.filter { $0.playerId == playerId }
        guard playerActions.count >= 10 else {
            return .balanced
        }
        
        let betFrequency = calculateBetFrequency(playerActions)
        let raiseFrequency = calculateRaiseFrequency(playerActions)
        let checkFrequency = calculateCheckFrequency(playerActions)
        
        let pattern: BettingPattern
        
        if betFrequency > 0.4 && raiseFrequency > 0.2 {
            pattern = .aggressive
        } else if betFrequency < 0.15 && raiseFrequency < 0.1 {
            pattern = .passive
        } else if betFrequency > 0.35 {
            pattern = .loose
        } else if betFrequency < 0.2 {
            pattern = .tight
        } else {
            pattern = .balanced
        }
        
        patternCache[playerId] = pattern
        return pattern
    }
    
    private func calculateBetFrequency(_ actions: [BettingHistory]) -> Double {
        let bettingStreets = actions.filter { $0.street == .flop || $0.street == .turn || $0.street == .river }
        guard !bettingStreets.isEmpty else { return 0 }
        
        let bets = bettingStreets.filter {
            if case .raise = $0.action { return true }
            return false
        }
        
        return Double(bets.count) / Double(bettingStreets.count)
    }
    
    private func calculateRaiseFrequency(_ actions: [BettingHistory]) -> Double {
        let bettingStreets = actions.filter { $0.street == .flop || $0.street == .turn || $0.street == .river }
        guard !bettingStreets.isEmpty else { return 0 }
        
        let raises = bettingStreets.filter {
            if case .raise = $0.action { return true }
            return false
        }
        
        return Double(raises.count) / Double(bettingStreets.count)
    }
    
    private func calculateCheckFrequency(_ actions: [BettingHistory]) -> Double {
        let bettingStreets = actions.filter { $0.street == .flop || $0.street == .turn || $0.street == .river }
        guard !bettingStreets.isEmpty else { return 0 }
        
        let checks = bettingStreets.filter {
            if case .check = $0.action { return true }
            return false
        }
        
        return Double(checks.count) / Double(bettingStreets.count)
    }
    
    func getRecentActions(for playerId: String, lastNHands: Int = 10) -> [BettingHistory] {
        let maxHand = history.filter { $0.playerId == playerId }.map { $0.handNumber }.max() ?? 0
        return history.filter {
            $0.playerId == playerId && $0.handNumber > maxHand - lastNHands
        }
    }
    
    func clearHistory(for playerId: String? = nil) {
        if let playerId = playerId {
            history.removeAll { $0.playerId == playerId }
            patternCache.removeValue(forKey: playerId)
        } else {
            history.removeAll()
            patternCache.removeAll()
        }
    }
}
