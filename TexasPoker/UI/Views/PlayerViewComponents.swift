import SwiftUI

// MARK: - Player Card View

struct PlayerCardsView: View {
    let player: Player
    let isHero: Bool
    let showCards: Bool
    let cardWidth: CGFloat
    
    var body: some View {
        Group {
            if isHero && !player.holeCards.isEmpty {
                // Hero 始终显示正面
                HStack(spacing: -(cardWidth * 0.35)) {
                    ForEach(Array(player.holeCards.enumerated()), id: \.offset) { index, card in
                        FlippingCard(card: card, delay: Double(index) * 0.15, width: cardWidth, isHero: true)
                    }
                }
                .padding(.bottom, -4)
                .zIndex(1)
            } else if !player.holeCards.isEmpty && player.status != .folded {
                // 非 Hero：有牌时显示牌背或正面
                HStack(spacing: -(cardWidth * 0.35)) {
                    ForEach(player.holeCards) { card in
                        CardView(card: showCards ? card : nil, width: cardWidth)
                    }
                }
                .padding(.bottom, -4)
                .zIndex(1)
            } else {
                Color.clear.frame(width: cardWidth * 1.6, height: cardWidth * 1.2)
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
            
            // Status Overlay (Fold/All-in)
            if playerStatus == .folded {
                Text("FOLD")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.7))
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
            Text(player.displayName)
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
                    Text(player.displayName)
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
                    Text("统计")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    StatRow(label: "总局数", value: "\(stats.totalHands)")
                    StatRow(label: "入池率", value: String(format: "%.1f%%", stats.vpip))
                    StatRow(label: "加注率", value: String(format: "%.1f%%", stats.pfr))
                    StatRow(label: "3-Bet", value: String(format: "%.1f%%", stats.threeBet))
                    StatRow(label: "看到摊牌", value: String(format: "%.1f%%", stats.wtsd))
                    StatRow(label: "摊牌胜率", value: String(format: "%.1f%%", stats.wsd))
                }
            } else {
                Text("暂无统计数据")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            // AI Profile Section
            if let aiProfile = player.aiProfile {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("AI 画像")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    StatRow(label: "松紧度", value: String(format: "%.0f%%", (1 - aiProfile.tightness) * 100))
                    StatRow(label: "侵略性", value: String(format: "%.0f%%", aiProfile.aggression * 100))
                    StatRow(label: "诈唬频率", value: String(format: "%.0f%%", aiProfile.bluffFreq * 100))
                    StatRow(label: "C-Bet翻牌", value: String(format: "%.0f%%", aiProfile.cbetFreq * 100))
                    StatRow(label: "C-Bet转牌", value: String(format: "%.0f%%", aiProfile.cbetTurnFreq * 100))
                    StatRow(label: "位置感知", value: String(format: "%.0f%%", aiProfile.positionAwareness * 100))
                    StatRow(label: "上头敏感度", value: String(format: "%.0f%%", aiProfile.tiltSensitivity * 100))
                    StatRow(label: "跟注到底", value: String(format: "%.0f%%", aiProfile.callDownTendency * 100))
                }
            }
            
            // Description
            if let aiProfile = player.aiProfile {
                Divider()

                Text(aiProfile.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(minWidth: 240)
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
