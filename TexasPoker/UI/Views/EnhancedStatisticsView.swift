import CoreData
import os.log
import SwiftUI

private let viewLogger = Logger(subsystem: "smartegg.TexasPoker", category: "View")

struct EnhancedStatisticsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var settings: GameSettings
    @ObservedObject private var profiles = ProfileManager.shared

    @StateObject private var viewModel = StatisticsViewModel()
    @State private var selectedMode: GameMode = .cashGame
    @State private var selectedTimeRange: StatisticsCalculator.TimeRange = .all
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var handHistoryData: [StatisticsCalculator.HandHistorySummary] = []
    @State private var positionStats: [StatisticsCalculator.PositionStat] = []

    private let getAIAnalysisUseCase = GetAIAnalysisUseCase()

    private var aiNames: [String] {
        PlayerDataProvider.allAINames
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "0f0f23"),
                        Color(hex: "1a1a2e"),
                        Color(hex: "16213e")
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        selectorHeader
                        heroOverviewCard
                        chartSection
                        positionSection
                        detailedStatsSection
                        opponentsSection
                        aiAnalysisSection
                    }
                    .padding()
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("数据统计")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.exportStatistics()
                        if let url = viewModel.exportURL {
                            exportURL = url
                            showExportSheet = true
                        }
                    }) {
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
                Task {
                    await viewModel.loadData(gameMode: selectedMode)
                }
            }
            .onChange(of: selectedMode) { _, _ in
                Task {
                    await viewModel.loadData(gameMode: selectedMode, timeRange: selectedTimeRange)
                }
            }
            .onChange(of: selectedTimeRange) { _, _ in
                Task {
                    await viewModel.loadData(gameMode: selectedMode, timeRange: selectedTimeRange)
                }
            }
        }
    }

    private var selectorHeader: some View {
        VStack(spacing: 16) {
            Picker("模式", selection: $selectedMode) {
                Text("现金局").tag(GameMode.cashGame)
                Text("锦标赛").tag(GameMode.tournament)
            }
            .pickerStyle(SegmentedPickerStyle())
            .colorMultiply(Color.white.opacity(0.9))
            
            Picker("时间范围", selection: $selectedTimeRange) {
                ForEach(StatisticsCalculator.TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .colorMultiply(Color.white.opacity(0.9))
        }
        .padding(.horizontal, 4)
    }

    private var heroOverviewCard: some View {
        let stats = viewModel.heroStats
        let heroStats = HeroStatsSummary(
            profit: stats?.totalWinnings ?? 0,
            hands: stats?.totalHands ?? 0,
            winRate: (stats?.totalHands ?? 0) > 0 ? Double(stats?.handsWon ?? 0) / Double(stats?.totalHands ?? 1) * 100 : 0,
            bbPer100: calculateBBPer100(stats: stats),
            vpip: stats?.vpip ?? 0,
            pfr: stats?.pfr ?? 0,
            af: stats?.af ?? 0,
            wtsd: stats?.wtsd ?? 0,
            wsd: stats?.wsd ?? 0,
            threeBet: stats?.threeBet ?? 0,
            showdownRate: stats?.wtsd ?? 0
        )
        
        let confidence = StatisticsConfidence(
            value: heroStats.winRate / 100,
            sampleSize: heroStats.hands,
            confidenceLevel: 0.95
        )
        
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
            
            HStack {
                Image(systemName: confidenceIcon(for: confidence.reliabilityLevel))
                    .foregroundColor(confidenceColor(for: confidence.reliabilityLevel))
                Text(confidenceText(for: confidence.reliabilityLevel))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("±\(String(format: "%.1f", confidence.marginOfError * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }

    private func calculateBBPer100(stats: PlayerStats?) -> Double {
        guard let stats = stats, stats.totalHands > 0 else { return 0 }
        let bb = settings.getCashGameConfig().bigBlind
        return Double(stats.totalWinnings) / Double(bb) / Double(stats.totalHands) * 100
    }
    
    private func confidenceIcon(for level: ReliabilityLevel) -> String {
        switch level {
        case .high: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "questionmark.circle.fill"
        case .insufficient: return "exclamationmark.triangle.fill"
        }
    }
    
    private func confidenceColor(for level: ReliabilityLevel) -> Color {
        switch level {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .orange
        case .insufficient: return .red
        }
    }
    
    private func confidenceText(for level: ReliabilityLevel) -> String {
        switch level {
        case .high: return "数据可信"
        case .medium: return "数据较可信"
        case .low: return "数据样本较少"
        case .insufficient: return "需要更多数据"
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("盈亏走势")
                .font(.headline)
            
            let chartData = viewModel.profitTrend.map { Double($0.cumulativeProfit) }
            WinRateChartView(
                dataPoints: chartData,
                labels: chartData.isEmpty ? [] : (1...chartData.count).map { "\($0)" }
            )
            .frame(height: 150)
        }
    }

    private var positionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("位置胜率")
                .font(.headline)
            
            let positionData = viewModel.positionStats.map { ($0.position, $0.winRate, $0.handsPlayed) }
            PositionWinRateChart(positionData: positionData)
        }
    }

    private var detailedStatsSection: some View {
        let stats = viewModel.heroStats
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("详细数据")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                EnhancedStatBadge(
                    label: "VPIP",
                    value: "\(Int(stats?.vpip ?? 0))%",
                    subValue: "入池率",
                    color: .blue,
                    icon: "arrow.down.circle"
                )
                EnhancedStatBadge(
                    label: "PFR",
                    value: "\(Int(stats?.pfr ?? 0))%",
                    subValue: "加注率",
                    color: .orange,
                    icon: "arrow.up.circle"
                )
                EnhancedStatBadge(
                    label: "AF",
                    value: String(format: "%.1f", stats?.af ?? 0),
                    subValue: "攻击性",
                    color: .red,
                    icon: "flame"
                )
                EnhancedStatBadge(
                    label: "WTSD",
                    value: "\(Int(stats?.wtsd ?? 0))%",
                    subValue: "看牌率",
                    color: .green,
                    icon: "eye"
                )
                EnhancedStatBadge(
                    label: "W$SD",
                    value: "\(Int(stats?.wsd ?? 0))%",
                    subValue: " showdown胜率",
                    color: .purple,
                    icon: "crown"
                )
                EnhancedStatBadge(
                    label: "3Bet",
                    value: "\(Int(stats?.threeBet ?? 0))%",
                    subValue: "3Bet率",
                    color: .yellow,
                    icon: "arrow.2.circlepath"
                )
            }
        }
    }

    private var opponentsSection: some View {
        let aiStats = viewModel.aiStats
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("AI 对手数据")
                .font(.headline)
            
            ForEach(aiStats, id: \.name) { stats in
                StatsOpponentRow(stats: AIOpponentStats(from: stats))
            }
        }
    }

    private var aiAnalysisSection: some View {
        let analysis = getAIAnalysis()
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("AI 分析洞察")
                .font(.headline)
            
            if analysis.isEmpty {
                Text("暂无足够数据进行分析")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(analysis, id: \.self) { insight in
                    InsightRow(insight: insight)
                }
            }
        }
    }
    
    private func getAIAnalysis() -> [String] {
        getAIAnalysisUseCase.execute()
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
    
    init(from aiStats: AIPlayerStats) {
        self.name = aiStats.name
        self.hands = aiStats.totalHands
        self.vpip = aiStats.vpip
        self.pfr = aiStats.pfr
        self.winnings = aiStats.totalProfit
    }
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

// MARK: - Insight Row
struct InsightRow: View {
    let insight: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
                .font(.system(size: 14))
            
            Text(insight)
                .font(.system(size: 13))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(10)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview
struct EnhancedStatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedStatisticsView()
    }
}
