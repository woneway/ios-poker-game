import SwiftUI

/// Grid view for displaying player statistics
struct PlayerStatsGridView: View {
    let playerStats: PlayerStats
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            StatCell(title: "VPIP", value: String(format: "%.1f%%", playerStats.vpip), description: "入池率", color: .blue)
            StatCell(title: "PFR", value: String(format: "%.1f%%", playerStats.pfr), description: "翻前加注率", color: .orange)
            StatCell(title: "AF", value: String(format: "%.1f", playerStats.af), description: "攻击性", color: .red)
            StatCell(title: "WTSD", value: String(format: "%.1f%%", playerStats.wtsd), description: "入摊率", color: .green)
            StatCell(title: "W$SD", value: String(format: "%.1f%%", playerStats.wsd), description: "摊牌胜率", color: .purple)
            StatCell(title: "3Bet", value: String(format: "%.1f%%", playerStats.threeBet), description: "三次下注率", color: .yellow)
        }
    }
}

/// Individual stat cell in the grid
struct StatCell: View {
    let title: String
    let value: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)
            
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    PlayerStatsGridView(playerStats: PlayerStats(
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
    .padding()
}
