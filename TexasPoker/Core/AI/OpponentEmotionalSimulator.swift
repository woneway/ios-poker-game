import Foundation

enum EmotionalState: String {
    case calm = "冷静"
    case focused = "专注"
    case confident = "自信"
    case frustrated = "沮丧"
    case nervous = "紧张"
    case tilted = "上头"
    case desperate = "孤注一掷"
    case scared = "恐惧"
}

struct EmotionalProfile {
    let playerId: String
    var currentState: EmotionalState
    var tiltLevel: Double
    var confidence: Double
    var stress: Double
    var recentEmotionalChanges: [EmotionalChange]
    
    var isOnTilt: Bool {
        return tiltLevel > 0.5
    }
    
    var isStressed: Bool {
        return stress > 0.6
    }
}

struct EmotionalChange {
    let timestamp: Date
    let fromState: EmotionalState
    let toState: EmotionalState
    let trigger: EmotionalTrigger
    let intensity: Double
}

enum EmotionalTrigger: String {
    case badBeat = "冤家牌"
    case coolers = "冷门牌"
    case bigWin = "大胜"
    case bigLoss = "大败"
    case missedDraw = "听牌失败"
    case hitDraw = "听牌成功"
    case bluffFailed = "诈笼失败"
    case bluffSucceeded = "诈笼成功"
    case timePressure = "时间压力"
    case chipLow = "筹码不足"
}

class OpponentEmotionalSimulator {
    static let shared = OpponentEmotionalSimulator()
    
    private var profiles: [String: EmotionalProfile] = [:]
    private let queue = DispatchQueue(label: "com.poker.emotion", attributes: .concurrent)
    
    private init() {}
    
    func initializePlayer(_ playerId: String) {
        queue.async(flags: .barrier) {
            self.profiles[playerId] = EmotionalProfile(
                playerId: playerId,
                currentState: .calm,
                tiltLevel: 0.0,
                confidence: 0.5,
                stress: 0.0,
                recentEmotionalChanges: []
            )
        }
    }
    
    func recordEvent(
        playerId: String,
        trigger: EmotionalTrigger,
        result: HandResult,
        potSize: Int
    ) {
        queue.async(flags: .barrier) {
            guard var profile = self.profiles[playerId] else {
                return
            }
            
            let intensity = self.calculateIntensity(trigger: trigger, result: result, potSize: potSize)
            let newState = self.determineNewState(
                currentState: profile.currentState,
                trigger: trigger,
                intensity: intensity
            )
            
            let change = EmotionalChange(
                timestamp: Date(),
                fromState: profile.currentState,
                toState: newState,
                trigger: trigger,
                intensity: intensity
            )
            
            profile.recentEmotionalChanges.append(change)
            if profile.recentEmotionalChanges.count > 20 {
                profile.recentEmotionalChanges.removeFirst()
            }
            
            profile.currentState = newState
            profile.tiltLevel = self.updateTiltLevel(profile.tiltLevel, change: change)
            profile.confidence = self.updateConfidence(profile.confidence, change: change)
            profile.stress = self.updateStress(profile.stress, change: change)
            
            self.profiles[playerId] = profile
        }
    }
    
    private func calculateIntensity(trigger: EmotionalTrigger, result: HandResult, potSize: Int) -> Double {
        var baseIntensity: Double = 0.3
        
        switch trigger {
        case .badBeat:
            baseIntensity = 0.8
        case .coolers:
            baseIntensity = 0.7
        case .bigWin:
            baseIntensity = 0.5
        case .bigLoss:
            baseIntensity = 0.7
        case .missedDraw:
            baseIntensity = 0.4
        case .hitDraw:
            baseIntensity = 0.3
        case .bluffFailed:
            baseIntensity = 0.5
        case .bluffSucceeded:
            baseIntensity = 0.3
        case .timePressure:
            baseIntensity = 0.4
        case .chipLow:
            baseIntensity = 0.6
        }
        
        let potMultiplier = min(Double(potSize) / 1000.0, 2.0)
        
        return baseIntensity * potMultiplier
    }
    
    private func determineNewState(currentState: EmotionalState, trigger: EmotionalTrigger, intensity: Double) -> EmotionalState {
        switch trigger {
        case .badBeat, .coolers, .bigLoss, .missedDraw:
            return degradeState(from: currentState, by: intensity)
            
        case .bigWin, .hitDraw, .bluffSucceeded:
            return improveState(from: currentState, by: intensity)
            
        case .chipLow:
            return .scared
            
        case .timePressure:
            return .nervous
            
        default:
            return currentState
        }
    }
    
    private func degradeState(from state: EmotionalState, by intensity: Double) -> EmotionalState {
        if intensity < 0.3 {
            return state
        }
        
        switch state {
        case .calm:
            return intensity > 0.5 ? .frustrated : .focused
        case .focused:
            return intensity > 0.4 ? .frustrated : .calm
        case .confident:
            return intensity > 0.6 ? .tilted : .frustrated
        case .frustrated:
            return intensity > 0.5 ? .tilted : .nervous
        case .nervous:
            return .tilted
        case .tilted:
            return .desperate
        case .desperate:
            return .desperate
        case .scared:
            return .desperate
        }
    }
    
