import Foundation
import Combine

/// A single player's final result in a game
struct PlayerResult: Codable, Identifiable {
    var id: String { name }
    let name: String
    let avatar: String
    let rank: Int          // 1 = winner, 2 = runner-up, etc.
    let finalChips: Int    // Chips when eliminated (0) or final chip count for winner
    let handsPlayed: Int   // Hand number when eliminated, or total hands for winner
    let isHuman: Bool
}

/// A complete game record
struct GameRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let totalHands: Int
    let totalPlayers: Int
    let results: [PlayerResult]   // Sorted by rank (1st place first)
    let heroRank: Int             // Hero's finishing position
    
    init(date: Date = Date(), totalHands: Int, totalPlayers: Int, results: [PlayerResult], heroRank: Int) {
        self.id = UUID()
        self.date = date
        self.totalHands = totalHands
        self.totalPlayers = totalPlayers
        self.results = results.sorted { $0.rank < $1.rank }
        self.heroRank = heroRank
    }
}

/// Manages game history persistence using UserDefaults
class GameHistoryManager: ObservableObject {
    static let shared = GameHistoryManager()
    
    private let storageKey = "poker_game_history"
    
    @Published var records: [GameRecord] = []
    
    private init() {
        loadRecords()
    }
    
    func saveRecord(_ record: GameRecord) {
        records.insert(record, at: 0)
        // Keep last 100 records
        if records.count > 100 {
            records = Array(records.prefix(100))
        }
        persistRecords()
    }
    
    func clearHistory() {
        records.removeAll()
        persistRecords()
    }
    
    private func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([GameRecord].self, from: data) else {
            records = []
            return
        }
        records = decoded
    }
    
    private func persistRecords() {
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}
