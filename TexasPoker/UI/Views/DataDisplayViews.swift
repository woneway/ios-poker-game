import SwiftUI

struct StatisticsDashboardView: View {
    let playerId: String
    @State private var selectedPeriod: TimePeriod = .all
    
    enum TimePeriod: String, CaseIterable {
        case today = "今日"
        case week = "本周"
        case month = "本月"
        case all = "全部"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                periodSelector
                
                summaryCards
                
                statsGrid
                
                chartSection
            }
            .padding()
        }
        .background(Color.black.opacity(0.9))
    }
    
    private var periodSelector: some View {
        HStack {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Button(action: { selectedPeriod = period }) {
                    Text(period.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedPeriod == period ? Color.blue : Color.gray.opacity(0.3))
                        .cornerRadius(15)
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private var summaryCards: some View {
        HStack(spacing: 12) {
            SummaryCard(title: "盈利", value: "+\(12345)", color: .green, icon: "arrow.up.circle.fill")
            SummaryCard(title: "手牌", value: "567", color: .blue, icon: "hand.raised.fill")
            SummaryCard(title: "胜率", value: "32.5%", color: .purple, icon: "chart.line.uptrend.xyaxis")
            SummaryCard(title: "ROI", value: "+15%", color: .orange, icon: "percent")
        }
    }
    
    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("详细统计")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                DisplayStatItem(title: "VPIP", value: "28%", icon: "hand.point.up.fill")
                DisplayStatItem(title: "PFR", value: "18%", icon: "arrow.up.forward")
                DisplayStatItem(title: "3-Bet", value: "8%", icon: "arrow.up.circle")
                DisplayStatItem(title: "C-Bet", value: "65%", icon: "bolt.fill")
                DisplayStatItem(title: "WTSD", value: "28%", icon: "eye.fill")
                DisplayStatItem(title: "WSD", value: "52%", icon: "star.fill")
            }
        }
    }
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("盈利趋势")
                .font(.headline)
                .foregroundColor(.white)
            
            ProfitChartView(data: sampleChartData)
                .frame(height: 200)
        }
    }
    
    private var sampleChartData: [Double] {
        [100, 200, 150, 300, 250, 400, 350, 500, 450, 600]
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
}

struct DisplayStatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.caption)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(value)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
}

struct ProfitChartView: View {
    let data: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            let maxValue = data.max() ?? 1
            let minValue = data.min() ?? 0
            let range = maxValue - minValue
            let stepX = geometry.size.width / CGFloat(data.count - 1)
            
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height))
                    
                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = geometry.size.height - ((CGFloat(value - minValue) / CGFloat(max(range, 1))) * geometry.size.height)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.5), Color.green.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                Path { path in
                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = geometry.size.height - ((CGFloat(value - minValue) / CGFloat(max(range, 1))) * geometry.size.height)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.green, lineWidth: 2)
            }
        }
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
}

struct PlayerCompareView: View {
    let player1Id: String
    let player2Id: String
    
    var body: some View {
        HStack(spacing: 20) {
            PlayerStatColumn(playerId: player1Id, isLeft: true)
            
            VSIndicator()
            
            PlayerStatColumn(playerId: player2Id, isLeft: false)
        }
        .padding()
        .background(Color.black.opacity(0.9))
    }
}

struct PlayerStatColumn: View {
    let playerId: String
    let isLeft: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(Color.blue.opacity(0.5))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                )
            
            Text("Player \(playerId)")
                .foregroundColor(.white)
                .font(.headline)
            
            VStack(spacing: 8) {
                ComparisonStat(label: "VPIP", leftValue: "28%", rightValue: "32%", isLeftBetter: false)
                ComparisonStat(label: "PFR", leftValue: "18%", rightValue: "22%", isLeftBetter: false)
                ComparisonStat(label: "胜率", leftValue: "32%", rightValue: "28%", isLeftBetter: true)
            }
        }
    }
}

struct ComparisonStat: View {
    let label: String
    let leftValue: String
    let rightValue: String
    let isLeftBetter: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack {
                Text(leftValue)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(isLeftBetter ? .green : .white)
                
                Text("vs")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(rightValue)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(isLeftBetter ? .white : .green)
            }
        }
    }
}

struct VSIndicator: View {
    var body: some View {
        Text("VS")
            .font(.title)
            .fontWeight(.bold)
            .foregroundColor(.red)
            .padding()
            .background(Circle().fill(Color.red.opacity(0.2)))
    }
}

struct LeaderboardView: View {
    @State private var entries: [LeaderboardEntry] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(entries) { entry in
                    LeaderboardRow(entry: entry, rank: entries.firstIndex(where: { $0.id == entry.id })! + 1)
                }
            }
            .padding()
        }
        .onAppear {
            entries = sampleLeaderboard()
        }
    }
    
    private func sampleLeaderboard() -> [LeaderboardEntry] {
        [
            LeaderboardEntry(id: "1", name: "Player1", profit: 50000, winRate: 35),
            LeaderboardEntry(id: "2", name: "Player2", profit: 45000, winRate: 32),
            LeaderboardEntry(id: "3", name: "Player3", profit: 40000, winRate: 30)
        ]
    }
}

