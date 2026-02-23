import SwiftUI

/// Detailed view for a single player's statistics
struct PlayerDetailView: View {
    let playerStats: PlayerStats
    
    @State private var showHandHistory: Bool = false
    
    private let playerAvatarMap: [String: String] = [
        "石头": "🪨",
        "疯子麦克": "🤪",
        "安娜": "👩",
        "老狐狸": "🦊",
        "鲨鱼汤姆": "🦈",
        "艾米": "🎓",
        "大卫": "😤",
        "新手鲍勃": "🐟",
        "玛丽": "🐢",
        "史蒂夫": "🥶",
        "杰克": "🎭",
        "山姆": "💰",
        "托尼": "🕸️",
        "皮特": "🧠",
        "维克多": "🎖️"
    ]
    
    private var playerAvatar: String {
        if let avatar = playerAvatarMap[playerStats.playerName] {
            return avatar
        }
        return playerStats.isHuman ? "👤" : "🤖"
    }
    
    private var winRate: Double {
        guard playerStats.totalHands > 0 else { return 0 }
        return Double(playerStats.handsWon) / Double(playerStats.totalHands) * 100
    }
    
    private var playerStyle: PlayerTendency {
        StatisticsCalculator.determinePlayerStyle(stats: playerStats)
    }
    
    private var hasEnoughData: Bool {
        playerStats.totalHands >= 20
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with avatar and basic info
                headerSection
                
                // Core stats grid
                statsGridSection
                
                // Additional stats
                additionalStatsSection
                
                // Player style
                playerStyleSection
                
                // Hand history button
                if playerStats.totalHands > 0 {
                    handHistoryButton
                }
            }
            .padding()
        }
        .navigationTitle(playerStats.playerName)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showHandHistory) {
            PlayerHandHistoryView(
                playerName: playerStats.playerName,
                gameMode: playerStats.gameMode
            )
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Avatar
            Text(playerAvatar)
                .font(.system(size: 64))
                .frame(width: 100, height: 100)
                .background(Color(.systemGray6))
                .clipShape(Circle())
            
            // Name and style badge
            HStack(spacing: 8) {
                Text(playerStats.playerName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if playerStats.isHuman {
                    Text("👤")
                        .font(.caption)
                }
            }
            
            // Game mode badge
            Text(playerStats.gameMode == .cashGame ? "现金局" : "锦标赛")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
    
    // MARK: - Stats Grid Section
    private var statsGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("核心数据")
                .font(.headline)
            
            PlayerStatsGridView(playerStats: playerStats)
        }
    }
    
    // MARK: - Additional Stats Section
    private var additionalStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("概览")
                .font(.headline)
            
            HStack(spacing: 12) {
                AdditionalStatCard(
                    title: "总局数",
                    value: "\(playerStats.totalHands)",
                    icon: "number.circle.fill",
                    color: .blue
                )
                
                AdditionalStatCard(
                    title: "获胜手数",
                    value: "\(playerStats.handsWon)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                AdditionalStatCard(
                    title: "胜率",
                    value: String(format: "%.1f%%", winRate),
                    icon: "chart.pie.fill",
                    color: .purple
                )
            }
            
            // Total winnings
            HStack {
                Text("总盈利")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatCurrency(playerStats.totalWinnings))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(playerStats.totalWinnings >= 0 ? .green : .red)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Player Style Section
    private var playerStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("玩家风格")
                .font(.headline)
            
            if hasEnoughData {
                HStack {
                    PlayerStyleBadgeView(style: playerStyle)
                    
                    Spacer()
                    
                    Text(styleDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    Text("数据不足，无法判断风格")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("需要至少 20 手数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Hand History Button
    private var handHistoryButton: some View {
        Button(action: { showHandHistory = true }) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                Text("历史牌局")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .foregroundColor(.accentColor)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Helpers
    private var styleDescription: String {
        switch playerStyle {
        case .lag:
            return "松凶型 - 入池率高，攻击性强"
        case .tag:
            return "紧凶型 - 入池率适中，攻击性强"
        case .lpp:
            return "紧弱型 - 入池率低，较少攻击"
        case .callingStation:
            return "跟注站 - 喜欢跟注到摊牌"
        case .nit:
            return "岩石型 - 入池率极低，极少攻击"
        case .abc:
            return "标准型 - 平衡型打法"
        case .unknown:
            return ""
        }
    }
    
    private func formatCurrency(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        
        let formattedAmount = formatter.string(from: NSNumber(value: abs(amount))) ?? "\(abs(amount))"
        
        if amount >= 0 {
            return "+$\(formattedAmount)"
        } else {
            return "-$\(formattedAmount)"
        }
    }
}

/// Additional stat card component
struct AdditionalStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        PlayerDetailView(playerStats: PlayerStats(
            playerName: "石头",
            gameMode: .cashGame,
            isHuman: false,
            totalHands: 150,
            vpip: 25.5,
            pfr: 18.0,
            af: 2.5,
            wtsd: 28.0,
            wsd: 52.0,
            threeBet: 8.5,
            handsWon: 75,
            totalWinnings: 5000,
            totalInvested: 10000
        ))
    }
}
