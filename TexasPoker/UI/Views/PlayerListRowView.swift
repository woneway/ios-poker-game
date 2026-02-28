import SwiftUI

/// Row view for displaying a player in the list
struct PlayerListRowView: View {
    let playerStats: PlayerStats

    private var playerAvatar: String {
        if playerStats.isHuman {
            return "👤"
        }
        return PlayerDataProvider.aiEmoji(for: playerStats.playerName)
    }
    
    private var winRate: Double {
        guard playerStats.totalHands > 0 else { return 0 }
        return Double(playerStats.handsWon) / Double(playerStats.totalHands) * 100
    }
    
    private var playerStyle: PlayerTendency {
        StatisticsCalculator.determinePlayerStyle(stats: playerStats)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Text(playerAvatar)
                .font(.system(size: 32))
                .frame(width: 44, height: 44)
                .background(Color(hex: "1a1a2e"))
                .clipShape(Circle())
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(playerStats.playerName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if playerStyle != .unknown {
                        PlayerStyleBadgeView(style: playerStyle, compact: true)
                    }
                }
                
                Text("\(playerStats.totalHands) 手")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Stats
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f%%", winRate))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                Text(formatCurrency(playerStats.totalWinnings))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(playerStats.totalWinnings >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(hex: "1a1a2e"))
        .cornerRadius(12)
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

#Preview {
    VStack {
        PlayerListRowView(playerStats: PlayerStats(
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
        
        PlayerListRowView(playerStats: PlayerStats(
            playerName: "Hero",
            gameMode: .cashGame,
            isHuman: true,
            totalHands: 50,
            vpip: 30.0,
            pfr: 20.0,
            af: 1.8,
            wtsd: 35.0,
            wsd: 45.0,
            threeBet: 5.0,
            handsWon: 20,
            totalWinnings: -1500,
            totalInvested: 5000
        ))
    }
    .padding()
}
