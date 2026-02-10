import Foundation
import Combine

class Deck: ObservableObject {
    @Published var cards: [Card] = []
    
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
        guard !cards.isEmpty else { return nil }
        return cards.removeLast()
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
