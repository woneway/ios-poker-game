import Foundation

class DataAnalysisEngine {
    static let shared = DataAnalysisEngine()
    
    private var handHistory: [HandRecord] = []
    private var playerActions: [String: [ActionRecord]] = [:]
    private let queue = DispatchQueue(label: "com.poker.analysis", attributes: .concurrent)
    
    private init() {}
    
    struct HandRecord {
        let id: UUID
        let timestamp: Date
        let players: [String]
        let holeCards: [String: [Card]]
        let communityCards: [Card]
        let actions: [ActionRecord]
        let potSize: Int
        let winner: String?
        let profit: [String: Int]
    }
    
    struct ActionRecord {
        let playerId: String
        let street: String
        let action: String
        let amount: Int?
        let timestamp: Date
    }
    
    func recordHand(_ record: HandRecord) {
        queue.async(flags: .barrier) {
            self.handHistory.append(record)
            
            if self.handHistory.count > 1000 {
                self.handHistory.removeFirst(100)
            }
            
            for action in record.actions {
                self.playerActions[action.playerId, default: []].append(action)
            }
        }
    }
    
    func analyzeProfitByPosition() -> [Int: ProfitAnalysis] {
        return queue.sync {
            var positionProfits: [Int: [Int]] = [:]
            
            for hand in handHistory {
                for (playerId, profit) in hand.profit {
                    let position = determinePosition(playerId: playerId, hand: hand)
                    positionProfits[position, default: []].append(profit)
                }
            }
            
            var result: [Int: ProfitAnalysis] = [:]
            for (position, profits) in positionProfits {
                result[position] = ProfitAnalysis(
                    position: position,
                    totalProfit: profits.reduce(0, +),
                    handsPlayed: profits.count,
                    avgProfit: Double(profits.reduce(0, +)) / Double(profits.count),
                    biggestWin: profits.max() ?? 0,
                    biggestLoss: profits.min() ?? 0
                )
            }
            
            return result
        }
    }
    
    func analyzeProfitByTime() -> TimeAnalysis {
        return queue.sync {
            var dailyProfit: [String: Int] = [:]
            var weeklyProfit: [String: Int] = [:]
            var monthlyProfit: [String: Int] = [:]
            
            let dateFormatter = DateFormatter()
            
            for hand in handHistory {
                let profit = hand.profit.values.reduce(0, +)
                
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let day = dateFormatter.string(from: hand.timestamp)
                dailyProfit[day, default: 0] += profit
                
                dateFormatter.dateFormat = "yyyy-WW"
                let week = dateFormatter.string(from: hand.timestamp)
                weeklyProfit[week, default: 0] += profit
                
                dateFormatter.dateFormat = "yyyy-MM"
                let month = dateFormatter.string(from: hand.timestamp)
                monthlyProfit[month, default: 0] += profit
            }
            
            return TimeAnalysis(
                daily: dailyProfit,
                weekly: weeklyProfit,
                monthly: monthlyProfit
            )
        }
    }
    
    func analyzeActionPatterns(playerId: String) -> ActionPatternAnalysis {
        return queue.sync {
            guard let actions = playerActions[playerId], !actions.isEmpty else {
                return ActionPatternAnalysis(
                    playerId: playerId,
                    mostCommonAction: "check",
                    actionFrequencies: [:],
                    avgThinkingTime: 0,
                    bluffFrequency: 0.2,
                    tightFactor: 0
                )
            }
            
            var actionCounts: [String: Int] = [:]
            
            for action in actions {
                actionCounts[action.action, default: 0] += 1
            }
            
            let mostCommon = actionCounts.max(by: { $0.value < $1.value })?.key ?? "check"
            
            let foldCount = actionCounts["fold"] ?? 0
            let totalActions = actions.count
            let tightFactor = Double(foldCount) / Double(max(totalActions, 1))
            
            return ActionPatternAnalysis(
                playerId: playerId,
                mostCommonAction: mostCommon,
                actionFrequencies: actionCounts,
                avgThinkingTime: 0,
                bluffFrequency: 0.2,
                tightFactor: tightFactor
            )
        }
    }
    
