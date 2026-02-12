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
                HStack(spacing: -(cardWidth * 0.35)) {
                    ForEach(player.holeCards) { card in
                        CardView(card: shouldShowCardFace ? card : nil, width: cardWidth)
                    }
                }
                .padding(.bottom, -6)
                .zIndex(1)
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
            // Active indicator
            if isActive {
                Circle()
                    .fill(Color.yellow.opacity(0.5))
                    .frame(width: avatarSize + 12, height: avatarSize + 12)
                    .blur(radius: 4)
            }
            
            // Avatar circle
            Circle()
                .fill(Color(white: 0.15))
                .frame(width: avatarSize, height: avatarSize)
                .overlay(
                    Circle().stroke(
                        isActive ? Color.yellow : (playerStatus == .folded ? Color.gray.opacity(0.3) : Color.gray.opacity(0.6)),
                        lineWidth: isActive ? 2.5 : 1
                    )
                )
                .shadow(
                    color: .yellow,
                    radius: 0
                )
            
            Text(avatar)
                .font(.system(size: avatarSize * 0.5))
            
            // Dealer button
            if isDealer {
                Text("D")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.black)
                    .frame(width: 14, height: 14)
                    .background(Color.white)
                    .clipShape(Circle())
                    .offset(x: avatarSize * 0.4, y: -avatarSize * 0.35)
            }
            
            // Stats badge
            if let stats = playerStats, stats.totalHands >= 10 {
                VStack(spacing: 0) {
                    Text("\(Int(stats.vpip))/\(Int(stats.pfr))")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(Color.blue.opacity(0.8))
                .cornerRadius(3)
                .offset(x: -avatarSize * 0.5, y: -avatarSize * 0.35)
            }
            
            // Status overlay
            if playerStatus == .folded {
                Text("FOLD")
                    .font(.system(size: 7, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(3)
            } else if playerStatus == .allIn {
                Text("ALL IN")
                    .font(.system(size: 7, weight: .black))
                    .foregroundColor(.red)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(3)
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
        VStack(spacing: 0) {
            Text(player.name)
                .font(.system(size: compact ? 9 : 10))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text("$\(player.chips)")
                .font(.system(size: compact ? 9 : 10, weight: .bold))
                .foregroundColor(.yellow)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(.ultraThinMaterial)
        .cornerRadius(4)
    }
}

// MARK: - Player Bet View

struct PlayerBetView: View {
    let bet: Int
    
    var body: some View {
        Group {
            if bet > 0 {
                Text("$\(bet)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.orange.opacity(0.7)))
            }
        }
    }
}
