import Foundation

struct EnhancedPlayerProfile: Codable, Identifiable {
    let id: String
    var name: String
    var avatar: String
    var level: Int
    var experience: Int
    var achievements: [Achievement]
    var statistics: DetailedStatistics
    var playingHistory: [PlayingSession]
    var favoriteStrategies: [String]
    var notes: String
    
    var levelTitle: String {
        switch level {
        case 1...5: return "新手"
        case 6...10: return "入门"
        case 11...20: return "进阶"
        case 21...40: return "熟练"
        case 41...60: return "专家"
        default: return "大师"
        }
    }
    
    var experienceToNextLevel: Int {
        return level * 1000 - experience
    }
    
    var progressToNextLevel: Double {
        let currentLevelExp = level * 1000 - 1000
        let nextLevelExp = level * 1000
        let progress = Double(experience - currentLevelExp) / Double(nextLevelExp - currentLevelExp)
        return max(0, min(1, progress))
    }
}

struct Achievement: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let iconName: String
    let unlockedAt: Date?
    let isUnlocked: Bool
    
    static func allAchievements() -> [Achievement] {
        return [
            Achievement(id: "first_win", name: "首胜", description: "赢得第一手牌", iconName: "star.fill", unlockedAt: nil, isUnlocked: false),
            Achievement(id: "ten_wins", name: "十连胜", description: "连续赢得10手牌", iconName: "flame.fill", unlockedAt: nil, isUnlocked: false),
            Achievement(id: "big_pot", name: "大池", description: "赢得10000以上彩池", iconName: "dollarsign.circle.fill", unlockedAt: nil, isUnlocked: false),
            Achievement(id: "royal_flush", name: "皇家同花顺", description: "击中皇家同花顺", iconName: "crown.fill", unlockedAt: nil, isUnlocked: false),
            Achievement(id: "tournament_winner", name: "冠军", description: "赢得锦标赛", iconName: "trophy.fill", unlockedAt: nil, isUnlocked: false),
            Achievement(id: "grinder", name: "勤奋", description: "完成1000手牌", iconName: "hammer.fill", unlockedAt: nil, isUnlocked: false)
        ]
    }
}

struct DetailedStatistics: Codable {
    var totalHands: Int
    var handsWon: Int
    var totalProfit: Int
    var biggestWin: Int
    var biggestLoss: Int
    
    var preflopStats: PreflopStats
    var postflopStats: PostflopStats
    var positionStats: [Int: PositionStats]
    var streetStats: [String: StreetStats]
    
    var winRate: Double {
        guard totalHands > 0 else { return 0 }
        return Double(handsWon) / Double(totalHands) * 100
    }
    
    var averageProfit: Double {
        guard totalHands > 0 else { return 0 }
        return Double(totalProfit) / Double(totalHands)
    }
}

struct PreflopStats: Codable {
    var openRaise: Int
    var threeBet: Int
    var fourBet: Int
    var coldCall: Int
    var squeeze: Int
    var totalVpip: Int
    
    var openRaiseFreq: Double {
        guard totalVpip > 0 else { return 0 }
        return Double(openRaise) / Double(totalVpip) * 100
    }
    
    var threeBetFreq: Double {
        guard openRaise > 0 else { return 0 }
        return Double(threeBet) / Double(openRaise) * 100
    }
}

struct PostflopStats: Codable {
    var cBet: Int
    var doubleBarrel: Int
    var tripleBarrel: Int
    var checkRaise: Int
    var float: Int
    var donkBet: Int
    
    var cBetSuccessRate: Double {
        guard cBet > 0 else { return 0 }
        return Double(cBet) / Double(cBet) * 50
    }
}

struct PositionStats: Codable {
    let position: Int
    var handsPlayed: Int
    var profit: Int
    
    var profitPerHand: Double {
        guard handsPlayed > 0 else { return 0 }
        return Double(profit) / Double(handsPlayed)
    }
}

struct StreetStats: Codable {
    let street: String
    var timesSeen: Int
    var timesBet: Int
    var timesChecked: Int
    var timesCalled: Int
    var timesFolded: Int
    
    var betFreq: Double {
        guard timesSeen > 0 else { return 0 }
        return Double(timesBet) / Double(timesSeen) * 100
    }
}

struct PlayingSession: Codable, Identifiable {
    let id: String
    let startTime: Date
    var endTime: Date?
    var handsPlayed: Int
    var profit: Int
    var gameType: GameType
    
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    
    enum GameType: String, Codable {
        case cashGame
        case tournament
        case sitAndGo
    }
}

class PlayerProfileManager {
    static let shared = PlayerProfileManager()
    
    private var profiles: [String: EnhancedPlayerProfile] = [:]
    private let queue = DispatchQueue(label: "com.poker.profile", attributes: .concurrent)
    
    private init() {}
    
    func createProfile(id: String, name: String, avatar: String = "person.circle") -> EnhancedPlayerProfile {
        let profile = EnhancedPlayerProfile(
            id: id,
            name: name,
            avatar: avatar,
            level: 1,
            experience: 0,
            achievements: Achievement.allAchievements(),
            statistics: DetailedStatistics(
                totalHands: 0,
                handsWon: 0,
                totalProfit: 0,
                biggestWin: 0,
                biggestLoss: 0,
                preflopStats: PreflopStats(
                    openRaise: 0,
                    threeBet: 0,
                    fourBet: 0,
                    coldCall: 0,
                    squeeze: 0,
                    totalVpip: 0
                ),
                postflopStats: PostflopStats(
                    cBet: 0,
                    doubleBarrel: 0,
                    tripleBarrel: 0,
                    checkRaise: 0,
                    float: 0,
                    donkBet: 0
                ),
                positionStats: [:],
                streetStats: [:]
            ),
            playingHistory: [],
            favoriteStrategies: [],
            notes: ""
        )
        
        queue.async(flags: .barrier) {
            self.profiles[id] = profile
        }
        
        return profile
    }
    
