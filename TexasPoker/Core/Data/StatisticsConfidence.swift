import Foundation

struct StatisticsConfidence {
    let value: Double
    let sampleSize: Int
    let confidenceLevel: Double
    
    static let zScore95 = 1.96
    static let zScore90 = 1.645
    
    var marginOfError: Double {
        guard sampleSize > 0 else { return 1.0 }
        let p = value
        return Self.zScore95 * sqrt(p * (1 - p) / Double(sampleSize))
    }
    
    var confidenceInterval: (lower: Double, upper: Double) {
        let moe = marginOfError
        return (max(0, value - moe), min(1, value + moe))
    }
    
    var isReliable: Bool {
        return sampleSize >= 100 && marginOfError < 0.1
    }
    
    var reliabilityLevel: ReliabilityLevel {
        if sampleSize >= 500 && marginOfError < 0.05 {
            return .high
        } else if sampleSize >= 100 && marginOfError < 0.1 {
            return .medium
        } else if sampleSize >= 30 {
            return .low
        } else {
            return .insufficient
        }
    }
}

enum ReliabilityLevel: String {
    case high = "高可信度"
    case medium = "中等可信度"
    case low = "低可信度"
    case insufficient = "数据不足"
    
    var color: String {
        switch self {
        case .high: return "green"
        case .medium: return "yellow"
        case .low: return "orange"
        case .insufficient: return "red"
        }
    }
}

struct TrendData {
    let recentValues: [Double]
    let periodSize: Int
    
    var trend: TrendDirection {
        guard recentValues.count >= periodSize else { return .stable }
        
        let recent = recentValues.suffix(periodSize)
        let previous = recentValues.dropLast(periodSize)
        
        guard previous.count >= periodSize else { return .stable }
        
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let previousAvg = previous.reduce(0, +) / Double(previous.count)
        
        let change = (recentAvg - previousAvg) / previousAvg
        
        if change > 0.1 { return .improving }
        if change < -0.1 { return .declining }
        return .stable
    }
    
    var volatility: Double {
        guard recentValues.count > 1 else { return 0 }
        
        let mean = recentValues.reduce(0, +) / Double(recentValues.count)
        let variance = recentValues.map { pow($0 - mean, 2) }.reduce(0, +) / Double(recentValues.count)
        return sqrt(variance)
    }
}

enum TrendDirection: String {
    case improving = "上升"
    case declining = "下降"
    case stable = "稳定"
    
    var symbol: String {
        switch self {
        case .improving: return "↗"
        case .declining: return "↘"
        case .stable: return "→"
        }
    }
}

struct StatisticsTrend {
    let vpipTrend: TrendData
    let pfrTrend: TrendData
    let afTrend: TrendData
    let wtsdTrend: TrendData
    let winRateTrend: TrendData
    
    static func analyze(from history: [PlayerStats]) -> StatisticsTrend? {
        guard history.count >= 20 else { return nil }
        
        let periodSize = max(1, history.count / 5)
        
        let vpipValues = history.map { $0.vpip }
        let pfrValues = history.map { $0.pfr }
        let afValues = history.map { $0.af }
        let wtsdValues = history.map { $0.wtsd }
        let winRateValues = history.map { Double($0.handsWon) / Double(max(1, $0.totalHands)) }
        
        return StatisticsTrend(
            vpipTrend: TrendData(recentValues: vpipValues, periodSize: periodSize),
            pfrTrend: TrendData(recentValues: pfrValues, periodSize: periodSize),
            afTrend: TrendData(recentValues: afValues, periodSize: periodSize),
            wtsdTrend: TrendData(recentValues: wtsdValues, periodSize: periodSize),
            winRateTrend: TrendData(recentValues: winRateValues, periodSize: periodSize)
        )
    }
}

struct PlayerStatsWithConfidence {
    let stats: PlayerStats
    let vpipConfidence: StatisticsConfidence
    let pfrConfidence: StatisticsConfidence
    let afConfidence: StatisticsConfidence
    let threeBetConfidence: StatisticsConfidence
    let trend: StatisticsTrend?
    
    init(stats: PlayerStats) {
        self.stats = stats
        self.vpipConfidence = StatisticsConfidence(
            value: stats.vpip,
            sampleSize: stats.totalHands,
            confidenceLevel: 0.95
        )
        self.pfrConfidence = StatisticsConfidence(
            value: stats.pfr,
            sampleSize: stats.totalHands,
            confidenceLevel: 0.95
        )
        self.afConfidence = StatisticsConfidence(
            value: stats.af,
            sampleSize: stats.totalHands,
            confidenceLevel: 0.95
        )
        self.threeBetConfidence = StatisticsConfidence(
            value: stats.threeBet,
            sampleSize: stats.totalHands,
            confidenceLevel: 0.95
        )
        self.trend = nil
    }
}
