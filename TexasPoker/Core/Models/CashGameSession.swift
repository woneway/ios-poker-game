import Foundation

/// Represents a cash game session with buy-in, top-ups, and hand profit tracking.
struct CashGameSession: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    let initialBuyIn: Int
    var topUpTotal: Int = 0
    var finalChips: Int = 0
    var handsPlayed: Int = 0
    var handProfits: [Int] = []
    var handsWon: Int = 0
    
    /// Maximum total buy-in count before session ends (0 = unlimited)
    /// Calculated as: playerCount × maxBuyIn × multiplier
    var maxBuyIns: Int = 0
    
    /// The max single buy-in amount (used for calculating top-up counts)
    var maxBuyIn: Int = 2000
    
    /// Total number of buy-ins (initial + top-ups)
    var totalBuyInCount: Int {
        guard initialBuyIn > 0 else { return 0 }
        var count = 1  // initial buy-in
        if maxBuyIn > 0 && topUpTotal > 0 {
            count += topUpTotal / maxBuyIn
        }
        return count
    }
    
    /// Whether session has reached the buy-in limit
    var isBuyInLimitReached: Bool {
        return maxBuyIns > 0 && totalBuyInCount >= maxBuyIns
    }
    
    /// Legacy property for compatibility
    var maxHands: Int = 0

    /// Net profit: final chips minus initial buy-in and total top-ups
    var netProfit: Int {
        finalChips - initialBuyIn - topUpTotal
    }

    /// Maximum single hand win (positive profit)
    var maxWin: Int {
        handProfits.max() ?? 0
    }

    /// Maximum single hand loss (negative profit)
    var maxLoss: Int {
        handProfits.min() ?? 0
    }

    /// Session duration in seconds
    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }
    
    /// Win rate (hands won / total hands)
    var winRate: Double {
        guard handsPlayed > 0 else { return 0 }
        return Double(handsWon) / Double(handsPlayed)
    }
    
    /// Hourly rate (profit per hour)
    var hourlyRate: Double {
        let hours = duration / 3600
        guard hours > 0 else { return 0 }
        return Double(netProfit) / hours
    }
    
    /// Total buy-in (initial + top-ups)
    var totalBuyIn: Int {
        initialBuyIn + topUpTotal
    }
    
    /// ROI (Return on Investment) percentage
    var roi: Double {
        guard totalBuyIn > 0 else { return 0 }
        return Double(netProfit) / Double(totalBuyIn) * 100
    }

    /// Creates a new cash game session with the given buy-in amount.
    /// - Parameters:
    ///   - buyIn: The initial buy-in amount in chips.
    ///   - maxBuyIns: Maximum total buy-in count before session ends (default: 0 = unlimited)
    ///   - maxBuyIn: The max single buy-in amount for calculating top-up counts
    init(buyIn: Int, maxBuyIns: Int = 0, maxBuyIn: Int = 2000) {
        self.id = UUID()
        self.startTime = Date()
        self.initialBuyIn = buyIn
        self.maxBuyIns = maxBuyIns
        self.maxBuyIn = maxBuyIn
    }
    
    /// Records a hand result
    /// - Parameters:
    ///   - profit: The profit from this hand (can be negative)
    ///   - won: Whether the hand was won
    mutating func recordHand(profit: Int, won: Bool) {
        handsPlayed += 1
        if won {
            handsWon += 1
        }
        handProfits.append(profit)
    }
    
    /// Records a buy-in/top-up
    /// - Parameter amount: The amount of the top-up
    mutating func recordTopUp(_ amount: Int) {
        topUpTotal += amount
    }
    
    /// Ends the session
    /// - Parameter finalChips: The final chip count
    mutating func endSession(finalChips: Int) {
        self.finalChips = finalChips
        self.endTime = Date()
    }
}

// MARK: - Session Analysis

struct SessionAnalysis {
    let performance: String
    let roi: Double
    let factors: [String]
    let recommendations: [String]
    
    var summary: String {
        return "\(performance) - ROI: \(String(format: "%.1f", roi))%"
    }
}