    func getProfile(id: String) -> EnhancedPlayerProfile? {
        return queue.sync {
            return profiles[id]
        }
    }
    
    func updateProfile(_ profile: EnhancedPlayerProfile) {
        queue.async(flags: .barrier) {
            self.profiles[profile.id] = profile
        }
    }
    
    func addExperience(to playerId: String, amount: Int) {
        queue.async(flags: .barrier) {
            guard var profile = self.profiles[playerId] else { return }
            
            profile.experience += amount
            
            while profile.experience >= profile.level * 1000 {
                profile.level += 1
            }
            
            self.profiles[playerId] = profile
        }
    }
    
    func unlockAchievement(for playerId: String, achievementId: String) {
        queue.async(flags: .barrier) {
            guard var profile = self.profiles[playerId] else { return }
            
            if let index = profile.achievements.firstIndex(where: { $0.id == achievementId }) {
                var achievement = profile.achievements[index]
                achievement = Achievement(
                    id: achievement.id,
                    name: achievement.name,
                    description: achievement.description,
                    iconName: achievement.iconName,
                    unlockedAt: Date(),
                    isUnlocked: true
                )
                profile.achievements[index] = achievement
            }
            
            self.profiles[playerId] = profile
        }
    }
    
    func recordHand(for playerId: String, profit: Int, won: Bool) {
        queue.async(flags: .barrier) {
            guard var profile = self.profiles[playerId] else { return }
            
            profile.statistics.totalHands += 1
            if won {
                profile.statistics.handsWon += 1
            }
            profile.statistics.totalProfit += profit
            
            if profit > profile.statistics.biggestWin {
                profile.statistics.biggestWin = profit
            }
            if profit < profile.statistics.biggestLoss {
                profile.statistics.biggestLoss = profit
            }
            
            self.profiles[playerId] = profile
        }
    }
}

extension EnhancedPlayerProfile {
    func toPlayerStats(gameMode: GameMode, isHuman: Bool) -> PlayerStats {
        let stats = self.statistics
        let vpip = Double(stats.preflopStats.totalVpip) / max(Double(stats.totalHands), 1) * 100
        let pfr = Double(stats.preflopStats.openRaise) / max(Double(stats.totalHands), 1) * 100
        let threeBetFreq = stats.preflopStats.threeBetFreq
        let wtsd = stats.streetStats["showdown"]?.timesSeen ?? 0
        let wsd = stats.streetStats["showdown"]?.timesBet ?? 0
        
        let af: Double = {
            let betRaise = Double(stats.postflopStats.cBet + stats.postflopStats.checkRaise)
            let call = Double(stats.postflopStats.float)
            return call > 0 ? betRaise / call : 0
        }()
        
        return PlayerStats(
            playerName: self.name,
            gameMode: gameMode,
            isHuman: isHuman,
            totalHands: stats.totalHands,
            vpip: vpip,
            pfr: pfr,
            af: af,
            wtsd: wtsd > 0 ? Double(wsd) / Double(wtsd) * 100 : 0,
            wsd: wsd > 0 ? Double(wsd) / Double(wtsd) * 100 : 0,
            threeBet: threeBetFreq,
            handsWon: stats.handsWon,
            totalWinnings: stats.totalProfit,
            totalInvested: max(abs(stats.totalProfit), 1)
        )
    }
    
    mutating func updateFromPlayerStats(_ stats: PlayerStats) {
        self.statistics.totalHands = stats.totalHands
        self.statistics.handsWon = stats.handsWon
        self.statistics.totalProfit = stats.totalWinnings
    }
}

extension PlayerStats {
    func toEnhancedProfile(id: String, name: String, avatar: String = "person.circle") -> EnhancedPlayerProfile {
        return EnhancedPlayerProfile(
            id: id,
            name: name,
            avatar: avatar,
            level: 1,
            experience: 0,
            achievements: Achievement.allAchievements(),
            statistics: DetailedStatistics(
                totalHands: totalHands,
                handsWon: handsWon,
                totalProfit: totalWinnings,
                biggestWin: max(totalWinnings, 0),
                biggestLoss: min(totalWinnings, 0),
                preflopStats: PreflopStats(
                    openRaise: Int(Double(totalHands) * pfr / 100),
                    threeBet: Int(Double(totalHands) * threeBet / 100),
                    fourBet: 0,
                    coldCall: 0,
                    squeeze: 0,
                    totalVpip: Int(Double(totalHands) * vpip / 100)
                ),
                postflopStats: PostflopStats(
                    cBet: 0,
                    doubleBarrel: 0,
                    tripleBarrel: 0,
                    checkRaise: 0,
                    float: 0,
                    donkBet: 0
                ),
                positionStats: [:],
                streetStats: [:]
            ),
            playingHistory: [],
            favoriteStrategies: [],
            notes: ""
        )
    }
}
