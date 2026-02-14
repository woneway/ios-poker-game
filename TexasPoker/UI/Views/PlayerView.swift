import SwiftUI

// MARK: - Player View (Simplified)

struct PlayerView: View {
    let player: Player
    let isActive: Bool
    let isDealer: Bool
    var isHero: Bool = false
    var showCards: Bool = false
    var compact: Bool = false
    var gameMode: GameMode = .cashGame
    
    @State private var showProfile = false
    @State private var playerStats: PlayerStats? = nil
    @State private var isWinner = false
    
    // MARK: - Computed Properties
    
    private var avatar: String {
        player.aiProfile?.avatar ?? (player.isHuman ? "🤠" : "🤖")
    }
    
    private var avatarSize: CGFloat {
        let base: CGFloat = compact ? 44 : 56
        return base * DeviceHelper.scaleFactor
    }
    
    private var cardWidth: CGFloat {
        let base: CGFloat = compact ? 32 : 42
        return base * DeviceHelper.scaleFactor
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 2) {
            // Cards
            PlayerCardsView(
                player: player,
                isHero: isHero,
                showCards: showCards,
                cardWidth: cardWidth
            )
            
            // Avatar
            PlayerAvatarView(
                avatar: avatar,
                isActive: isActive,
                isDealer: isDealer,
                playerStatus: player.status,
                playerStats: playerStats,
                avatarSize: avatarSize,
                onTap: { showProfile = true }
            )
            .onAppear { loadPlayerStats() }
            .onReceive(NotificationCenter.default.publisher(for: PokerEngine.EngineNotifications.playerStatsUpdated)) { notification in
                if let modeRaw = notification.userInfo?["gameMode"] as? String,
                   modeRaw != gameMode.rawValue {
                    return
                }
                loadPlayerStats()
            }
            .onReceiveWinnerNotification(for: player)
            
            // Name & Chips
            PlayerInfoView(
                player: player,
                compact: compact,
                isActive: isActive
            )
            
            // Statistics HUD
            PlayerHUD(playerName: player.name, gameMode: gameMode)
            
            // Current Bet
            PlayerBetView(bet: player.currentBet)
        }
        .opacity(player.status == .folded || player.status == .eliminated ? 0.55 : 1.0)
        .scaleEffect(isActive ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isActive)
        .popover(isPresented: $showProfile) {
            ProfilePopover(player: player, stats: playerStats)
        }
    }
    
    // MARK: - Private Methods
    
    private func loadPlayerStats() {
        playerStats = StatisticsCalculator.shared.calculateStats(
            playerName: player.name,
            gameMode: gameMode
        )
    }
}

// MARK: - Winner Notification Extension

extension View {
    func onReceiveWinnerNotification(for player: Player) -> some View {
        self.onReceive(
            NotificationCenter.default.publisher(for: NSNotification.Name("PlayerWon"))
        ) { notification in
            if let winnerID = notification.userInfo?["playerID"] as? UUID,
               winnerID == player.id {
                // Handle winner animation in parent
                NotificationCenter.default.post(
                    name: NSNotification.Name("LocalPlayerWon"),
                    object: nil,
                    userInfo: ["playerID": player.id]
                )
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PlayerView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerView(
            player: Player(
                name: "Test Player",
                chips: 1000,
                isHuman: true,
                aiProfile: AIProfile(
                    name: "Test",
                    avatar: "🤖",
                    description: "Test AI",
                    tightness: 0.5,
                    aggression: 0.5,
                    bluffFreq: 0.2,
                    foldTo3Bet: 0.5,
                    cbetFreq: 0.6,
                    cbetTurnFreq: 0.45,
                    positionAwareness: 0.5,
                    tiltSensitivity: 0.2,
                    callDownTendency: 0.3
                )
            ),
            isActive: true,
            isDealer: true
        )
        .previewLayout(.sizeThatFits)
    }
}
#endif
