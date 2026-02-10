import Foundation

/// 发牌管理器 — 处理底牌和公共牌发放
enum DealingManager {

    /// 给所有活跃玩家发底牌（每人2张）
    /// - Parameters:
    ///   - deck: 牌堆（inout，会消耗牌）
    ///   - players: 玩家列表（inout，会添加底牌）
    ///   - dealerIndex: 庄家位置，从庄家下一位开始发
    static func dealHoleCards(
        deck: inout Deck,
        players: inout [Player],
        dealerIndex: Int
    ) {
        let playerCount = players.count
        guard playerCount > 0 else { return }

        for _ in 0..<2 {
            var idx = nextActiveIndex(after: dealerIndex, players: players)
            for _ in 0..<playerCount {
                if players[idx].status == .active || players[idx].status == .allIn {
                    if let card = deck.deal() {
                        players[idx].holeCards.append(card)
                    }
                }
                idx = (idx + 1) % playerCount
            }
        }
    }

    /// 发当前街的公共牌（burn + deal）
    /// - Parameters:
    ///   - deck: 牌堆
    ///   - communityCards: 公共牌（inout）
    ///   - currentStreet: 当前街（inout，会推进到下一街）
    static func dealStreetCards(
        deck: inout Deck,
        communityCards: inout [Card],
        currentStreet: inout Street
    ) {
        _ = deck.deal() // burn card

        switch currentStreet {
        case .preFlop:
            currentStreet = .flop
            if let c1 = deck.deal(), let c2 = deck.deal(), let c3 = deck.deal() {
                communityCards.append(contentsOf: [c1, c2, c3])
            }
        case .flop:
            currentStreet = .turn
            if let c = deck.deal() { communityCards.append(c) }
        case .turn:
            currentStreet = .river
            if let c = deck.deal() { communityCards.append(c) }
        case .river:
            break
        }
    }

    /// 计算从当前街到河牌还需发几条街
    static func streetsRemaining(from street: Street) -> Int {
        switch street {
        case .preFlop: return 3
        case .flop:    return 2
        case .turn:    return 1
        case .river:   return 0
        }
    }

    // MARK: - Private Helpers

    private static func nextActiveIndex(after index: Int, players: [Player]) -> Int {
        guard !players.isEmpty else { return 0 }
        let safeIndex = ((index % players.count) + players.count) % players.count
        var next = (safeIndex + 1) % players.count
        var attempts = 0
        while players[next].status != .active && attempts < players.count {
            next = (next + 1) % players.count
            attempts += 1
        }
        return next
    }
}
