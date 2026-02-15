import Foundation

// MARK: - AI Profile Extensions
/// 8 New AI Characters + Difficulty System

extension AIProfile {
    
    // MARK: - 8 New Characters
    
    /// 8. 新手鲍勃 (Newbie Bob) - Loose-Passive Fish
    /// VPIP 60%, PFR 5%, AF 0.8
    /// 经常limp入池，很少加注，喜欢跟注看牌
    static let newbieBob = AIProfile(
        name: "新手鲍勃",
        avatar: "🐟",
        description: "刚学打牌，什么牌都玩，从不弃牌",
        tightness: 0.25,
        aggression: 0.08,
        bluffFreq: 0.02,
        foldTo3Bet: 0.10,
        cbetFreq: 0.05,        // 被动玩家很少c-bet
        cbetTurnFreq: 0.03,
        positionAwareness: 0.05,
        tiltSensitivity: 0.4,
        callDownTendency: 0.90
    )
    
    /// 9. 紧弱玛丽 (Tight-Passive Mary)
    /// VPIP 12%, PFR 3%, AF 0.5
    /// 只打好牌，但是只跟注不加注，容易被挤出底池
    static let tightMary = AIProfile(
        name: "玛丽",
        avatar: "🐢",
        description: "只打好牌，但太被动，从不主动加注",
        tightness: 0.88,
        aggression: 0.15,
        bluffFreq: 0.01,
        foldTo3Bet: 0.45,
        cbetFreq: 0.10,        // 紧弱玩家很少c-bet
        cbetTurnFreq: 0.05,
        positionAwareness: 0.25,
        tiltSensitivity: 0.15,
        callDownTendency: 0.40
    )
    
    /// 10. 超紧尼特 (Nit Steve) - 比 Rock 更紧
    /// VPIP 6%, PFR 5%, AF 5.0
    /// 只玩 AA/KK/QQ/AK，几乎不参与任何牌
    static let nitSteve = AIProfile(
        name: "史蒂夫",
        avatar: "🥶",
        description: "超级紧凶，只玩顶级牌，一小时看不到几手牌",
        tightness: 0.95,
        aggression: 0.95,
        bluffFreq: 0.01,
        foldTo3Bet: 0.05,
        cbetFreq: 0.85,
        cbetTurnFreq: 0.70,
        positionAwareness: 0.15,
        tiltSensitivity: 0.05,
        callDownTendency: 0.05
    )
    
    /// 11. 诈唬王杰克 (Bluffing Jack)
    /// VPIP 45%, PFR 40%, AF 4.5
    /// 经常诈唬，难读，但容易被抓
    static let bluffJack = AIProfile(
        name: "杰克",
        avatar: "🎭",
        description: "诈唬狂魔，半池以上都是诈唬，容易被抓鸡",
        tightness: 0.40,
        aggression: 0.92,
        bluffFreq: 0.55,
        foldTo3Bet: 0.35,
        cbetFreq: 0.82,
        cbetTurnFreq: 0.68,
        positionAwareness: 0.70,
        tiltSensitivity: 0.25,
        callDownTendency: 0.20
    )
    
    /// 12. 短筹码专家 (Short Stack Sam)
    /// 擅长 push/fold 策略，经常 all-in
    static let shortStackSam = AIProfile(
        name: "山姆",
        avatar: "💰",
        description: "短筹码专家，要么全下要么弃牌",
        tightness: 0.60,
        aggression: 0.95,
        bluffFreq: 0.15,
        foldTo3Bet: 0.35,     // 短筹码不应该频繁fold 3bet
        cbetFreq: 0.90,
        cbetTurnFreq: 0.80,
        positionAwareness: 0.90,
        tiltSensitivity: 0.10,
        callDownTendency: 0.10
    )
    
    /// 13. 陷阱大师 (Trapper Tony)
    /// 喜欢慢打大牌，经常 check-raise
    static let trapperTony = AIProfile(
        name: "托尼",
        avatar: "🕸️",
        description: "陷阱大师，喜欢慢打大牌，check-raise 高手",
        tightness: 0.50,
        aggression: 0.70,
        bluffFreq: 0.20,
        foldTo3Bet: 0.55,
        cbetFreq: 0.60,        // 正常c-bet频率，只是偶尔慢打
        cbetTurnFreq: 0.50,
        positionAwareness: 0.75,
        tiltSensitivity: 0.12,
        callDownTendency: 0.35
    )
    
    /// 14. 天才少年 (Prodigy Pete)
    /// 适应性强，会根据对手调整策略
    static let prodigyPete = AIProfile(
        name: "皮特",
        avatar: "🧠",
        description: "天才少年，适应性强，会根据对手调整策略",
        tightness: 0.50,
        aggression: 0.65,
        bluffFreq: 0.28,
        foldTo3Bet: 0.50,
        cbetFreq: 0.68,
        cbetTurnFreq: 0.52,
        positionAwareness: 0.88,
        tiltSensitivity: 0.08,
        callDownTendency: 0.28
    )
    
    /// 15. 老手维克多 (Veteran Victor)
    /// 经验丰富，会针对对手弱点
    static let veteranVictor = AIProfile(
        name: "维克多",
        avatar: "🎖️",
        description: "老牌高手，经验丰富，专门抓鱼",
        tightness: 0.52,
        aggression: 0.60,
        bluffFreq: 0.22,
        foldTo3Bet: 0.48,
        cbetFreq: 0.62,
        cbetTurnFreq: 0.48,
        positionAwareness: 0.82,
        tiltSensitivity: 0.05,
        callDownTendency: 0.30
    )
    