    func findLeaks(playerId: String) -> [LeakReport] {
        return queue.sync {
            var leaks: [LeakReport] = []
            
            let positionAnalysis = analyzeProfitByPosition()
            
            for (position, profit) in positionAnalysis {
                if profit.avgProfit < -5 {
                    leaks.append(LeakReport(
                        category: "位置",
                        severity: profit.avgProfit < -20 ? .high : .medium,
                        description: "位置 \(position) 平均亏损 \(Int(abs(profit.avgProfit)))",
                        recommendation: "在不利位置收紧范围"
                    ))
                }
            }
            
            let patternAnalysis = analyzeActionPatterns(playerId: playerId)
            
            if patternAnalysis.tightFactor > 0.7 {
                leaks.append(LeakReport(
                    category: "弃牌率",
                    severity: .low,
                    description: "弃牌率过高: \(Int(patternAnalysis.tightFactor*100))%",
                    recommendation: "可以更多诈牌"
                ))
            }
            
            leaks.append(contentsOf: detectAdvancedLeaks(playerId: playerId))
            
            return leaks
        }
    }
    
    private func detectAdvancedLeaks(playerId: String) -> [LeakReport] {
        var leaks: [LeakReport] = []
        
        guard let actions = playerActions[playerId], actions.count > 10 else {
            return leaks
        }
        
        var streetActions: [String: [String]] = [:]
        for action in actions {
            streetActions[action.street, default: []].append(action.action)
        }
        
        if let flopActions = streetActions["flop"] {
            let betCount = flopActions.filter { $0 == "bet" || $0 == "raise" }.count
            let checkCount = flopActions.filter { $0 == "check" }.count
            if checkCount > betCount * 3 {
                leaks.append(LeakReport(
                    category: "翻牌圈",
                    severity: .medium,
                    description: "翻牌圈过牌过多，错过价值",
                    recommendation: "考虑用成手牌下注获取价值"
                ))
            }
        }
        
        if let turnActions = streetActions["turn"] {
            let foldCount = turnActions.filter { $0 == "fold" }.count
            let totalActions = turnActions.count
            if Double(foldCount) / Double(totalActions) > 0.6 {
                leaks.append(LeakReport(
                    category: "转牌圈",
                    severity: .medium,
                    description: "转牌圈弃牌率过高",
                    recommendation: "适当防守，保护手牌范围"
                ))
            }
        }
        
        return leaks
    }
    
    func analyzeOpponent(playerId: String, opponentId: String) -> OpponentAnalysis {
        return queue.sync {
            var matchHands = 0
            var wins = 0
            var totalProfit = 0
            
            for hand in handHistory {
                if hand.players.contains(playerId) && hand.players.contains(opponentId) {
                    matchHands += 1
                    if let profit = hand.profit[playerId] {
                        totalProfit += profit
                        if profit > 0 {
                            wins += 1
                        }
                    }
                }
            }
            
            let winRate = matchHands > 0 ? Double(wins) / Double(matchHands) : 0
            
            var playerStyle: String = "未知"
            if let opponentActions = playerActions[opponentId] {
                let vpipActions = opponentActions.filter { $0.action == "call" || $0.action == "raise" || $0.action == "bet" }
                let totalActions = opponentActions.count
                let vpip = totalActions > 0 ? Double(vpipActions.count) / Double(totalActions) : 0
                
                if vpip > 0.4 {
                    playerStyle = "松散"
                } else if vpip < 0.2 {
                    playerStyle = "紧"
                } else {
                    playerStyle = "中等"
                }
            }
            
            return OpponentAnalysis(
                opponentId: opponentId,
                handsPlayed: matchHands,
                winRate: winRate,
                totalProfit: totalProfit,
                estimatedStyle: playerStyle,
                aggressionScore: calculateAggression(opponentId: opponentId)
            )
        }
    }
    
