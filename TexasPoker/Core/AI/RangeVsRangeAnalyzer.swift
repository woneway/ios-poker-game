import Foundation

struct RangeData: Equatable {
    let combos: [String]
    let weight: Double
    
    static let anyTwo = RangeData(combos: ["*"], weight: 1.0)
    
    var totalCombos: Int {
        if combos.contains("*") { return 1326 }
        return combos.count
    }
    
    func contains(hand: [Card]) -> Bool {
        guard hand.count == 2 else { return false }
        let handStr = hand.map { $0.id }.sorted().joined()
        return combos.contains("*") || combos.contains(handStr)
    }
}

struct RangeMatchup {
    let player1Range: RangeData
    let player2Range: RangeData
    let communityCards: [Card]
    
    var player1Equity: Double {
        return calculateEquity(range1: player1Range, range2: player2Range)
    }
    
    var player2Equity: Double {
        return 1.0 - player1Equity
    }
    
    private func calculateEquity(range1: RangeData, range2: RangeData) -> Double {
        return 0.5
    }
}

class RangeVsRangeAnalyzer {
    static let shared = RangeVsRangeAnalyzer()
    
    private let queue = DispatchQueue(label: "com.poker.rangevsrange", attributes: .concurrent)
    
    private init() {}
    
    func analyzeRangeEquity(
        range1: RangeData,
        range2: RangeData,
        board: [Card]
    ) -> RangeEquityResult {
        return queue.sync {
            let matchup = RangeMatchup(
                player1Range: range1,
                player2Range: range2,
                communityCards: board
            )
            
            return RangeEquityResult(
                equity1: matchup.player1Equity,
                equity2: matchup.player2Equity,
                tieEquity: 0.0,
                combos1: range1.totalCombos,
                combos2: range2.totalCombos
            )
        }
    }
    
    func identifyBluffCatchers(
        opponentRange: RangeData,
        board: [Card],
        heroHand: [Card]
    ) -> [String] {
        return queue.sync {
            var bluffCatchers: [String] = []
            
            let heroStrength = evaluateHand(heroHand, board: board)
            
            for combo in opponentRange.combos {
                if combo == "*" { continue }
                
                let oppStrength = evaluateHandFromCombo(combo, board: board)
                
                if oppStrength < heroStrength && heroStrength < 0.7 {
                    bluffCatchers.append(combo)
                }
            }
            
            return bluffCatchers
        }
    }
    
    func calculateValueToBluffRatio(
        valueHands: [String],
        bluffHands: [String],
        board: [Card]
    ) -> Double {
        let valueCount = Double(valueHands.count)
        let bluffCount = Double(bluffHands.count)
        
        guard valueCount > 0 && bluffCount > 0 else { return 0 }
        
        return valueCount / bluffCount
    }
    
    func getOptimalBetSizing(
        range: RangeData,
        board: [Card],
        potSize: Int,
        stackSize: Int
    ) -> BetSizingRecommendation {
        let strongHands = filterStrongHands(range: range, board: board)
        let weakHands = filterWeakHands(range: range, board: board)
        
        let valueRatio = Double(strongHands.count) / Double(range.totalCombos)
        let bluffRatio = Double(weakHands.count) / Double(range.totalCombos)
        
        let polarize = valueRatio > 0.3 && bluffRatio > 0.15
        
        if polarize {
            let overbetRecommended = valueRatio > 0.5 && stackSize > potSize * 2
            return BetSizingRecommendation(
                minSize: potSize / 2,
                optimalSize: overbetRecommended ? potSize * 2 : potSize * 3 / 4,
                maxSize: stackSize,
                strategy: .polarized,
                reasoning: "价值牌比例 \(Int(valueRatio*100))%, 诈牌比例 \(Int(bluffRatio*100))%"
            )
        } else {
            return BetSizingRecommendation(
                minSize: potSize / 3,
                optimalSize: potSize * 2 / 3,
                maxSize: potSize,
                strategy: .linear,
                reasoning: "线性范围，适中尺度"
            )
        }
    }
    
    private func filterStrongHands(range: RangeData, board: [Card]) -> [String] {
        return range.combos.filter { combo in
            if combo == "*" { return false }
            let strength = evaluateHandFromCombo(combo, board: board)
            return strength > 0.7
        }
    }
    
    private func filterWeakHands(range: RangeData, board: [Card]) -> [String] {
        return range.combos.filter { combo in
            if combo == "*" { return false }
            let strength = evaluateHandFromCombo(combo, board: board)
            return strength < 0.3
        }
    }
    
    private func evaluateHand(_ hand: [Card], board: [Card]) -> Double {
        guard hand.count == 2 && board.count >= 3 else { return 0.5 }
        
        let result = HandEvaluator.evaluate(holeCards: hand, communityCards: board)
        
        switch result.0 {
        case 9...8: return 0.95
        case 7: return 0.9
        case 6: return 0.85
        case 5: return 0.8
        case 4: return 0.75
        case 3: return 0.65
        case 2: return 0.5
        case 1: return 0.4
        default: return 0.3
        }
    }
    
    private func evaluateHandFromCombo(_ combo: String, board: [Card]) -> Double {
        return 0.5
    }
}

struct RangeEquityResult {
    let equity1: Double
    let equity2: Double
    let tieEquity: Double
    let combos1: Int
    let combos2: Int
    
    var totalCombos: Int { combos1 + combos2 }
    
    var description: String {
        return "P1: \(Int(equity1*100))% (\(combos1) combos), P2: \(Int(equity2*100))% (\(combos2) combos)"
    }
}

