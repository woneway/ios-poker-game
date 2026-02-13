import SwiftUI

// MARK: - Player Card View

struct PlayerCardsView: View {
    let player: Player
    let showCards: Bool
    let cardWidth: CGFloat
    
    private var shouldShowCardFace: Bool {
        return player.isHuman || showCards
    }
    
    var body: some View {
        Group {
            if !player.holeCards.isEmpty && player.status != .folded {
                HStack(spacing: -(cardWidth * 0.4)) {
                    ForEach(player.holeCards) { card in
                        CardView(card: shouldShowCardFace ? card : nil, width: cardWidth)
                            .rotationEffect(.degrees(Double.random(in: -3...3)))
                    }
                }
                .padding(.bottom, -8)
                .zIndex(1)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            } else {
                Color.clear.frame(height: 24)
            }
        }
    }
}

// MARK: - Player Avatar View

struct PlayerAvatarView: View {
    let avatar: String
    let isActive: Bool
    let isDealer: Bool
    let playerStatus: PlayerStatus
    let playerStats: PlayerStats?
    let avatarSize: CGFloat
    let onTap: () -> Void
    
    var body: some View {
        ZStack {
            // Active Glow
            if isActive {
                Circle()
                    .fill(Color.yellow.opacity(0.6))
                    .frame(width: avatarSize + 16, height: avatarSize + 16)
                    .blur(radius: 8)
                    .scaleEffect(1.1)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isActive)
            }
            
            // Avatar Background & Border
            Circle()
                .fill(Material.ultraThin)
                .frame(width: avatarSize, height: avatarSize)
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: isActive ? [.yellow, .orange] : [.white.opacity(0.3), .white.opacity(0.1)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isActive ? 3 : 1.5
                        )
                )
                .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
            
            // Avatar Character
            Text(avatar)
                .font(.system(size: avatarSize * 0.55))
                .shadow(color: .black.opacity(0.2), radius: 2)
            
            // Dealer Button
            if isDealer {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(radius: 2)
                    Text("D")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.black)
                }
                .offset(x: avatarSize * 0.35, y: -avatarSize * 0.35)
            }
            
            // Stats Badge (VPIP/PFR)
            if let stats = playerStats, stats.totalHands >= 10 {
                HStack(spacing: 2) {
                    Text("\(Int(stats.vpip))")
                        .foregroundColor(.green)
                    Text("/")
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(Int(stats.pfr))")
                        .foregroundColor(.red)
                }
                .font(.system(size: 8, weight: .bold))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                .offset(x: 0, y: avatarSize * 0.55)
            }
            
            // Status Overlay (Fold/All-in)
            if playerStatus == .folded {
                Text("FOLD")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                    .rotationEffect(.degrees(-15))
            } else if playerStatus == .allIn {
                Text("ALL IN")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        LinearGradient(gradient: Gradient(colors: [.red, .orange]), startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(4)
                    .shadow(color: .red.opacity(0.5), radius: 4)
                    .scaleEffect(1.1)
            }
        }
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Player Info View

struct PlayerInfoView: View {
    let player: Player
    let compact: Bool
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 1) {
            Text(player.name)
                .font(.system(size: compact ? 10 : 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .shadow(color: .black, radius: 1)
            
            Text("$\(player.chips)")
                .font(.system(size: compact ? 10 : 11, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)
                .shadow(color: .black, radius: 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(isActive ? 0.3 : 0.1), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Player Bet View

struct PlayerBetView: View {
    let bet: Int

    var body: some View {
        Group {
            if bet > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.yellow)
                    Text("$\(bet)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.6))
                        .overlay(Capsule().stroke(Color.yellow.opacity(0.5), lineWidth: 1))
                )
                .shadow(radius: 2)
            }
        }
    }
}

// MARK: - Profile Popover (Unchanged mostly, just styling)

struct ProfilePopover: View {
    let player: Player
    let stats: PlayerStats?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(player.aiProfile?.avatar ?? (player.isHuman ? "🤠" : "🤖"))
                    .font(.system(size: 40))
                    .padding(4)
                    .background(Circle().fill(Color.gray.opacity(0.1)))
                
                VStack(alignment: .leading) {
                    Text(player.name)
                        .font(.headline)
                    if let aiProfile = player.aiProfile {
                        Text(aiProfile.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider()

            // Stats Section
            if let stats = stats {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Statistics")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    StatRow(label: "Total Hands", value: "\(stats.totalHands)")
                    StatRow(label: "VPIP", value: String(format: "%.1f%%", stats.vpip))
                    StatRow(label: "PFR", value: String(format: "%.1f%%", stats.pfr))
                    StatRow(label: "3-Bet", value: String(format: "%.1f%%", stats.threeBet))
                    StatRow(label: "WTSD", value: String(format: "%.1f%%", stats.wtsd))
                    StatRow(label: "W$SD", value: String(format: "%.1f%%", stats.wsd))
                }
            } else {
                Text("No statistics available")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            // AI Profile Section
            if let aiProfile = player.aiProfile {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Profile")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    StatRow(label: "Tightness", value: String(format: "%.0f%%", (1 - aiProfile.tightness) * 100))
                    StatRow(label: "Aggression", value: String(format: "%.0f%%", aiProfile.aggression * 100))
                    StatRow(label: "Bluff Freq", value: String(format: "%.0f%%", aiProfile.bluffFreq * 100))
                }
            }
        }
        .padding()
        .frame(minWidth: 220)
        .background(.regularMaterial)
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .fontDesign(.monospaced)
        }
    }
}
