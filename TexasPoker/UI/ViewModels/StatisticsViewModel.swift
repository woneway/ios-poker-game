import Foundation
import Combine

@MainActor
final class StatisticsViewModel: ObservableObject {
    @Published var heroStats: PlayerStats?
    @Published var aiStats: [AIPlayerStats] = []
    @Published var positionStats: [StatisticsCalculator.PositionStat] = []
    @Published var profitTrend: [StatisticsCalculator.ProfitDataPoint] = []
    @Published var handHistory: [StatisticsCalculator.HandHistorySummary] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var exportURL: URL?

    private let getHeroStatsUseCase: GetPlayerStatsUseCase
    private let getAllPlayersStatsUseCase: GetAllPlayersStatsUseCase
    private let getPositionStatsUseCase: GetPositionStatsUseCase
    private let getProfitTrendUseCase: GetProfitTrendUseCase
    private let refreshStatisticsUseCase: RefreshStatisticsUseCase
    private let exportStatisticsUseCase: ExportStatisticsUseCase

    private var selectedGameMode: GameMode = .cashGame
    var selectedTimeRange: StatisticsCalculator.TimeRange = .all

    init(
        getHeroStatsUseCase: GetPlayerStatsUseCase = GetPlayerStatsUseCase(),
        getAllPlayersStatsUseCase: GetAllPlayersStatsUseCase = GetAllPlayersStatsUseCase(),
        getPositionStatsUseCase: GetPositionStatsUseCase = GetPositionStatsUseCase(),
        getProfitTrendUseCase: GetProfitTrendUseCase = GetProfitTrendUseCase(),
        refreshStatisticsUseCase: RefreshStatisticsUseCase = RefreshStatisticsUseCase(),
        exportStatisticsUseCase: ExportStatisticsUseCase = ExportStatisticsUseCase()
    ) {
        self.getHeroStatsUseCase = getHeroStatsUseCase
        self.getAllPlayersStatsUseCase = getAllPlayersStatsUseCase
        self.getPositionStatsUseCase = getPositionStatsUseCase
        self.getProfitTrendUseCase = getProfitTrendUseCase
        self.refreshStatisticsUseCase = refreshStatisticsUseCase
        self.exportStatisticsUseCase = exportStatisticsUseCase
    }

    func loadData(gameMode: GameMode, timeRange: StatisticsCalculator.TimeRange? = nil) async {
        selectedGameMode = gameMode
        if let tr = timeRange {
            selectedTimeRange = tr
        }
        isLoading = true
        errorMessage = nil

        refreshStatisticsUseCase.execute()

        do {
            heroStats = try await getHeroStatsUseCase.execute(playerId: "Hero", gameMode: gameMode)

            let allStats = try await getAllPlayersStatsUseCase.execute(gameMode: gameMode)
            aiStats = allStats
                .filter { $0.key != "Hero" }
                .map { name, stats in
                    AIPlayerStats(
                        name: name,
                        totalHands: stats.totalHands,
                        vpip: stats.vpip,
                        pfr: stats.pfr,
                        af: stats.af,
                        wtsd: stats.wtsd,
                        winRate: stats.totalHands > 0 ? Double(stats.handsWon) / Double(stats.totalHands) * 100 : 0,
                        totalProfit: stats.totalWinnings
                    )
                }
        } catch {
            errorMessage = "Failed to load statistics: \(error.localizedDescription)"
        }

        positionStats = getPositionStatsUseCase.execute(gameMode: gameMode, timeRange: selectedTimeRange)
        profitTrend = getProfitTrendUseCase.execute(gameMode: gameMode, timeRange: selectedTimeRange)

        isLoading = false
    }

    func refresh() async {
        await loadData(gameMode: selectedGameMode)
    }

    func exportStatistics() {
        exportURL = exportStatisticsUseCase.execute(gameMode: selectedGameMode)
    }
}

struct AIPlayerStats {
    let name: String
    let totalHands: Int
    let vpip: Double
    let pfr: Double
    let af: Double
    let wtsd: Double
    let winRate: Double
    let totalProfit: Int
}