struct LeaderboardEntry: Identifiable {
    let id: String
    let name: String
    let profit: Int
    let winRate: Double
}

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let rank: Int
    
    var body: some View {
        HStack {
            Text("#\(rank)")
                .font(.headline)
                .foregroundColor(rankColor)
                .frame(width: 40)
            
            Circle()
                .fill(Color.blue.opacity(0.5))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                )
            
            Text(entry.name)
                .foregroundColor(.white)
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("+\(entry.profit)")
                    .foregroundColor(.green)
                Text("\(entry.winRate)%")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .white
        }
    }
}

struct PositionStatsView: View {
    let positionData: [PositionProfit]
    
    struct PositionProfit: Identifiable {
        let id = UUID()
        let position: String
        let profit: Int
        let hands: Int
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("位置盈利分析")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(positionData) { data in
                Text("\(data.position): $\(data.profit) (\(data.hands)手)")
                    .font(.subheadline)
                    .foregroundColor(data.profit >= 0 ? .green : .red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
}

struct StreetStatsView: View {
    let streetData: [StreetData]
    
    struct StreetData: Identifiable {
        let id = UUID()
        let street: String
        let betFreq: Double
        let checkFreq: Double
        let foldFreq: Double
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("街次数据分布")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(streetData) { data in
                StreetDataRow(data: data)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
}

struct StreetDataRow: View {
    let data: StreetStatsView.StreetData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(data.street)
                .font(.subheadline)
                .foregroundColor(.white)
            
            HStack(spacing: 8) {
                StatBar(label: "下注", value: data.betFreq, color: .blue)
                StatBar(label: "过牌", value: data.checkFreq, color: .gray)
                StatBar(label: "弃牌", value: data.foldFreq, color: .red)
            }
        }
    }
}

struct StatBar: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(Int(value))%")
                    .font(.caption2)
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(value / 100))
                }
            }
            .frame(height: 8)
        }
    }
}

struct SessionTrendView: View {
    let trend: SessionTrend
    let suggestion: String?
    
    enum SessionTrend {
        case hot
        case cold
        case neutral
        
        var icon: String {
            switch self {
            case .hot: return "flame.fill"
            case .cold: return "snowflake"
            case .neutral: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .hot: return .orange
            case .cold: return .blue
            case .neutral: return .gray
            }
        }
        
        var title: String {
            switch self {
            case .hot: return "手感火热"
            case .cold: return "下风期"
            case .neutral: return "状态平稳"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: trend.icon)
                .font(.title2)
                .foregroundColor(trend.color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(trend.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if let suggestion = suggestion {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
}

struct LeakReportView: View {
    let leaks: [LeakInfo]
    
    struct LeakInfo: Identifiable {
        let id = UUID()
        let category: String
        let severity: Severity
        let description: String
        let recommendation: String
        
        enum Severity {
            case high
            case medium
            case low
            
            var color: Color {
                switch self {
                case .high: return .red
                case .medium: return .orange
                case .low: return .yellow
                }
            }
            
            var icon: String {
                switch self {
                case .high: return "exclamationmark.triangle.fill"
                case .medium: return "exclamationmark.circle.fill"
                case .low: return "info.circle.fill"
                }
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("漏洞检测")
                .font(.headline)
                .foregroundColor(.white)
            
            if leaks.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("未发现明显漏洞")
                        .foregroundColor(.gray)
                }
                .padding()
            } else {
                ForEach(leaks) { leak in
                    LeakRow(leak: leak)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
}

struct LeakRow: View {
    let leak: LeakReportView.LeakInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: leak.severity.icon)
                    .foregroundColor(leak.severity.color)
                
                Text(leak.category)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            Text(leak.description)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(leak.recommendation)
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding()
        .background(leak.severity.color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct OpponentComparisonView: View {
    let opponents: [OpponentInfo]
    
    struct OpponentInfo: Identifiable {
        let id = UUID()
        let name: String
        let vpip: Double
        let pfr: Double
        let winRate: Double
        let handsPlayed: Int
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("对手对比")
                .font(.headline)
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(opponents) { opponent in
                        OpponentCard(opponent: opponent)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
}

struct OpponentCard: View {
    let opponent: OpponentComparisonView.OpponentInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(opponent.name)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                ComparisonItem(label: "入池", value: "\(Int(opponent.vpip))%")
                ComparisonItem(label: "加注", value: "\(Int(opponent.pfr))%")
                ComparisonItem(label: "胜率", value: "\(Int(opponent.winRate))%")
                ComparisonItem(label: "手数", value: "\(opponent.handsPlayed)")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }
}

struct ComparisonItem: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}
