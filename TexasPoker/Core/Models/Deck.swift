import Foundation
import os.log

private let logger = AppLogger.shared

nonisolated class Deck {
    var cards: [Card] = []
    
    init() {
        reset()
    }
    
    func reset() {
        cards.removeAll()
        
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                cards.append(Card(rank: rank, suit: suit))
            }
        }
        // reset 后自动洗牌，避免顺序可预测
        shuffle()
    }
    
    func shuffle() {
        cards.shuffle()
    }
    
    func deal() -> Card? {
        guard !cards.isEmpty else {
            #if DEBUG
            logger.warning("Deck.deal() 警告: 牌堆已空！", category: .game)
            #endif
            return nil
        }
        let card = cards.removeLast()
        #if DEBUG
        if cards.count < 10 {
            logger.warning("Deck.deal() 警告: 剩余 \(cards.count) 张牌", category: .game)
        }
        #endif
        return card
    }
    
    func deal(count: Int) -> [Card] {
        var result: [Card] = []
        for _ in 0..<count {
            if let card = deal() {
                result.append(card)
            }
        }
        return result
    }
    
    var remainingCount: Int {
        return cards.count
    }
}