struct BetSizingRecommendation {
    let minSize: Int
    let optimalSize: Int
    let maxSize: Int
    let strategy: BettingStrategy
    let reasoning: String
    
    enum BettingStrategy {
        case linear
        case polarized
        case underbalanced
    }
}

class RangeConstructionHelper {
    static let shared = RangeConstructionHelper()
    
    private init() {}
    
    func openRaiseRange(position: Int, tableSize: Int) -> [String] {
        let ranges: [[String]] = [
            ["AA", "KK", "QQ", "JJ", "TT", "99", "88", "77", "AKs", "AQs", "AJs", "ATs", "AKo"],
            ["AA", "KK", "QQ", "JJ", "TT", "99", "88", "AKs", "AQs", "AJs", "ATs", "AKo", "KQs"],
            ["AA", "KK", "QQ", "JJ", "TT", "99", "AKs", "AQs", "AJs", "AKo", "KQs", "KJs"],
            ["AA", "KK", "QQ", "JJ", "TT", "AKs", "AQs", "AKo", "KQs", "AJs"],
            ["AA", "KK", "QQ", "JJ", "AKs", "AQs", "AKo"],
            ["AA", "KK", "QQ", "AKs", "AQs", "AKo"],
            ["AA", "KK", "AKs", "AKo"]
        ]
        
        let index = min(position, ranges.count - 1)
        return ranges[index]
    }
    
    func get3BetRange(position: Int, isOOP: Bool) -> [String] {
        let oopRanges: [[String]] = [
            ["AA", "KK", "QQ", "JJ", "TT", "99", "88", "77", "AKs", "AQs", "AJs", "ATs", "AKo", "KQs", "KJs", "QJs", "JTs"],
            ["AA", "KK", "QQ", "JJ", "TT", "99", "88", "AKs", "AQs", "AJs", "ATs", "AKo", "KQs"],
            ["AA", "KK", "QQ", "JJ", "TT", "AKs", "AQs", "AJs", "AKo", "KQs"]
        ]
        
        let ipRanges: [[String]] = [
            ["AA", "KK", "QQ", "JJ", "TT", "99", "88", "77", "66", "55", "44", "33", "22", 
             "AKs", "AQs", "AJs", "ATs", "A9s", "A8s", "A7s", "A6s", "A5s", "A4s", "A3s", "A2s",
             "KQs", "KJs", "KTs", "QJs", "JTs", "T9s", "98s", "87s", "76s", "65s", "54s",
             "AKo", "KKo", "QQo", "JJo", "TTo", "AQo", "KQo"],
            ["AA", "KK", "QQ", "JJ", "TT", "99", "88", "77", "66", "55", "44", "33", "22",
             "AKs", "AQs", "AJs", "ATs", "A9s", "KQs", "KJs", "QJs", "JTs", "T9s", "98s",
             "AKo", "KKo", "QQo", "JJo", "TTo", "AQo", "KQo"],
            ["AA", "KK", "QQ", "JJ", "TT", "99", "88", "AKs", "AQs", "AJs", "ATs", "KQs", "QJs", "JTs",
             "AKo", "KKo", "QQo", "JJo", "TTo", "AQo"]
        ]
        
        let ranges = isOOP ? oopRanges : ipRanges
        let index = min(position, ranges.count - 1)
        return ranges[index]
    }
    
    func coldCallRange(position: Int, openPosition: Int) -> [String] {
        let callingRanges: [[String]] = [
            ["AA", "KK", "QQ", "JJ", "TT", "99", "88", "77", "66", "55", "44", "33", "22",
             "AKs", "AQs", "AJs", "ATs", "A9s", "KQs", "KJs", "KTs", "QJs", "JTs", "T9s",
             "AKo", "KKo", "QQo", "JJo", "TTo", "AQo", "KQo"],
            ["AA", "KK", "QQ", "JJ", "TT", "99", "88", "77", "66", "55", "44", "33", "22",
             "AKs", "AQs", "AJs", "ATs", "KQs", "KJs", "QJs", "JTs", "T9s",
             "AKo", "KKo", "QQo", "JJo", "TTo", "AQo", "KQo"],
            ["AA", "KK", "QQ", "JJ", "TT", "99", "88", "77", "66", "55",
             "AKs", "AQs", "AJs", "KQs", "KJs", "QJs", "JTs",
             "AKo", "KKo", "QQo", "JJo", "TTo", "AQo"]
        ]
        
        let index = min(position, callingRanges.count - 1)
        return callingRanges[index]
    }
    
    func convertToCombos(_ hands: [String]) -> [String] {
        var combos: [String] = []
        
        for hand in hands {
            if hand.contains("s") {
                let rank1 = hand.prefix(1)
                let rank2 = hand.dropFirst().prefix(1)
                let suits = ["h", "d", "c", "s"]
                for suit in suits {
                    combos.append(rank1 + suit + rank2 + suit)
                }
            } else if hand.contains("o") {
                let rank1 = hand.prefix(1)
                let rank2 = hand.dropFirst().prefix(1)
                let suits = ["h", "d", "c", "s"]
                for i in 0..<suits.count {
                    for j in (i+1)..<suits.count {
                        combos.append(rank1 + suits[i] + rank2 + suits[j])
                        combos.append(rank1 + suits[j] + rank2 + suits[i])
                    }
                }
            } else {
                combos.append(hand + "hh")
            }
        }
        
        return combos
    }
}
