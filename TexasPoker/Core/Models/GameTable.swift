import Foundation
import Combine
import SwiftUI

struct GameTable: Identifiable {
    let id: UUID
    let tableNumber: Int
    let gameMode: GameMode
    let difficulty: AIProfile.Difficulty
    let smallBlind: Int
    let bigBlind: Int
    let maxPlayers: Int
    let currentPlayers: Int
    let players: [TablePlayer]
    let buyInRange: ClosedRange<Int>
    
    var tableName: String {
        "桌 #\(tableNumber)"
    }
    
    var stakesText: String {
        "$\(smallBlind)/$\(bigBlind)"
    }
    
    var playerCountText: String {
        "\(currentPlayers)/\(maxPlayers)"
    }
    
    var isFull: Bool {
        currentPlayers >= maxPlayers
    }
}

struct TablePlayer: Identifiable {
    let id: UUID
    let name: String
    let avatar: AvatarType
    let aiProfile: AIProfile?
    let chips: Int
    let isHero: Bool
    
    var gameStyle: String {
        guard let profile = aiProfile else { return "玩家" }
        return profile.gameStyleDescription
    }
    
    var difficulty: Int {
        guard let profile = aiProfile else { return 1 }
        return profile.difficultyRating
    }
    
    var characteristics: String {
        guard let profile = aiProfile else { return "人类玩家" }
        return profile.shortDescription
    }
}

extension AIProfile {
    var gameStyleDescription: String {
        let tightness = self.tightness
        let aggression = self.aggression
        
        if tightness > 0.7 && aggression > 0.6 {
            return "紧凶"
        } else if tightness > 0.7 && aggression < 0.4 {
            return "紧弱"
        } else if tightness < 0.4 && aggression > 0.6 {
            return "松凶"
        } else if tightness < 0.4 && aggression < 0.4 {
            return "松弱"
        } else if aggression > 0.6 {
            return "激进"
        } else if aggression < 0.3 {
            return "被动"
        } else {
            return "平衡"
        }
    }
    
    var difficultyRating: Int {
        let allProfiles = AIProfile.allProfiles
        guard let index = allProfiles.firstIndex(where: { $0.id == self.id }) else {
            return 3
        }
        
        let difficultyTiers: [[String]] = [
            ["newbie_bob", "tight_mary", "calling_station", "maniac"],
            ["rock", "fox", "tilt_david"],
            ["shark", "academic", "bluff_jack", "trapper_tony", "short_stack_sam", "prodigy_pete"],
            ["nit_steve", "veteran_victor"]
        ]
        
        for (tierIndex, tier) in difficultyTiers.enumerated() {
            if tier.contains(self.id) {
                return tierIndex + 1
            }
        }
        
        return 3
    }
    
    var shortDescription: String {
        switch self.id {
        case "rock": return "只玩超强牌"
        case "maniac": return "疯狂激进"
        case "calling_station": return "跟注站"
        case "fox": return "狡猾多变"
        case "shark": return "精准凶悍"
        case "academic": return "GTO风格"
        case "tilt_david": return "容易上头"
        case "newbie_bob": return "从不错过"
        case "tight_mary": return "只跟不攻"
        case "nit_steve": return "超紧nit"
        case "bluff_jack": return "诈唬狂魔"
        case "short_stack_sam": return "短码专家"
        case "trapper_tony": return "陷阱大师"
        case "prodigy_pete": return "自适应"
        case "veteran_victor": return "抓鱼高手"
        default: return "标准风格"
        }
    }
}

class TableManager: ObservableObject {
    static let shared = TableManager()
    
    @Published var tables: [GameTable] = []
    @Published var selectedDifficulty: AIProfile.Difficulty = .normal
    @Published var selectedGameMode: GameMode = .cashGame
    
    private let tableCount = 10
    
    private init() {
        generateTables()
    }
    
    func generateTables() {
        var newTables: [GameTable] = []
        let difficulties = AIProfile.Difficulty.allCases
        var usedDifficulties: Set<AIProfile.Difficulty> = []
        
        for i in 1...tableCount {
            let mode: GameMode = i % 2 == 0 ? .tournament : .cashGame
            
            let availableDifficulties = difficulties.filter { !usedDifficulties.contains($0) || usedDifficulties.count >= difficulties.count }
            let difficulty: AIProfile.Difficulty
            if availableDifficulties.isEmpty {
                difficulty = difficulties.randomElement() ?? .normal
            } else {
                difficulty = availableDifficulties.randomElement() ?? .normal
                usedDifficulties.insert(difficulty)
                if usedDifficulties.count >= difficulties.count {
                    usedDifficulties.removeAll()
                }
            }
            
            let (smallBlind, bigBlind) = generateBlinds(for: difficulty)
            let players = generatePlayers(for: difficulty, mode: mode)
            
            let table = GameTable(
                id: UUID(),
                tableNumber: i,
                gameMode: mode,
                difficulty: difficulty,
                smallBlind: smallBlind,
                bigBlind: bigBlind,
                maxPlayers: 8,
                currentPlayers: players.count,
                players: players,
                buyInRange: bigBlind * 40...(bigBlind * 100)
            )
            newTables.append(table)
        }
        
        tables = newTables.shuffled()
    }
    
    func regenerateWithFilter() {
        var filteredTables: [GameTable] = []
        
        for i in 1...tableCount {
            let difficulty = selectedDifficulty
            let mode = selectedGameMode
            
            let (smallBlind, bigBlind) = generateBlinds(for: difficulty)
            let players = generatePlayers(for: difficulty, mode: mode)
            
            let table = GameTable(
                id: UUID(),
                tableNumber: i,
                gameMode: mode,
                difficulty: difficulty,
                smallBlind: smallBlind,
                bigBlind: bigBlind,
                maxPlayers: 8,
                currentPlayers: players.count,
                players: players,
                buyInRange: bigBlind * 40...(bigBlind * 100)
            )
            filteredTables.append(table)
        }
        
        tables = filteredTables
    }
    
    private func generateBlinds(for difficulty: AIProfile.Difficulty) -> (Int, Int) {
        switch difficulty {
        case .easy:
            return (1, 2)
        case .normal:
            return (5, 10)
        case .hard:
            return (25, 50)
        case .expert:
            return (100, 200)
        }
    }
    
    private func generatePlayers(for difficulty: AIProfile.Difficulty, mode: GameMode) -> [TablePlayer] {
        var tablePlayers: [TablePlayer] = []
        
        let aiPlayerCount = 7
        
        let selectedProfiles = difficulty.randomOpponents(count: aiPlayerCount)
        
        for profile in selectedProfiles {
            tablePlayers.append(TablePlayer(
                id: UUID(),
                name: profile.name,
                avatar: profile.avatar,
                aiProfile: profile,
                chips: Int.random(in: 800...1500),
                isHero: false
            ))
        }
        
        tablePlayers.append(TablePlayer(
            id: UUID(),
            name: "Hero",
            avatar: .emoji("🤠"),
            aiProfile: nil,
            chips: 1000,
            isHero: true
        ))
        
        return tablePlayers.shuffled()
    }
    
    func filteredTables() -> [GameTable] {
        return tables.filter { table in
            table.gameMode == selectedGameMode
        }.filter { table in
            table.difficulty == selectedDifficulty
        }
    }
}