    // MARK: - All AI Profiles
    
    static let allProfiles: [AIProfile] = [
        .rock,           // 1. 石头
        .maniac,         // 2. 疯子麦克
        .callingStation, // 3. 安娜
        .fox,            // 4. 老狐狸
        .shark,          // 5. 鲨鱼汤姆
        .academic,       // 6. 艾米
        .tiltDavid,      // 7. 大卫
        .newbieBob,      // 8. 新手鲍勃
        .tightMary,      // 9. 玛丽
        .nitSteve,       // 10. 史蒂夫
        .bluffJack,      // 11. 杰克
        .shortStackSam,  // 12. 山姆
        .trapperTony,    // 13. 托尼
        .prodigyPete,    // 14. 皮特
        .veteranVictor   // 15. 维克多
    ]
    
    // MARK: - Difficulty Levels
    
    enum Difficulty: String, CaseIterable, Identifiable {
        case easy = "简单"
        case normal = "普通"
        case hard = "困难"
        case expert = "专家"
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .easy: return "适合新手，对手较弱"
            case .normal: return "平衡体验，标准难度"
            case .hard: return "有挑战性，对手较强"
            case .expert: return "地狱模式，顶级对手"
            }
        }
        
        /// Profiles available at this difficulty level
        var availableProfiles: [AIProfile] {
            switch self {
            case .easy:
                return [.newbieBob, .tightMary, .callingStation, .maniac]
            case .normal:
                return [.newbieBob, .tightMary, .callingStation, .maniac, 
                       .rock, .fox, .tiltDavid]
            case .hard:
                return [.rock, .fox, .shark, .academic, .bluffJack, 
                       .trapperTony, .shortStackSam, .prodigyPete]
            case .expert:
                return [.shark, .academic, .prodigyPete, .veteranVictor,
                       .nitSteve, .shortStackSam, .trapperTony, .bluffJack]
            }
        }
        
        /// Returns random opponents for a game
        func randomOpponents(count: Int) -> [AIProfile] {
            let pool = availableProfiles
            guard !pool.isEmpty else { return [] }
            
            var selected: [AIProfile] = []
            for _ in 0..<count {
                if let profile = pool.randomElement(), !selected.contains(profile) {
                    selected.append(profile)
                } else {
                    // If duplicate or empty, pick any from pool
                    selected.append(pool.randomElement() ?? pool[0])
                }
            }
            return selected
        }
    }
    
    // MARK: - Tournament Entry System
    
    /// Random entry for tournament (can be called at any time)
    /// Returns new player to add to table
    static func randomTournamentEntry(difficulty: Difficulty, startingChips: Int) -> Player {
        let profile = difficulty.availableProfiles.randomElement() ?? .fox
        return Player(
            name: profile.name,
            chips: startingChips,
            isHuman: false,
            aiProfile: profile
        )
    }
    
    /// Random entry with custom starting stack based on tournament stage
    static func randomTournamentEntry(
        difficulty: Difficulty,
        stage: TournamentStage,
        averageStack: Int
    ) -> Player {
        let profile = difficulty.availableProfiles.randomElement() ?? .fox
        
        // Late stage players get adjusted stacks
        let startingChips: Int
        switch stage {
        case .early:
            startingChips = averageStack
        case .middle:
            startingChips = Int(Double(averageStack) * 0.8)
        case .late:
            startingChips = Int(Double(averageStack) * 0.6)
        case .finalTable:
            startingChips = Int(Double(averageStack) * 0.5)
        }
        
        return Player(
            name: profile.name,
            chips: max(1000, startingChips),
            isHuman: false,
            aiProfile: profile
        )
    }
}

// MARK: - Tournament Stage
enum TournamentStage {
    case early      // First few levels
    case middle     // Middle levels
    case late       // Approaching bubble
    case finalTable // Final table
    
    static func from(handNumber: Int, totalPlayers: Int) -> TournamentStage {
        let eliminationRate = Double(handNumber) / Double(totalPlayers * 10)
        
        switch eliminationRate {
        case 0..<0.3:
            return .early
        case 0.3..<0.6:
            return .middle
        case 0.6..<0.85:
            return .late
        default:
            return .finalTable
        }
    }
}

// MARK: - Game Setup Helper
struct GameSetup {
    let difficulty: AIProfile.Difficulty
    let playerCount: Int
    let startingChips: Int
    let gameMode: GameMode
    
    /// Generates player list including Hero and AI opponents
    func generatePlayers(heroName: String = "Hero") -> [Player] {
        var players: [Player] = []
        
        // Add Hero
        players.append(Player(name: heroName, chips: startingChips, isHuman: true))
        
        // Add AI opponents
        let aiCount = min(playerCount - 1, 7) // Max 8 players total
        let profiles = difficulty.randomOpponents(count: aiCount)
        
        for profile in profiles {
            players.append(Player(
                name: profile.name,
                chips: startingChips,
                isHuman: false,
                aiProfile: profile
            ))
        }
        
        return players
    }
    
    /// Static method for quick setup
    static func quickSetup(
        difficulty: AIProfile.Difficulty = .normal,
        playerCount: Int = 6,
        startingChips: Int = 1000,
        gameMode: GameMode = .cashGame
    ) -> GameSetup {
        return GameSetup(
            difficulty: difficulty,
            playerCount: playerCount,
            startingChips: startingChips,
            gameMode: gameMode
        )
    }
}
