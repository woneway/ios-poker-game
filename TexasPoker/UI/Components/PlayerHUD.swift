import SwiftUI

struct PlayerHUD: View {
    let playerName: String
    let gameMode: GameMode
    @State private var stats: PlayerStats?
    
    private let minSampleSize = 20
    
    var body: some View {
        Group {
            if let stats = stats, stats.totalHands >= minSampleSize {
                HStack(spacing: 2) {
                    Text("\(Int(stats.vpip))/\(Int(stats.pfr))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.yellow)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
            }
        }
        .onAppear {
            loadStats()
        }
        .onReceive(NotificationCenter.default.publisher(for: PokerEngine.EngineNotifications.playerStatsUpdated)) { notification in
            // 只在同模式/同 profile 下刷新，避免切换模式时的误刷新
            if let modeRaw = notification.userInfo?["gameMode"] as? String,
               modeRaw != gameMode.rawValue {
                return
            }
            loadStats()
        }
    }
    
    func loadStats() {
        DispatchQueue.global(qos: .background).async {
            if let calculated = StatisticsCalculator.shared.calculateStats(
                playerName: playerName,
                gameMode: gameMode
            ) {
                DispatchQueue.main.async {
                    self.stats = calculated
                }
            }
        }
    }
}
