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
