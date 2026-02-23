import Foundation

enum HandPhase {
    case preflop
    case flop
    case turn
    case river
    case showdown
}

enum GameBoardTexture {
    case dry
    case wet
    case paired
    case rainbow
    
    static func analyze(communityCards: [Card]) -> GameBoardTexture {
        guard communityCards.count >= 3 else { return .dry }
        
        let suits = Set(communityCards.map { $0.suit })
        let ranks = communityCards.map { $0.rank.rawValue }
        let hasPair = ranks.count != Set(ranks).count
        
        if hasPair { return .paired }
        if suits.count == 1 { return .wet }
        if suits.count == communityCards.count { return .rainbow }
        
        let sortedRanks = ranks.sorted()
        var straightPotential = 0
        for i in 0..<(sortedRanks.count - 1) {
            if sortedRanks[i + 1] - sortedRanks[i] <= 4 {
                straightPotential += 1
            }
        }
        
        return straightPotential >= 2 ? .wet : .dry
    }
}

enum StrategyPlaybook: String, CaseIterable {
    case standard = "标准"
    case loose = "松散"
    case tight = "紧凶"
    case aggressive = "激进"
    case passive = "保守"
    case bluffy = "诈唬型"
    case callingStation = "跟注站"
    
    var description: String {
        switch self {
        case .standard: return "标准GTO风格"
        case .loose: return "松散入池，多手牌"
        case .tight: return "紧凶，只打强牌"
        case .aggressive: return "激进攻击，多加注"
        case .passive: return "被动防守，多跟注"
        case .bluffy: return "喜欢诈唬"
        case .callingStation: return "喜欢跟注到底"
        }
    }
    
    func adjustTightness(_ base: Double) -> Double {
        switch self {
        case .tight: return base * 0.7
        case .loose: return base * 1.3
        default: return base
        }
    }
    
    func adjustAggression(_ base: Double) -> Double {
        switch self {
        case .aggressive: return min(base * 1.3, 1.0)
        case .passive: return base * 0.7
        default: return base
        }
    }
    
    func adjustBluffFreq(_ base: Double) -> Double {
        switch self {
        case .bluffy: return min(base * 1.5, 0.8)
        case .tight: return base * 0.5
        default: return base
        }
    }
    
    func adjustCallDown(_ base: Double) -> Double {
        switch self {
        case .callingStation: return min(base * 1.4, 1.0)
        case .tight: return base * 0.6
        default: return base
        }
    }
}

struct PlaybookModifier {
    let playbook: StrategyPlaybook
    let handPhase: HandPhase
    let boardTexture: GameBoardTexture
    let position: Int
    
    func apply(to profile: AIProfile) -> AIProfile {
        var modified = profile
        
        modified.tightness = playbook.adjustTightness(profile.tightness)
        modified.aggression = playbook.adjustAggression(profile.aggression)
        modified.bluffFreq = playbook.adjustBluffFreq(profile.bluffFreq)
        modified.callDownTendency = playbook.adjustCallDown(profile.callDownTendency)
        
        modified = applyBoardTexture(modified)
        modified = applyPosition(modified)
        
        return modified
    }
    
    private func applyBoardTexture(_ profile: AIProfile) -> AIProfile {
        var modified = profile
        
        switch boardTexture {
        case .dry:
            modified.bluffFreq *= 1.2
            modified.aggression *= 1.1
        case .wet:
            modified.bluffFreq *= 0.7
            modified.callDownTendency *= 1.2
        case .paired:
            modified.bluffFreq *= 0.8
            modified.aggression *= 0.9
        case .rainbow:
            modified.bluffFreq *= 1.0
        }
        
        return modified
    }
    
    private func applyPosition(_ profile: AIProfile) -> AIProfile {
        var modified = profile
        
        if position == 0 {
            modified.tightness *= 1.1
            modified.aggression *= 0.9
        } else if position >= 6 {
            modified.tightness *= 0.9
            modified.bluffFreq *= 1.15
        }
        
        return modified
    }
}

class StrategyPlaybookManager {
    static let shared = StrategyPlaybookManager()
    
    private var currentPlaybook: [String: StrategyPlaybook] = [:]
    private var phaseCount: [String: Int] = [:]
    
    private init() {}
    
    func getPlaybook(for playerId: String) -> StrategyPlaybook {
        if let playbook = currentPlaybook[playerId] {
            return playbook
        }
        return .standard
    }
    
    func assignRandomPlaybook(to playerId: String) {
        let playbooks = StrategyPlaybook.allCases
        currentPlaybook[playerId] = playbooks.randomElement() ?? .standard
    }
    
    func adjustPlaybook(for playerId: String, basedOn result: GameResult) {
        guard var playbook = currentPlaybook[playerId] else { return }
        
        phaseCount[playerId, default: 0] += 1
        
        switch result {
        case .win:
            if phaseCount[playerId]! % 5 == 0 {
                playbook = escalateAggression(playbook)
            }
        case .loss:
            if phaseCount[playerId]! % 3 == 0 {
                playbook = adjustForLoss(playbook)
            }
        case .split:
            break
        }
        
        currentPlaybook[playerId] = playbook
    }
    
    private func escalateAggression(_ playbook: StrategyPlaybook) -> StrategyPlaybook {
        switch playbook {
        case .tight: return .standard
        case .standard: return .aggressive
        case .aggressive: return .bluffy
        default: return playbook
        }
    }
    
    private func adjustForLoss(_ playbook: StrategyPlaybook) -> StrategyPlaybook {
        switch playbook {
        case .aggressive: return .passive
        case .bluffy: return .tight
        case .loose: return .tight
        default: return playbook
        }
    }
    
    func resetPlaybook(for playerId: String) {
        currentPlaybook.removeValue(forKey: playerId)
        phaseCount.removeValue(forKey: playerId)
    }
}

enum GameResult {
    case win
    case loss
    case split
}
