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
    var startingChips: Int = 0  // 本手牌开始时的筹码
    var holeCards: [Card] = []
    var status: PlayerStatus = .active
    var currentBet: Int = 0
    var totalBetThisHand: Int = 0  // 本手牌总投注额（跨所有 street 累计）
    
    /// 入场序号，用于区分同一 profile 的多次入场
    /// 例如："石头" 第一次入场 entryIndex = 1，第二次入场 entryIndex = 2
    var entryIndex: Int = 0
    
    var isHuman: Bool = false
    var aiProfile: AIProfile? = nil
    
    /// 玩家唯一标识：使用 profileName + entryIndex 格式
    /// 例如："石头#1", "老狐狸#2", "安娜#3"
    /// 对于没有 AIProfile 的玩家，使用 name + entryIndex
    /// entryIndex 为 0 时显示为 #0（表示尚未分配序号）
    var playerUniqueId: String {
        if let profile = aiProfile {
            return "\(profile.name)#\(entryIndex)"
        } else {
            return "\(name)#\(entryIndex)"
        }
    }
    
    /// 显示名称
    /// AI 玩家返回 playerUniqueId，人类玩家返回原始 name
    var displayName: String {
        if isHuman || aiProfile == nil {
            return name
        }
        return playerUniqueId
    }
    
    init(name: String, chips: Int, isHuman: Bool = false, aiProfile: AIProfile? = nil, entryIndex: Int = 0) {
        self.id = UUID()
        self.name = name
        self.chips = chips
        self.isHuman = isHuman
        self.aiProfile = aiProfile
        self.entryIndex = entryIndex
    }
    
    static func == (lhs: Player, rhs: Player) -> Bool {
        return lhs.id == rhs.id
            && lhs.chips == rhs.chips
            && lhs.holeCards == rhs.holeCards
            && lhs.status == rhs.status
            && lhs.currentBet == rhs.currentBet
            && lhs.totalBetThisHand == rhs.totalBetThisHand  // 修复：确保本手牌总投注额也参与比较
    }
}