    private func calculateAggression(opponentId: String) -> Double {
        guard let actions = playerActions[opponentId], !actions.isEmpty else {
            return 1.0
        }
        
        let betRaiseCount = actions.filter { $0.action == "bet" || $0.action == "raise" || $0.action == "3bet" }.count
        let callCount = actions.filter { $0.action == "call" }.count
        let foldCount = actions.filter { $0.action == "fold" }.count
        
        let totalActiveActions = betRaiseCount + callCount
        guard totalActiveActions > 0 else { return 1.0 }
        
        return Double(betRaiseCount) / Double(totalActiveActions) * 2.0
    }
    
    func analyzeSessionTrends(playerId: String) -> SessionTrends {
        return queue.sync {
            guard !handHistory.isEmpty else {
                return SessionTrends(recentForm: [], biggestPot: 0, trend: .neutral, suggestedAdjustment: nil)
            }
            
            let sortedHands = handHistory.sorted { $0.timestamp > $1.timestamp }
            let recentHands = Array(sortedHands.prefix(50))
            
            var recentProfit: [Int] = []
            var biggestPot = 0
            
            for hand in recentHands {
                if let profit = hand.profit[playerId] {
                    recentProfit.append(profit)
                    if abs(hand.potSize) > abs(biggestPot) {
                        biggestPot = hand.potSize
                    }
                }
            }
            
            let trend: SessionTrends.TrendDirection
            let formCount = min(10, recentProfit.count)
            if formCount >= 5 {
                let last5Profit = recentProfit.prefix(5).reduce(0, +)
                let previous5Profit = recentProfit.prefix(10).suffix(5).reduce(0, +)
                
                if last5Profit > previous5Profit + 500 {
                    trend = .hot
                } else if last5Profit < previous5Profit - 500 {
                    trend = .cold
                } else {
                    trend = .neutral
                }
            } else {
                trend = .neutral
            }
            
            return SessionTrends(
                recentForm: recentProfit,
                biggestPot: biggestPot,
                trend: trend,
                suggestedAdjustment: generateAdjustmentSuggestion(trend: trend)
            )
        }
    }
    
    private func generateAdjustmentSuggestion(trend: SessionTrends.TrendDirection) -> String? {
        switch trend {
        case .hot:
            return "手感火热，保持当前节奏"
        case .cold:
            return "可能进入下风期，建议收紧范围"
        case .neutral:
            return nil
        }
    }
    
    func generateInsights(playerId: String) -> [Insight] {
        return queue.sync {
            var insights: [Insight] = []
            
            let profitByPosition = analyzeProfitByPosition()
            
            if let bestPosition = profitByPosition.max(by: { $0.value.avgProfit < $1.value.avgProfit }) {
                insights.append(Insight(
                    type: .positive,
                    title: "最佳位置",
                    description: "在 \(bestPosition.key) 位置表现最好，平均盈利 \(Int(bestPosition.value.avgProfit))",
                    confidence: min(1.0, Double(bestPosition.value.handsPlayed) / 50),
                    recommendation: nil
                ))
            }
            
            let timeAnalysis = analyzeProfitByTime()
            if let lastMonth = timeAnalysis.monthly.sorted(by: { $0.key > $1.key }).first {
                if lastMonth.value > 0 {
                    insights.append(Insight(
                        type: .positive,
                        title: "盈利月份",
                        description: "\(lastMonth.key) 盈利 \(lastMonth.value)",
                        confidence: 0.8,
                        recommendation: nil
                    ))
                }
            }
            
            let leaks = findLeaks(playerId: playerId)
            if let biggestLeak = leaks.max(by: { $0.severity.rawValue < $1.severity.rawValue }) {
                insights.append(Insight(
                    type: .warning,
                    title: "需要改进",
                    description: biggestLeak.description,
                    confidence: 0.7,
                    recommendation: biggestLeak.recommendation
                ))
            }
            
            return insights
        }
    }
    
