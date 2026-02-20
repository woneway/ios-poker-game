import Foundation

enum TiltLevel: Int {
    case calm = 0
    case minor = 1
    case moderate = 2
    case severe = 3
    case onTilt = 4
    
    var description: String {
        switch self {
        case .calm: return "冷静"
        case .minor: return "轻微波动"
        case .moderate: return "情绪波动"
        case .severe: return "严重上头"
        case .onTilt: return "完全失控"
        }
    }
    
    var decisionPenalty: Double {
        switch self {
        case .calm: return 0.0
        case .minor: return 0.05
        case .moderate: return 0.15
        case .severe: return 0.25
        case .onTilt: return 0.4
        }
    }
}

struct TiltTrigger {
    let type: TiltTriggerType
    let severity: Double
    let cooldown: TimeInterval
    
    enum TiltTriggerType {
        case badBeat
        case coolers
        case lostBigPot
        case suckedOut
        case streakLoss
    }
}

class EnhancedTiltManager {
    static let shared = EnhancedTiltManager()
    
    private var playerTilt: [String: TiltState] = [:]
    private let queue = DispatchQueue(label: "com.poker.tilt", attributes: .concurrent)
    
    struct TiltState {
        var level: TiltLevel
        var triggerCount: Int
        var lastTriggerTime: Date
        var recoveryStartTime: Date?
        
        var isRecovering: Bool {
            recoveryStartTime != nil
        }
        
        var recoveryProgress: Double {
            guard let start = recoveryStartTime else { return 0 }
            let elapsed = Date().timeIntervalSince(start)
            return min(elapsed / 300.0, 1.0)
        }
    }
    
    private init() {}
    
    func getTiltLevel(for playerId: String) -> TiltLevel {
        queue.sync {
            playerTilt[playerId]?.level ?? .calm
        }
    }
    
    func recordTiltTrigger(
        for playerId: String,
        trigger: TiltTrigger
    ) {
        queue.async(flags: .barrier) {
            var state = self.playerTilt[playerId] ?? TiltState(
                level: .calm,
                triggerCount: 0,
                lastTriggerTime: Date(),
                recoveryStartTime: nil
            )
            
            state.triggerCount += 1
            state.lastTriggerTime = Date()
            state.recoveryStartTime = nil
            
            if state.triggerCount >= 5 {
                state.level = .onTilt
            } else if state.triggerCount >= 3 {
                state.level = .severe
            } else if state.triggerCount >= 2 {
                state.level = .moderate
            } else if state.triggerCount >= 1 {
                state.level = .minor
            }
            
            self.playerTilt[playerId] = state
        }
    }
    
    func applyDecisionPenalty(for playerId: String, to equity: Double) -> Double {
        let level = getTiltLevel(for: playerId)
        return equity * (1.0 - level.decisionPenalty)
    }
    
    func startRecovery(for playerId: String) {
        queue.async(flags: .barrier) {
            self.playerTilt[playerId]?.recoveryStartTime = Date()
        }
    }
    
    func updateRecovery() {
        queue.async(flags: .barrier) {
            for (playerId, var state) in self.playerTilt {
                if state.isRecovering {
                    let progress = state.recoveryProgress
                    
                    if progress >= 1.0 {
                        state.level = .calm
                        state.triggerCount = 0
                        state.recoveryStartTime = nil
                    } else if progress >= 0.75 {
                        state.level = .minor
                    } else if progress >= 0.5 {
                        state.level = .moderate
                    } else if progress >= 0.25 {
                        state.level = .severe
                    }
                    
                    self.playerTilt[playerId] = state
                }
            }
        }
    }
    
    func reset(for playerId: String) {
        queue.async(flags: .barrier) {
            self.playerTilt.removeValue(forKey: playerId)
        }
    }
}

class TiltReactionAnalyzer {
    static let shared = TiltReactionAnalyzer()
    
    private init() {}
    
    func analyzeReaction(
        handResult: HandResult,
        potSize: Int,
        expectedEquity: Double,
        actualEquity: Double
    ) -> TiltTrigger? {
        let surprise = abs(actualEquity - expectedEquity)
        
        if handResult == .loss && potSize > 1000 && surprise > 0.3 {
            return TiltTrigger(
                type: .badBeat,
                severity: 0.8,
                cooldown: 120
            )
        }
        
        if handResult == .loss && actualEquity > 0.8 && potSize > 500 {
            return TiltTrigger(
                type: .coolers,
                severity: 0.7,
                cooldown: 60
            )
        }
        
        if handResult == .win && actualEquity < 0.3 {
            return TiltTrigger(
                type: .suckedOut,
                severity: 0.3,
                cooldown: 30
            )
        }
        
        return nil
    }
    
    func shouldIncreaseAggression(tiltLevel: TiltLevel) -> Bool {
        switch tiltLevel {
        case .severe, .onTilt:
            return true
        default:
            return false
        }
    }
    
    func adjustStrategyForTilt(
        baseStrategy: StrategyPlaybook,
        tiltLevel: TiltLevel
    ) -> StrategyPlaybook {
        switch tiltLevel {
        case .calm:
            return baseStrategy
        case .minor:
            return .aggressive
        case .moderate:
            return .bluffy
        case .severe:
            return .loose
        case .onTilt:
            return .callingStation
        }
    }
}

class OpponentTiltDetector {
    static let shared = OpponentTiltDetector()
    
    private var opponentBehaviorHistory: [String: [BehaviorPattern]] = [:]
    private let queue = DispatchQueue(label: "com.poker.opponent.tilt", attributes: .concurrent)
    
    struct BehaviorPattern {
        let timestamp: Date
        let action: PlayerAction
        let result: HandResult
        let potSize: Int
    }
    
    private init() {}
    
    func recordAction(
        playerId: String,
        action: PlayerAction,
        result: HandResult,
        potSize: Int
    ) {
        let pattern = BehaviorPattern(
            timestamp: Date(),
            action: action,
            result: result,
            potSize: potSize
        )
        
        queue.async(flags: .barrier) {
            self.opponentBehaviorHistory[playerId, default: []].append(pattern)
            
            if self.opponentBehaviorHistory[playerId]!.count > 50 {
                self.opponentBehaviorHistory[playerId]!.removeFirst()
            }
        }
    }
    
    func detectTilt(playerId: String) -> TiltLevel {
        return queue.sync { () -> TiltLevel in
            guard let history = opponentBehaviorHistory[playerId], history.count >= 5 else {
                return .calm
            }
            
            let recent = history.suffix(5)
            let aggressiveActions = recent.filter {
                if case .raise = $0.action { return true }
                if case .allIn = $0.action { return true }
                return false
            }
            let passiveActions = recent.filter {
                if case .call = $0.action { return true }
                if case .check = $0.action { return true }
                return false
            }
            
            let aggressiveRatio = Double(aggressiveActions.count) / Double(recent.count)
            
            if aggressiveRatio > 0.7 {
                return .moderate
            } else if aggressiveRatio > 0.5 {
                return .minor
            }
            
            let bigPotLosses = recent.filter { $0.result == .loss && $0.potSize > 500 }
            if bigPotLosses.count >= 3 {
                return .severe
            }
            
            return .calm
        }
    }
    
    func adjustStrategyForOpponentTilt(
        baseStrategy: StrategyPlaybook,
        opponentId: String
    ) -> StrategyPlaybook {
        let tiltLevel = detectTilt(playerId: opponentId)
        
        switch tiltLevel {
        case .calm:
            return baseStrategy
        case .minor:
            return .passive
        case .moderate:
            return .tight
        case .severe, .onTilt:
            return .bluffy
        }
    }
}
