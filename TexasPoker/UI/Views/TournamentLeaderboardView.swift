import SwiftUI
import Combine

// MARK: - Tournament Leaderboard View
/// Real-time tournament leaderboard with rankings and statistics
struct TournamentLeaderboardView: View {
    @ObservedObject var store: PokerGameStore
    @State private var sortOption: SortOption = .chips
    @State private var showEliminated = true
    @Environment(\.colorScheme) var colorScheme
    
    enum SortOption: String, CaseIterable {
        case chips = "筹码"
        case rank = "排名"
        case eliminations = "淘汰顺序"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Stats summary
            statsSummary
            
            Divider()
            
            // Sort options
            sortBar
            
            // Player list
            playerList
        }
        .background(Color(hex: "0f0f23"))
    }
    
    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("锦标赛排名")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                if store.engine.gameMode == .tournament {
                    Text("Level \(store.engine.currentBlindLevel + 1)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            if store.engine.gameMode == .tournament,
               let config = store.engine.tournamentConfig {
                let entrantsCount = max(store.engine.players.count, 1)
                HStack {
                    Label("\(store.engine.players.count)/\(entrantsCount) 人", systemImage: "person.3")
                    Spacer()
                    Label("奖池: $\(entrantsCount * config.startingChips)", systemImage: "dollarsign.circle")
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
        }
        .padding()
    }
    
    // MARK: - Stats Summary
    private var statsSummary: some View {
        HStack(spacing: 16) {
            StatBox(title: "平均筹码", value: averageChips, color: .blue)
            StatBox(title: "最大筹码", value: maxChips, color: .green)
            StatBox(title: "最小筹码", value: minChips, color: .orange)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // MARK: - Sort Bar
    private var sortBar: some View {
        HStack {
            Picker("排序", selection: $sortOption) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Toggle("显示淘汰", isOn: $showEliminated)
                .font(.caption)
        }
        .padding()
    }
    
    // MARK: - Player List
    private var playerList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(sortedPlayers.indices, id: \.self) { index in
                    let player = sortedPlayers[index]
                    let actualRank = actualRank(for: player)
                    
                    PlayerRankRow(
                        rank: actualRank,
                        player: player,
                        isHero: player.isHuman,
                        isActive: player.chips > 0,
                        showTrend: sortOption == .chips
                    )
                    .opacity(player.chips > 0 ? 1.0 : (showEliminated ? 0.5 : 0))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Computed Properties
    
    private var sortedPlayers: [Player] {
        let players = store.engine.players
        
        switch sortOption {
        case .chips:
            return players.sorted { $0.chips > $1.chips }
        case .rank:
            return players.sorted {
                rankScore(for: $0) > rankScore(for: $1)
            }
        case .eliminations:
            return players.sorted {
                eliminationOrder(for: $0) < eliminationOrder(for: $1)
            }
        }
    }
    
    private func actualRank(for player: Player) -> Int {
        let allPlayers = store.engine.players
        let sortedByChips = allPlayers.sorted { $0.chips > $1.chips }
        return (sortedByChips.firstIndex(where: { $0.id == player.id }) ?? 0) + 1
    }
    
    private func rankScore(for player: Player) -> Int {
        if player.chips > 0 {
            return player.chips
        }
        // Eliminated players have negative scores based on elimination order
        return -eliminationOrder(for: player)
    }
    
    private func eliminationOrder(for player: Player) -> Int {
        guard player.chips <= 0 else { return 0 }
        
        if let index = store.engine.eliminationOrder.firstIndex(where: { $0.name == player.name }) {
            return index + 1
        }
        return Int.max
    }
    
    private var averageChips: String {
        let activePlayers = store.engine.players.filter { $0.chips > 0 }
        guard !activePlayers.isEmpty else { return "0" }
        let total = activePlayers.reduce(0) { $0 + $1.chips }
        return "\(total / activePlayers.count)"
    }
    
    private var maxChips: String {
        let max = store.engine.players.map { $0.chips }.max() ?? 0
        return "\(max)"
    }
    
    private var minChips: String {
        let activeMin = store.engine.players.filter { $0.chips > 0 }.map { $0.chips }.min() ?? 0
        return "\(activeMin)"
    }
}

// MARK: - Player Rank Row
struct PlayerRankRow: View {
    let rank: Int
    let player: Player
    let isHero: Bool
    let isActive: Bool
    let showTrend: Bool
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            RankBadge(rank: rank, isActive: isActive)

            // Avatar
            let displayAvatar = player.aiProfile?.avatar ?? (isHero ? .emoji("🤠") : .emoji("🤖"))
            displayAvatar.view(size: 28)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(avatarBackgroundColor)
                )
            
            // Player info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(player.name)
                        .font(.system(size: 15, weight: .semibold))
                    
                    if isHero {
                        Text("(你)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    if let profile = player.aiProfile {
                        Text(profile.name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(2)
                    }
                }
                
                if isActive {
                    HStack(spacing: 8) {
                        Text("$\(player.chips)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(chipColor)
                        
                        if showTrend {
                            ChipTrendIndicator(chips: player.chips, initialChips: 1000)
                        }
                    }
                } else {
                    Text("已淘汰")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            // Status indicator
            if isActive {
                if player.status == .active {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                } else if player.status == .allIn {
                    Text("All-in")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(rowBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHero ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
    
    private var avatarBackgroundColor: Color {
        if !isActive { return .gray.opacity(0.3) }
        if isHero { return .blue.opacity(0.3) }
        return .white.opacity(0.1)
    }
    
    private var chipColor: Color {
        if player.chips >= 2000 { return .green }
        if player.chips >= 1000 { return .primary }
        return .orange
    }
    
    private var rowBackground: some View {
        if isHero {
            return Color.blue.opacity(0.1)
        } else if !isActive {
            return Color.gray.opacity(0.1)
        } else {
            return Color.white.opacity(0.05)
        }
    }
}

// MARK: - Rank Badge
struct RankBadge: View {
    let rank: Int
    let isActive: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(badgeColor)
                .frame(width: 32, height: 32)
            
            Text("\(rank)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private var badgeColor: Color {
        guard isActive else { return .gray }
        
        switch rank {
        case 1: return .yellow
        case 2: return Color.gray.opacity(0.8)
        case 3: return Color.orange.opacity(0.8)
        default: return Color.blue.opacity(0.6)
        }
    }
}

// MARK: - Chip Trend Indicator
struct ChipTrendIndicator: View {
    let chips: Int
    let initialChips: Int
    
    var body: some View {
        let diff = chips - initialChips
        let percentage = Double(diff) / Double(initialChips) * 100
        
        HStack(spacing: 2) {
            Image(systemName: diff >= 0 ? "arrow.up" : "arrow.down")
                .font(.system(size: 8))
            Text(String(format: "%.0f%%", abs(percentage)))
                .font(.system(size: 10))
        }
        .foregroundColor(diff >= 0 ? .green : .red)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background((diff >= 0 ? Color.green : Color.red).opacity(0.1))
        .cornerRadius(4)
    }
}

// MARK: - Stat Box
struct StatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Tournament Progress View
/// Shows tournament progress with bubble indicator
struct TournamentProgressView: View {
    @ObservedObject var store: PokerGameStore
    
    var body: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressGradient)
                        .frame(width: progressWidth(in: geo.size.width), height: 8)
                    
                    // Bubble indicator
                    if isInMoney {
                        bubbleIndicator(in: geo.size.width)
                    }
                }
            }
            .frame(height: 20)
            
            // Stats
            HStack {
                Label("剩余: \(aliveCount) 人", systemImage: "person.fill")
                Spacer()
                if isInMoney {
                    Label("已入奖圈", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Label("距离钱圈: \(spotsToMoney) 人", systemImage: "bubble.left")
                        .foregroundColor(.orange)
                }
                Spacer()
                Label("已淘汰: \(eliminatedCount) 人", systemImage: "person.fill.xmark")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var aliveCount: Int {
        store.engine.players.filter { $0.chips > 0 }.count
    }
    
    private var eliminatedCount: Int {
        store.engine.players.count - aliveCount
    }
    
    private var isInMoney: Bool {
        guard let config = store.engine.tournamentConfig else { return false }
        let paidSpots = config.payoutStructure.count
        return aliveCount <= paidSpots
    }
    
    private var spotsToMoney: Int {
        guard let config = store.engine.tournamentConfig else { return 0 }
        let paidSpots = config.payoutStructure.count
        return max(0, aliveCount - paidSpots)
    }
    
    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        let entrantsCount = max(store.engine.players.count, 1)
        let progress = 1.0 - (Double(aliveCount) / Double(entrantsCount))
        return totalWidth * CGFloat(progress)
    }
    
    private func bubbleIndicator(in totalWidth: CGFloat) -> some View {
        let bubblePosition = progressWidth(in: totalWidth)
        
        return VStack(spacing: 0) {
            Text("🫧")
                .font(.system(size: 16))
            Triangle()
                .fill(Color.orange)
                .frame(width: 8, height: 6)
        }
        .position(x: bubblePosition, y: 0)
    }
    
    private var progressGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [.blue, .green]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Triangle Shape
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview
struct TournamentLeaderboardView_Previews: PreviewProvider {
    static var previews: some View {
        TournamentLeaderboardView(store: PokerGameStore(mode: .tournament))
            .preferredColorScheme(.dark)
    }
}
