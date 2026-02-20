import Foundation

struct HandHistoryRecord: Codable {
    let id: UUID
    let timestamp: Date
    let holeCards: [String]
    let position: Int
    let preflopAction: String
    let communityCards: [String]
    let streetActions: [StreetAction]
    let finalHand: String?
    let result: HandResult
    let profit: Int
    let potSize: Int
    
    struct StreetAction: Codable {
        let street: String
        let action: String
        let amount: Int?
    }
    
    init(
        holeCards: [Card],
        position: Int,
        preflopAction: PlayerAction,
        communityCards: [Card],
        streetActions: [StreetAction],
        finalHand: String?,
        result: HandResult,
        profit: Int,
        potSize: Int
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.holeCards = holeCards.map { $0.id }
        self.position = position
        self.preflopAction = preflopAction.description
        self.communityCards = communityCards.map { $0.id }
        self.streetActions = streetActions
        self.finalHand = finalHand
        self.result = result
        self.profit = profit
        self.potSize = potSize
    }
}

struct PositionAnalysis {
    let position: Int
    let handsPlayed: Int
    let vpip: Double
    let pfr: Double
    let threeBet: Double
    let cbet: Double
    let winRate: Double
    let avgProfit: Double
    
    var isProfitable: Bool {
        return avgProfit > 0
    }
}

struct StreetAnalysis {
    let street: Street
    let timesSeen: Int
    let checkRate: Double
    let betRate: Double
    let callRate: Double
    let raiseRate: Double
    let foldToBet: Double
    
    var mostCommonAction: String {
        let rates = [("check", checkRate), ("bet", betRate), ("call", callRate), ("raise", raiseRate)]
        return rates.max(by: { $0.1 < $1.1 })?.0 ?? "unknown"
    }
}

struct LeakAnalysis {
    let type: LeakType
    let severity: Double
    let description: String
    let recommendation: String
    
    enum LeakType: String {
        case overvaluing = "高估牌力"
        case callingTooMuch = "跟注过多"
        case foldingTooMuch = "弃牌过多"
        case bettingTooSmall = "下注太小"
        case bettingTooBig = "下注太大"
        case positional = "位置意识差"
        case tilt = "情绪失控"
        case bluffingTooMuch = "诈笼过多"
        case notProtecting = "未保护手牌"
    }
}

class HandHistoryAnalyzer {
    static let shared = HandHistoryAnalyzer()
    
    private var handHistory: [String: [HandHistoryRecord]] = [:]
    private let queue = DispatchQueue(label: "com.poker.history.analyzer", attributes: .concurrent)
    
    private init() {}
    
    func recordHand(playerId: String, record: HandHistoryRecord) {
        queue.async(flags: .barrier) {
            self.handHistory[playerId, default: []].append(record)
            
            if self.handHistory[playerId]!.count > 1000 {
                self.handHistory[playerId]!.removeFirst(100)
            }
        }
    }
    
    func getPositionAnalysis(playerId: String) -> [PositionAnalysis] {
        return queue.sync {
            guard let records = handHistory[playerId], !records.isEmpty else {
                return []
            }
            
            var positionStats: [Int: [HandHistoryRecord]] = [:]
            for record in records {
                positionStats[record.position, default: []].append(record)
            }
            
            return positionStats.map { position, hands in
                let played = hands.filter { $0.preflopAction != "fold" }.count
                let vpip = played > 0 ? Double(played) / Double(hands.count) : 0
                
                let raised = hands.filter { $0.preflopAction.contains("raise") || $0.preflopAction.contains("All In") }.count
                let pfr = played > 0 ? Double(raised) / Double(played) : 0
                
                let wins = hands.filter { $0.result == .win }.count
                let winRate = hands.count > 0 ? Double(wins) / Double(hands.count) : 0
                
                let totalProfit = hands.reduce(0) { $0 + $1.profit }
                let avgProfit = hands.count > 0 ? Double(totalProfit) / Double(hands.count) : 0
                
                return PositionAnalysis(
                    position: position,
                    handsPlayed: hands.count,
                    vpip: vpip,
                    pfr: pfr,
                    threeBet: 0,
                    cbet: 0,
                    winRate: winRate,
                    avgProfit: avgProfit
                )
            }
        }
    }
    
