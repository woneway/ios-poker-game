import Foundation

enum PlayerStatus: Equatable {
    case active       // Still in the hand
    case folded       // Folded this hand
    case allIn        // All chips in
    case sittingOut   // Not playing
    case eliminated   // 0 chips
}

struct Player: Identifiable, Equatable {
    let id: UUID
    let name: String
    var chips: Int
    var holeCards: [Card] = []
    var status: PlayerStatus = .active
    var currentBet: Int = 0
    var totalBetThisHand: Int = 0  // 本手牌总投注额（跨所有 street 累计）
    
    var isHuman: Bool = false
    var aiProfile: AIProfile? = nil
    
    init(name: String, chips: Int, isHuman: Bool = false, aiProfile: AIProfile? = nil) {
        self.id = UUID()
        self.name = name
        self.chips = chips
        self.isHuman = isHuman
        self.aiProfile = aiProfile
    }
    
    static func == (lhs: Player, rhs: Player) -> Bool {
        return lhs.id == rhs.id
            && lhs.chips == rhs.chips
            && lhs.holeCards == rhs.holeCards
            && lhs.status == rhs.status
            && lhs.currentBet == rhs.currentBet
    }
}
