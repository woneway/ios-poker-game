import SwiftUI

// MARK: - Tournament Leaderboard Overlay
/// Full-screen overlay for tournament leaderboard
struct TournamentLeaderboardOverlay: View {
    @ObservedObject var store: PokerGameStore
    @Binding var isPresented: Bool
    
    @State private var selectedTab: Tab = .leaderboard
    @Environment(\.colorScheme) var colorScheme
    
    enum Tab {
        case leaderboard
        case progress
        case history
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation { isPresented = false }
                }
            
            // Main content
            VStack(spacing: 0) {
                // Header
                header
                
                // Tab selector
                tabSelector
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Content
                content
            }
            .background(Color.adaptiveSurface(colorScheme))
            .cornerRadius(16)
            .padding()
            .frame(maxWidth: 600, maxHeight: 800)
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("锦标赛统计")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let config = store.engine.tournamentConfig {
                    Text("第 \(store.engine.handNumber) 手 · \(store.engine.players.count)/\(config.totalEntrants) 人")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: { 
                withAnimation { isPresented = false }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            TabButton(
                title: "排行榜",
                icon: "list.number",
                isSelected: selectedTab == .leaderboard
            ) {
                selectedTab = .leaderboard
            }
            
            TabButton(
                title: "进度",
                icon: "chart.line.uptrend.xyaxis",
                isSelected: selectedTab == .progress
            ) {
                selectedTab = .progress
            }
            
            TabButton(
                title: "历史",
                icon: "clock.arrow.circlepath",
                isSelected: selectedTab == .history
            ) {
                selectedTab = .history
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Content
    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .leaderboard:
            TournamentLeaderboardView(store: store)
        case .progress:
            TournamentProgressDetailView(store: store)
        case .history:
            TournamentHistoryView()
        }
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .blue : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Tournament Progress Detail View
struct TournamentProgressDetailView: View {
    @ObservedObject var store: PokerGameStore
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Progress overview
                TournamentProgressView(store: store)
                
                // Key moments
                keyMomentsSection
                
                // Biggest movers
                biggestMoversSection
                
                // Chip distribution
                chipDistributionSection
            }
            .padding()
        }
    }
    
    private var keyMomentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("关键时刻")
                .font(.headline)
            
            let moments = TournamentStatsManager.shared.keyMoments
            
            if moments.isEmpty {
                Text("暂无关键时刻")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(0..<moments.count, id: \.self) { index in
                    let moment = moments[index]
                    MomentRow(moment: moment, index: index + 1)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var biggestMoversSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("排名变动")
                .font(.headline)
            
            let movers = TournamentStatsManager.shared.biggestMovers(overHands: 5)
            
            if movers.isEmpty {
                Text("近期排名变动不大")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(0..<movers.count, id: \.self) { index in
                    let mover = movers[index]
                    MoverRow(name: mover.name, change: mover.change, rank: index + 1)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var chipDistributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("筹码分布")
                .font(.headline)
            
            // Simple bar chart showing chip distribution
            let rankings = TournamentStatsManager.shared.currentRankings
            let activePlayers = rankings.filter { !$0.isEliminated }
            
            if activePlayers.isEmpty {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(activePlayers.prefix(5)) { player in
                    HStack {
                        Text("#\(player.rank)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 30)
                        
                        Text(player.name)
                            .font(.system(size: 14))
                        
                        Spacer()
                        
                        GeometryReader { geo in
                            HStack {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(barColor(for: player.rank))
                                    .frame(width: barWidth(for: player.chips, in: geo.size.width))
                                
                                Text("\(player.chips)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, alignment: .trailing)
                            }
                        }
                        .frame(height: 20)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func barColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
    
    private func barWidth(for chips: Int, in totalWidth: CGFloat) -> CGFloat {
        let maxChips = TournamentStatsManager.shared.currentRankings.map { $0.chips }.max() ?? 1
        let ratio = Double(chips) / Double(maxChips)
        return totalWidth * CGFloat(ratio) * 0.6 // 60% of available space
    }
}

// MARK: - Tournament History View
struct TournamentHistoryView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Elimination order
                eliminationOrderSection
                
                // Ranking history chart placeholder
                rankingHistorySection
            }
            .padding()
        }
    }
    
    private var eliminationOrderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("淘汰顺序")
                .font(.headline)
            
            let eliminations = TournamentStatsManager.shared.eliminationOrder
            
            if eliminations.isEmpty {
                Text("暂无淘汰记录")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(0..<eliminations.count, id: \.self) { index in
                    let record = eliminations[index]
                    EliminationRow(record: record, total: eliminations.count)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var rankingHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("排名历史")
                .font(.headline)
            
            Text("排名变化图表功能开发中...")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Views
struct MomentRow: View {
    let moment: TournamentStatsManager.TournamentMoment
    let index: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.2))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(moment.description)
                    .font(.system(size: 14))
                
                Text("第 \(moment.handNumber) 手")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var iconName: String {
        switch moment.type {
        case .doubleUp: return "arrow.up.circle.fill"
        case .badBeat: return "exclamationmark.triangle.fill"
        case .bubbleBurst: return "bubble.left.fill"
        case .finalTable: return "tablecells.fill"
        case .headsUp: return "person.2.fill"
        case .champion: return "crown.fill"
        }
    }
    
    private var iconColor: Color {
        switch moment.type {
        case .doubleUp: return .green
        case .badBeat: return .orange
        case .bubbleBurst: return .red
        case .finalTable: return .blue
        case .headsUp: return .purple
        case .champion: return .yellow
        }
    }
}

struct MoverRow: View {
    let name: String
    let change: Int
    let rank: Int
    
    var body: some View {
        HStack {
            Text("\(rank)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text(name)
                .font(.system(size: 14))
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: change > 0 ? "arrow.up" : "arrow.down")
                    .font(.caption)
                Text("\(abs(change))")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(change > 0 ? .green : .red)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background((change > 0 ? Color.green : Color.red).opacity(0.1))
            .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

struct EliminationRow: View {
    let record: TournamentStatsManager.EliminationRecord
    let total: Int
    
    var body: some View {
        HStack {
            Text("#\(record.rank)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 36)
            
            Text(record.name)
                .font(.system(size: 14))
            
            Spacer()
            
            Text("第 \(record.handNumber) 手")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .opacity(0.7)
    }
}

// MARK: - Preview
struct TournamentLeaderboardOverlay_Previews: PreviewProvider {
    static var previews: some View {
        TournamentLeaderboardOverlay(
            store: PokerGameStore(mode: .tournament),
            isPresented: .constant(true)
        )
    }
}