    func getStreetAnalysis(playerId: String) -> [StreetAnalysis] {
        return queue.sync {
            guard let records = handHistory[playerId], !records.isEmpty else {
                return []
            }
            
            var streetStats: [Street: [HandHistoryRecord.StreetAction]] = [:]
            
            for record in records {
                for action in record.streetActions {
                    if let street = Street(rawValue: action.street.lowercased()) {
                        streetStats[street, default: []].append(action)
                    }
                }
            }
            
            return streetStats.map { street, actions in
                let checks = actions.filter { $0.action == "check" }.count
                let bets = actions.filter { $0.action == "bet" || $0.action == "raise" }.count
                let calls = actions.filter { $0.action == "call" }.count
                let folds = actions.filter { $0.action == "fold" }.count
                
                let total = actions.count
                
                return StreetAnalysis(
                    street: street,
                    timesSeen: total,
                    checkRate: total > 0 ? Double(checks) / Double(total) : 0,
                    betRate: total > 0 ? Double(bets) / Double(total) : 0,
                    callRate: total > 0 ? Double(calls) / Double(total) : 0,
                    raiseRate: total > 0 ? Double(bets) / Double(total) : 0,
                    foldToBet: bets + folds > 0 ? Double(folds) / Double(bets + folds) : 0
                )
            }
        }
    }
    
    func detectLeaks(playerId: String) -> [LeakAnalysis] {
        return queue.sync {
            guard let records = handHistory[playerId], records.count >= 20 else {
                return []
            }
            
            var leaks: [LeakAnalysis] = []
            
            let recent = records.suffix(50)
            
            let callingStations = recent.filter { record in
                let calls = record.streetActions.filter { $0.action == "call" }.count
                let bets = record.streetActions.filter { $0.action == "bet" || $0.action == "raise" }.count
                return calls > bets && record.result == .loss && record.potSize > 500
            }
            
            if Double(callingStations.count) / Double(recent.count) > 0.15 {
                leaks.append(LeakAnalysis(
                    type: .callingTooMuch,
                    severity: Double(callingStations.count) / Double(recent.count),
                    description: "在输掉的牌局中跟注过多",
                    recommendation: "评估牌力，不够强时考虑弃牌"
                ))
            }
            
            let nitPlay = recent.filter { record in
                record.preflopAction == "fold" && record.position >= 4
            }
            
            if Double(nitPlay.count) / Double(recent.count) > 0.5 {
                leaks.append(LeakAnalysis(
                    type: .foldingTooMuch,
                    severity: Double(nitPlay.count) / Double(recent.count),
                    description: "翻前弃牌率过高（位置靠后时）",
                    recommendation: "后位可以玩更多牌"
                ))
            }
            
            let overbets = recent.filter { record in
                let maxBet = record.streetActions.map { $0.amount ?? 0 }.max() ?? 0
                return maxBet > record.potSize * 3 && record.result == .loss
            }
            
            if Double(overbets.count) / Double(recent.count) > 0.1 {
                leaks.append(LeakAnalysis(
                    type: .bettingTooBig,
                    severity: Double(overbets.count) / Double(recent.count),
                    description: "下注过大导致损失",
                    recommendation: "控制下注尺度，不要过度投资"
                ))
            }
            
            let noProtection = recent.filter { record in
                record.result == .loss && 
                record.communityCards.count >= 3 &&
                !record.streetActions.contains { $0.action == "bet" || $0.action == "raise" }
            }
            
            if Double(noProtection.count) / Double(recent.count) > 0.2 {
                leaks.append(LeakAnalysis(
                    type: .notProtecting,
                    severity: Double(noProtection.count) / Double(recent.count),
                    description: "未保护好牌",
                    recommendation: "有强牌时主动下注保护"
                ))
            }
            
            return leaks.sorted { $0.severity > $1.severity }
        }
    }
    
    func getProfitByHand(playerId: String) -> [String: Double] {
        return queue.sync {
            guard let records = handHistory[playerId] else { return [:] }
            
            var handProfits: [String: (total: Int, count: Int)] = [:]
            
            for record in records {
                let handKey = record.holeCards.joined(separator: "-")
                let current = handProfits[handKey] ?? (0, 0)
                handProfits[handKey] = (current.total + record.profit, current.count + 1)
            }
            
            var avgProfits: [String: Double] = [:]
            for (hand, data) in handProfits {
                avgProfits[hand] = Double(data.total) / Double(data.count)
            }
            
            return avgProfits
        }
    }
    
    func getRecentPerformance(playerId: String, hands: Int = 100) -> (winRate: Double, avgProfit: Double, biggestPot: Int) {
        return queue.sync { () -> (winRate: Double, avgProfit: Double, biggestPot: Int) in
            guard let records = handHistory[playerId], !records.isEmpty else {
                return (0, 0, 0)
            }
            
            let recent = Array(records.suffix(hands))
            let wins = recent.filter { $0.result == .win }.count
            let winRate = Double(wins) / Double(recent.count)
            let avgProfit = Double(recent.reduce(0) { $0 + $1.profit }) / Double(recent.count)
            let biggestPot = recent.map { $0.potSize }.max() ?? 0
            
            return (winRate, avgProfit, biggestPot)
        }
    }
    
    func clearHistory(playerId: String) {
        queue.async(flags: .barrier) {
            self.handHistory.removeValue(forKey: playerId)
        }
    }
}