extension CashGameSession {
    /// Analyzes the session and returns insights
    func analyze() -> SessionAnalysis {
        let performance: String
        if roi > 50 {
            performance = "极佳"
        } else if roi > 20 {
            performance = "很好"
        } else if roi > 0 {
            performance = "盈利"
        } else if roi > -20 {
            performance = "小亏"
        } else {
            performance = "大亏"
        }
        
        var factors: [String] = []
        
        if winRate > 0.6 {
            factors.append("胜率高: \(Int(winRate * 100))%")
        } else if winRate < 0.4 {
            factors.append("胜率低: \(Int(winRate * 100))%")
        }
        
        if maxWin > netProfit - maxWin {
            factors.append("依赖大局")
        }
        
        if abs(maxLoss) > initialBuyIn / 2 {
            factors.append("有爆仓经历")
        }
        
        let recommendations = generateRecommendations()
        
        return SessionAnalysis(
            performance: performance,
            roi: roi,
            factors: factors,
            recommendations: recommendations
        )
    }
    
    private func generateRecommendations() -> [String] {
        var recs: [String] = []
        
        if roi < -30 {
            recs.append("建议休息调整状态")
            recs.append("回顾错误手牌")
        }
        
        if winRate < 0.35 {
            recs.append("收紧起手范围")
        } else if winRate > 0.65 {
            recs.append("可以玩更多手牌")
        }
        
        if recs.isEmpty {
            recs.append("保持当前状态")
        }
        
        return recs
    }
}

// MARK: - Trend Analysis

enum SessionTrendDirection {
    case upward
    case stable
    case downward
}

struct TrendAnalysis {
    let direction: SessionTrendDirection
    let strength: Double
    let confidence: Double
    let prediction: String
}

struct SessionStats {
    let totalSessions: Int
    let totalProfit: Int
    let totalHands: Int
    let avgProfit: Int
    let winRate: Double
    let hourlyRate: Double
}

extension Array where Element == CashGameSession {
    /// Analyzes trends across multiple sessions
    func analyzeTrend() -> TrendAnalysis {
        guard count >= 5 else {
            return TrendAnalysis(
                direction: .stable,
                strength: 0,
                confidence: 0,
                prediction: "数据不足"
            )
        }
        
        let profits = self.map { Double($0.netProfit) }
        
        let mean = profits.reduce(0, +) / Double(profits.count)
        
        var sumSquares = 0.0
        for profit in profits {
            sumSquares += (profit - mean) * (profit - mean)
        }
        let variance = sumSquares / Double(profits.count)
        let stdDev = sqrt(variance)
        
        let recent = profits.prefix(3)
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        
        let direction: SessionTrendDirection
        let strength: Double
        
        if recentAvg > mean + stdDev {
            direction = .upward
            strength = Swift.min(1.0, (recentAvg - mean) / stdDev)
        } else if recentAvg < mean - stdDev {
            direction = .downward
            strength = Swift.min(1.0, (mean - recentAvg) / stdDev)
        } else {
            direction = .stable
            strength = 0.5
        }
        
        return TrendAnalysis(
            direction: direction,
            strength: strength,
            confidence: Swift.min(1.0, Double(count) / 20.0),
            prediction: predictNextSession(profit: recentAvg, direction: direction)
        )
    }
    
    private func predictNextSession(profit: Double, direction: SessionTrendDirection) -> String {
        switch direction {
        case .upward:
            return "预计继续盈利"
        case .downward:
            return "预计亏损，建议谨慎"
        case .stable:
            return "预计持平"
        }
    }
    
    /// Calculates aggregate stats across all sessions
    func calculateStats() -> SessionStats {
        let totalProfit = self.reduce(0) { $0 + $1.netProfit }
        let totalHands = self.reduce(0) { $0 + $1.handsPlayed }
        let totalWon = self.reduce(0) { $0 + $1.handsWon }
        
        return SessionStats(
            totalSessions: count,
            totalProfit: totalProfit,
            totalHands: totalHands,
            avgProfit: count > 0 ? totalProfit / count : 0,
            winRate: totalHands > 0 ? Double(totalWon) / Double(totalHands) : 0,
            hourlyRate: 0
        )
    }
}
