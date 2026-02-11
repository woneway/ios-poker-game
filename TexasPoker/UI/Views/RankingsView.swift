import SwiftUI

/// Full-screen rankings overlay shown when game ends
struct RankingsView: View {
    let results: [PlayerResult]
    let totalHands: Int
    let onNewGame: () -> Void
    
    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.85)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                // Title
                Text("🏆 FINAL STANDINGS")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(0.5), radius: 6)
                    .padding(.top, 30)
                
                Text("Total Hands: \(totalHands)")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                
                // Rankings list
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(results) { result in
                            rankRow(result)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxHeight: 400)
                
                // New Game button
                Button(action: onNewGame) {
                    Text("NEW GAME")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue]),
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .cornerRadius(14)
                        .shadow(color: .blue.opacity(0.4), radius: 6, y: 3)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    private func rankRow(_ result: PlayerResult) -> some View {
        HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor(result.rank))
                    .frame(width: 36, height: 36)
                
                if result.rank <= 3 {
                    Text(rankMedal(result.rank))
                        .font(.system(size: 18))
                } else {
                    Text("#\(result.rank)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // Avatar
            Text(result.avatar)
                .font(.system(size: 22))
            
            // Name
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(result.name)
                        .font(.system(size: 15, weight: result.isHuman ? .bold : .medium))
                        .foregroundColor(result.isHuman ? .yellow : .white)
                    
                    if result.isHuman {
                        Text("(You)")
                            .font(.system(size: 11))
                            .foregroundColor(.yellow.opacity(0.7))
                    }
                }
                
                if result.rank == 1 {
                    Text("Winner · $\(result.finalChips)")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                } else {
                    Text("Out at Hand #\(result.handsPlayed)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            Spacer()

            // Payout indicator (tournament only)
            if result.payout > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 14))
                    Text("$\(result.payout)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.yellow)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.15))
                .cornerRadius(8)
            }

            // Chips or eliminated indicator
            if result.rank == 1 {
                Text("$\(result.finalChips)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
            } else {
                Text("Eliminated")
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(result.isHuman ? Color.yellow.opacity(0.1) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(result.isHuman ? Color.yellow.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
    
    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color.yellow.opacity(0.8)
        case 2: return Color.gray.opacity(0.6)
        case 3: return Color.orange.opacity(0.6)
        default: return Color.white.opacity(0.15)
        }
    }
    
    private func rankMedal(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return ""
        }
    }
}
