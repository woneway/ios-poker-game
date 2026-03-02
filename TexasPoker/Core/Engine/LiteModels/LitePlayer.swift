import Foundation

/// 轻量级玩家数据结构
struct LitePlayer: Identifiable, Equatable {
    let id: UUID
    let name: String
    var chips: Int
    var holeCards: [Card] = []
    var status: PlayerStatus = .active
    var currentBet: Int = 0
    var totalBetThisHand: Int = 0
    var isHuman: Bool = false
    var aiProfile: AIProfile? = nil

    init(id: UUID = UUID(), name: String, chips: Int, isHuman: Bool = false, aiProfile: AIProfile? = nil) {
        self.id = id
        self.name = name
        self.chips = chips
        self.isHuman = isHuman
        self.aiProfile = aiProfile
    }
}