    private func improveState(from state: EmotionalState, by intensity: Double) -> EmotionalState {
        if intensity < 0.3 {
            return state
        }
        
        switch state {
        case .calm:
            return .confident
        case .focused:
            return .confident
        case .confident:
            return .confident
        case .frustrated:
            return intensity > 0.5 ? .focused : .calm
        case .nervous:
            return .calm
        case .tilted:
            return intensity > 0.7 ? .focused : .frustrated
        case .desperate:
            return intensity > 0.8 ? .frustrated : .tilted
        case .scared:
            return .nervous
        }
    }
    
    private func updateTiltLevel(_ current: Double, change: EmotionalChange) -> Double {
        var newLevel = current
        
        switch change.trigger {
        case .badBeat, .coolers, .bigLoss:
            newLevel += change.intensity * 0.3
        case .missedDraw, .bluffFailed:
            newLevel += change.intensity * 0.15
        case .bigWin, .hitDraw, .bluffSucceeded:
            newLevel -= change.intensity * 0.2
        default:
            break
        }
        
        return min(max(newLevel, 0.0), 1.0)
    }
    
    private func updateConfidence(_ current: Double, change: EmotionalChange) -> Double {
        var newConf = current
        
        switch change.trigger {
        case .badBeat, .coolers, .bigLoss:
            newConf -= change.intensity * 0.2
        case .bigWin, .hitDraw, .bluffSucceeded:
            newConf += change.intensity * 0.25
        default:
            break
        }
        
        return min(max(newConf, 0.1), 0.9)
    }
    
    private func updateStress(_ current: Double, change: EmotionalChange) -> Double {
        var newStress = current
        
        switch change.trigger {
        case .bigLoss, .chipLow, .timePressure:
            newStress += change.intensity * 0.25
        case .bigWin:
            newStress -= change.intensity * 0.15
        default:
            break
        }
        
        return min(max(newStress, 0.0), 1.0)
    }
    
    func getEmotionalState(playerId: String) -> EmotionalState {
        return queue.sync {
            profiles[playerId]?.currentState ?? .calm
        }
    }
    
    func getEmotionalProfile(playerId: String) -> EmotionalProfile? {
        return queue.sync {
            profiles[playerId]
        }
    }
    
    func predictBehavioralChange(playerId: String) -> BehavioralPrediction? {
        return queue.sync {
            guard let profile = profiles[playerId] else {
                return nil
            }
            
            if profile.isOnTilt {
                return BehavioralPrediction(
                    likelyChange: .moreAggressive,
                    probability: profile.tiltLevel,
                    reason: "上头后更容易激进"
                )
            }
            
            if profile.isStressed {
                return BehavioralPrediction(
                    likelyChange: .morePassive,
                    probability: profile.stress,
                    reason: "压力大时更被动"
                )
            }
            
            if profile.confidence > 0.7 {
                return BehavioralPrediction(
                    likelyChange: .moreBluffing,
                    probability: profile.confidence - 0.5,
                    reason: "自信时更多诈笼"
                )
            }
            
            return nil
        }
    }
    
    func applyEmotionalAdjustment(playerId: String, to strategy: inout StrategyPlaybook) {
        queue.sync {
            guard let profile = profiles[playerId] else { return }
            
            switch profile.currentState {
            case .tilted, .desperate:
                strategy = .aggressive
            case .scared:
                strategy = .tight
            case .confident:
                strategy = .aggressive
            default:
                break
            }
        }
    }
}

struct BehavioralPrediction {
    enum ChangeType {
        case moreAggressive
        case morePassive
        case moreBluffing
        case moreCall
        case tightenUp
    }
    
    let likelyChange: ChangeType
    let probability: Double
    let reason: String
}

class EmotionalExploiter {
    static let shared = EmotionalExploiter()
    
    private init() {}
    
    func exploitEmotionalState(_ profile: EmotionalProfile, currentAction: PlayerAction, potSize: Int) -> ExploitationStrategy {
        if profile.isOnTilt {
            return ExploitationStrategy(
                action: .raise(potSize / 2),
                sizing: 1.2,
                reason: "对手上头，利用其激进倾向"
            )
        }
        
        if profile.isStressed {
            return ExploitationStrategy(
                action: .raise(potSize / 3),
                sizing: 0.8,
                reason: "对手压力大，多收取价值"
            )
        }
        
        switch profile.currentState {
        case .frustrated:
            return ExploitationStrategy(
                action: .call,
                sizing: 1.0,
                reason: "对手沮丧，可能放弃"
            )
            
        case .scared:
            return ExploitationStrategy(
                action: .raise(potSize / 2),
                sizing: 1.3,
                reason: "对手恐惧，更容易弃牌"
            )
            
        case .confident:
            return ExploitationStrategy(
                action: .raise(potSize / 2),
                sizing: 1.1,
                reason: "对手自信，可能支付"
            )
            
        default:
            return ExploitationStrategy(
                action: currentAction,
                sizing: 1.0,
                reason: "无特殊调整"
            )
        }
    }
}

struct ExploitationStrategy {
    let action: PlayerAction
    let sizing: Double
    let reason: String
}