    private func determinePosition(playerId: String, hand: HandRecord) -> Int {
        guard let index = hand.players.firstIndex(of: playerId) else { return 0 }
        return index
    }
}

struct ProfitAnalysis {
    let position: Int
    let totalProfit: Int
    let handsPlayed: Int
    let avgProfit: Double
    let biggestWin: Int
    let biggestLoss: Int
}

struct TimeAnalysis {
    let daily: [String: Int]
    let weekly: [String: Int]
    let monthly: [String: Int]
}

struct ActionPatternAnalysis {
    let playerId: String
    let mostCommonAction: String
    let actionFrequencies: [String: Int]
    let avgThinkingTime: TimeInterval
    let bluffFrequency: Double
    let tightFactor: Double
}

struct LeakReport {
    let category: String
    let severity: LeakSeverity
    let description: String
    let recommendation: String
    
    enum LeakSeverity: Int {
        case low = 1
        case medium = 2
        case high = 3
    }
}

struct Insight {
    let type: InsightType
    let title: String
    let description: String
    let confidence: Double
    let recommendation: String?
    
    enum InsightType {
        case positive
        case negative
        case warning
        case info
    }
}

struct OpponentAnalysis {
    let opponentId: String
    let handsPlayed: Int
    let winRate: Double
    let totalProfit: Int
    let estimatedStyle: String
    let aggressionScore: Double
}

struct SessionTrends {
    let recentForm: [Int]
    let biggestPot: Int
    let trend: TrendDirection
    let suggestedAdjustment: String?
    
    enum TrendDirection {
        case hot
        case cold
        case neutral
    }
}

class ReportGenerator {
    static let shared = ReportGenerator()
    
    private init() {}
    
    func generateSessionReport(playerId: String, sessionId: String) -> SessionReport {
        let analysisEngine = DataAnalysisEngine.shared
        
        let insights = analysisEngine.generateInsights(playerId: playerId)
        let leaks = analysisEngine.findLeaks(playerId: playerId)
        let patterns = analysisEngine.analyzeActionPatterns(playerId: playerId)
        
        return SessionReport(
            playerId: playerId,
            sessionId: sessionId,
            generatedAt: Date(),
            insights: insights,
            leaks: leaks,
            patterns: patterns,
            summary: generateSummary(insights: insights, leaks: leaks)
        )
    }
    
    func generateDailyReport(playerId: String) -> DailyReport {
        let timeAnalysis = DataAnalysisEngine.shared.analyzeProfitByTime()
        
        let todayProfit = timeAnalysis.daily.sorted(by: { $0.key > $1.key }).first?.value ?? 0
        let weekProfit = timeAnalysis.weekly.values.reduce(0, +)
        let monthProfit = timeAnalysis.monthly.values.reduce(0, +)
        
        return DailyReport(
            playerId: playerId,
            date: Date(),
            todayProfit: todayProfit,
            weekProfit: weekProfit,
            monthProfit: monthProfit,
            handsPlayed: 0
        )
    }
    
    private func generateSummary(insights: [Insight], leaks: [LeakReport]) -> String {
        var summary = ""
        
        let positiveCount = insights.filter { $0.type == .positive }.count
        let warningCount = insights.filter { $0.type == .warning }.count
        
        if positiveCount > 0 {
            summary += "发现 \(positiveCount) 个优势点。"
        }
        
        if warningCount > 0 {
            summary += "存在 \(warningCount) 个需要改进的地方。"
        } else {
            summary += "整体表现良好。"
        }
        
        return summary
    }
}

struct SessionReport {
    let playerId: String
    let sessionId: String
    let generatedAt: Date
    let insights: [Insight]
    let leaks: [LeakReport]
    let patterns: ActionPatternAnalysis
    let summary: String
}

struct DailyReport {
    let playerId: String
    let date: Date
    let todayProfit: Int
    let weekProfit: Int
    let monthProfit: Int
    let handsPlayed: Int
}
