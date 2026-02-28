import Foundation

final class GetPositionStatsUseCase {
    private let statisticsCalculator: StatisticsCalculator

    init(statisticsCalculator: StatisticsCalculator = .shared) {
        self.statisticsCalculator = statisticsCalculator
    }

    func execute(gameMode: GameMode, timeRange: StatisticsCalculator.TimeRange = .all, profileId: String? = nil) -> [StatisticsCalculator.PositionStat] {
        statisticsCalculator.calculatePositionStats(gameMode: gameMode, timeRange: timeRange, profileId: profileId)
    }
}

final class GetProfitTrendUseCase {
    private let statisticsCalculator: StatisticsCalculator

    init(statisticsCalculator: StatisticsCalculator = .shared) {
        self.statisticsCalculator = statisticsCalculator
    }

    func execute(gameMode: GameMode, timeRange: StatisticsCalculator.TimeRange = .all, profileId: String? = nil) -> [StatisticsCalculator.ProfitDataPoint] {
        statisticsCalculator.calculateProfitTrend(gameMode: gameMode, timeRange: timeRange, profileId: profileId)
    }
}

final class RefreshStatisticsUseCase {
    private let statisticsCalculator: StatisticsCalculator
    private let dataAnalysisEngine: DataAnalysisEngine

    init(
        statisticsCalculator: StatisticsCalculator = .shared,
        dataAnalysisEngine: DataAnalysisEngine = .shared
    ) {
        self.statisticsCalculator = statisticsCalculator
        self.dataAnalysisEngine = dataAnalysisEngine
    }

    func execute() {
        statisticsCalculator.invalidateCache()
        dataAnalysisEngine.ensureDataLoaded()
    }
}

final class ExportStatisticsUseCase {
    func execute(gameMode: GameMode) -> URL? {
        DataExporter.exportStatistics(gameMode: gameMode)
    }
}

final class GetAIAnalysisUseCase {
    private let dataAnalysisEngine: DataAnalysisEngine

    init(dataAnalysisEngine: DataAnalysisEngine = .shared) {
        self.dataAnalysisEngine = dataAnalysisEngine
    }

    func execute() -> [String] {
        var insights: [String] = []

        let positionAnalysis = dataAnalysisEngine.analyzeProfitByPosition()
        if let heroPosition = positionAnalysis[0] {
            if heroPosition.totalProfit < 0 {
                insights.append("📍 早期位置盈利较差，建议收紧入池范围")
            }
        }

        let timeAnalysis = dataAnalysisEngine.analyzeProfitByTime()
        let totalHands = timeAnalysis.daily.values.reduce(0, +)
        if totalHands > 10 {
            let recentProfit = timeAnalysis.daily.values.suffix(7).reduce(0, +)
            if recentProfit < 0 {
                insights.append("📈 最近盈利下滑，建议调整状态")
            }
        }

        return insights
    }
}
