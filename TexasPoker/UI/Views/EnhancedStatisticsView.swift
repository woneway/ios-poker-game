import SwiftUI
import CoreData

// MARK: - Enhanced Statistics View
/// Enhanced statistics view with charts and detailed analytics
struct EnhancedStatisticsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var profiles = ProfileManager.shared
    
    @State private var selectedMode: GameMode = .cashGame
    @State private var selectedTimeRange: StatisticsCalculator.TimeRange = .all
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var handHistoryData: [StatisticsCalculator.HandHistorySummary] = []
    @State private var positionStats: [StatisticsCalculator.PositionStat] = []

    // Use TimeRange from StatisticsCalculator
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Mode and time range selectors
                    selectorHeader
                    
                    // Hero overview card
                    heroOverviewCard
                    
                    // Win rate chart
                    chartSection
                    
                    // Position stats
                    positionSection
                    
                    // Detailed stats
                    detailedStatsSection
                    
                    // AI opponents
                    opponentsSection
                }
                .padding()
            }
            .navigationTitle("数据统计")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: exportStatistics) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .onAppear {
                loadHandHistory()
            }
            .onChange(of: selectedMode) { _, _ in
                loadHandHistory()
            }
            .onChange(of: selectedTimeRange) { _, _ in
                loadHandHistory()
            }
        }
    }
    
    // MARK: - Selector Header
    private var selectorHeader: some View {
        VStack(spacing: 12) {
            Picker("模式", selection: $selectedMode) {
                Text("现金局").tag(GameMode.cashGame)
                Text("锦标赛").tag(GameMode.tournament)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Picker("时间范围", selection: $selectedTimeRange) {
                ForEach(StatisticsCalculator.TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    // MARK: - Hero Overview Card
    private var heroOverviewCard: some View {
        let heroStats = getHeroStats()
        
        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("总盈亏")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(heroStats.profit >= 0 ? "+$\(heroStats.profit)" : "-$\(abs(heroStats.profit))")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(heroStats.profit >= 0 ? .green : .red)
                }
                
                Spacer()
                
                // BB/100 metric
                VStack(alignment: .trailing, spacing: 4) {
                    Text("BB/100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", heroStats.bbPer100))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(heroStats.bbPer100 >= 0 ? .green : .red)
                }
            }
            
            Divider()
            
            HStack(spacing: 20) {
                OverviewStatItem(title: "手数", value: "\(heroStats.hands)", icon: "number.circle")
                OverviewStatItem(title: "胜率", value: String(format: "%.1f%%", heroStats.winRate), icon: "chart.pie")
                OverviewStatItem(title: "Showdown", value: String(format: "%.1f%%", heroStats.showdownRate), icon: "eye")
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("盈亏走势")
                .font(.headline)
            
            let chartData = calculateProfitTrend()
            WinRateChartView(
                dataPoints: chartData,
                labels: (1...chartData.count).map { "\($0)" }
            )
            .frame(height: 150)
        }
    }
    
    // MARK: - Position Section
    private var positionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("位置胜率")
                .font(.headline)
            
            let positionData = calculatePositionStats()
            PositionWinRateChart(positionData: positionData)
        }
    }
    
    // MARK: - Detailed Stats Section
    private var detailedStatsSection: some View {
        let heroStats = getHeroStats()
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("详细数据")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                EnhancedStatBadge(
                    label: "VPIP",
                    value: "\(Int(heroStats.vpip))%",
                    subValue: "入池率",
                    color: .blue,
                    icon: "arrow.down.circle"
                )
                EnhancedStatBadge(
                    label: "PFR",
                    value: "\(Int(heroStats.pfr))%",
                    subValue: "加注率",
                    color: .orange,
                    icon: "arrow.up.circle"
                )
                EnhancedStatBadge(
                    label: "AF",
                    value: String(format: "%.1f", heroStats.af),
                    subValue: "攻击性",
                    color: .red,
                    icon: "flame"
                )
                EnhancedStatBadge(
                    label: "WTSD",
                    value: "\(Int(heroStats.wtsd))%",
                    subValue: "看牌率",
                    color: .green,
                    icon: "eye"
                )
                EnhancedStatBadge(
                    label: "W$SD",
                    value: "\(Int(heroStats.wsd))%",
                    subValue: " showdown胜率",
                    color: .purple,
                    icon: "crown"
                )
                EnhancedStatBadge(
                    label: "3Bet",
                    value: "\(Int(heroStats.threeBet))%",
                    subValue: "3Bet率",
                    color: .yellow,
                    icon: "arrow.2.circlepath"
                )
            }
        }
    }
    
    // MARK: - Opponents Section
    private var opponentsSection: some View {
        let aiStats = getAIStats()
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("AI 对手数据")
                .font(.headline)
            
            ForEach(aiStats, id: \.name) { stats in
                StatsOpponentRow(stats: stats)
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadHandHistory() {
        // This would fetch from Core Data based on selected filters
        // For now, we'll use mock data structure
        handHistoryData = fetchHandHistory()
        positionStats = calculatePositionStatsFromHistory()
    }
    
    private func fetchHandHistory() -> [StatisticsCalculator.HandHistorySummary] {
        // Fetch from Core Data via StatisticsCalculator
        return StatisticsCalculator.shared.fetchHandHistorySummaries(
            gameMode: selectedMode,
            timeRange: selectedTimeRange,
            profileId: profiles.currentProfileIdForData
        )
    }

    private func calculatePositionStatsFromHistory() -> [StatisticsCalculator.PositionStat] {
        // Calculate from hand history via StatisticsCalculator
        return StatisticsCalculator.shared.calculatePositionStats(
            gameMode: selectedMode,
            timeRange: selectedTimeRange,
            profileId: profiles.currentProfileIdForData
        )
    }
    
    // MARK: - Data Calculation Helpers
    private func getHeroStats() -> HeroStatsSummary {
        let profileId = profiles.currentProfileIdForData
        
        if let stats = StatisticsCalculator.shared.calculateStats(
            playerName: "Hero",
            gameMode: selectedMode,
            profileId: profileId
        ) {
            let bb = 20 // Default big blind
            let bbPer100 = stats.totalHands > 0 ? Double(stats.totalWinnings) / Double(bb) / Double(stats.totalHands) * 100 : 0
            
            return HeroStatsSummary(
                profit: stats.totalWinnings,
                hands: stats.totalHands,
                winRate: stats.totalHands > 0 ? Double(stats.handsWon) / Double(stats.totalHands) * 100 : 0,
                bbPer100: bbPer100,
                vpip: stats.vpip,
                pfr: stats.pfr,
                af: stats.af,
                wtsd: stats.wtsd,
                wsd: stats.wsd,
                threeBet: stats.threeBet,
                showdownRate: stats.wtsd
            )
        }
        
        return HeroStatsSummary()
    }
    
    private func getAIStats() -> [AIOpponentStats] {
        let profileId = profiles.currentProfileIdForData
        let aiNames = ["石头", "疯子麦克", "安娜", "老狐狸", "鲨鱼汤姆", "艾米", "大卫"]
        
        return aiNames.compactMap { name in
            if let stats = StatisticsCalculator.shared.calculateStats(
                playerName: name,
                gameMode: selectedMode,
                profileId: profileId
            ) {
                return AIOpponentStats(
                    name: name,
                    hands: stats.totalHands,
                    vpip: stats.vpip,
                    pfr: stats.pfr,
                    winnings: stats.totalWinnings
                )
            }
            return nil
        }
    }
    
    private func calculateProfitTrend() -> [Double] {
        // Calculate cumulative profit from hand history
        let profitData = StatisticsCalculator.shared.calculateProfitTrend(
            gameMode: selectedMode,
            timeRange: selectedTimeRange,
            profileId: profiles.currentProfileIdForData
        )
        return profitData.map { Double($0.cumulativeProfit) }
    }

    private func calculatePositionStats() -> [(position: String, winRate: Double, hands: Int)] {
        // Calculate win rate by position from hand history
        let stats = StatisticsCalculator.shared.calculatePositionStats(
            gameMode: selectedMode,
            timeRange: selectedTimeRange,
            profileId: profiles.currentProfileIdForData
        )
        return stats.map { ($0.position, $0.winRate, $0.handsPlayed) }
    }
    
    // MARK: - Export
    private func exportStatistics() {
        if let url = DataExporter.exportStatistics(gameMode: selectedMode) {
            exportURL = url
            showExportSheet = true
        }
    }
}

// MARK: - Supporting Types
struct HeroStatsSummary {
    var profit: Int = 0
    var hands: Int = 0
    var winRate: Double = 0
    var bbPer100: Double = 0
    var vpip: Double = 0
    var pfr: Double = 0
    var af: Double = 0
    var wtsd: Double = 0
    var wsd: Double = 0
    var threeBet: Double = 0
    var showdownRate: Double = 0
}

struct AIOpponentStats {
    let name: String
    let hands: Int
    let vpip: Double
    let pfr: Double
    let winnings: Int
}

// MARK: - Overview Stat Item
struct OverviewStatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Opponent Row
struct StatsOpponentRow: View {
    let stats: AIOpponentStats
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(stats.name)
                    .font(.system(size: 14, weight: .semibold))
                Text("\(stats.hands) 手")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("VPIP \(Int(stats.vpip))%")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("PFR \(Int(stats.pfr))%")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Text(stats.winnings >= 0 ? "+$\(stats.winnings)" : "-$\(abs(stats.winnings))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(stats.winnings >= 0 ? .green : .red)
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview
struct EnhancedStatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedStatisticsView()
    }
}
