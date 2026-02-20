import SwiftUI

// MARK: - Animation Modifier

struct AnimationModifier: ViewModifier {
    let animation: PlayerAnimationType?
    let emotion: PlayerEmotion
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let anim = animation {
                    emotionBadge(for: anim)
                        .offset(y: -20)
                }
            }
            .scaleEffect(scaleForAnimation)
            .shakeEffect(shouldShake)
            .glowEffect(shouldGlow)
    }
    
    private var scaleForAnimation: CGFloat {
        guard let anim = animation else { return 1.0 }
        switch anim {
        case .winning, .bigWin, .celebration: return 1.1
        case .losing: return 0.95
        case .allIn: return 1.05
        default: return 1.0
        }
    }
    
    private var shouldShake: Bool {
        guard let anim = animation else { return false }
        return anim == .losing || anim == .tilt
    }
    
    private var shouldGlow: Bool {
        guard let anim = animation else { return false }
        return anim == .winning || anim == .bigWin || anim == .celebration
    }
    
    @ViewBuilder
    private func emotionBadge(for anim: PlayerAnimationType) -> some View {
        if anim != .idle && anim != .acting && anim != .cardReveal {
            Text(emotion.emoji)
                .font(.title2)
                .transition(.scale.combined(with: .opacity))
        }
    }
}

extension View {
    func shakeEffect(_ enabled: Bool) -> some View {
        self.modifier(ShakeModifier(enabled: enabled))
    }
    
    func glowEffect(_ enabled: Bool) -> some View {
        self.shadow(color: .yellow.opacity(enabled ? 0.8 : 0), radius: enabled ? 15 : 0)
    }
}

struct ShakeModifier: ViewModifier {
    let enabled: Bool
    @State private var shakeOffset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onChangeCompat(of: enabled) { newValue in
                if newValue {
                    withAnimation(.default.repeatForever(autoreverses: true).speed(4)) {
                        shakeOffset = 3
                    }
                } else {
                    withAnimation(.default) {
                        shakeOffset = 0
                    }
                }
            }
    }
}

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
    @StateObject private var animationManager = PlayerAnimationManager.shared
    
    private var playerId: String { player.id.uuidString }
    
    private var currentAnimation: PlayerAnimationType? {
        animationManager.currentAnimations[playerId]
    }
    
    private var currentEmotion: PlayerEmotion {
        animationManager.playerEmotions[playerId] ?? .neutral
    }
    
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
            
            // Stats Badge (VPIP/PFR) - between avatar and name so it occupies layout space
            if let stats = playerStats, stats.totalHands >= 20, player.status != .folded {
                HStack(spacing: 2) {
                    Text("\(Int(stats.vpip))")
                        .foregroundColor(.green)
                    Text("/")
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(Int(stats.pfr))")
                        .foregroundColor(.orange)
                }
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.7))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
            }
            
            // Name & Chips
            PlayerInfoView(
                player: player,
                compact: compact,
                isActive: isActive
            )
            
            // Statistics HUD
            PlayerHUD(playerName: player.displayName, gameMode: gameMode)
            
            // Current Bet
            PlayerBetView(bet: player.currentBet)
        }
        .modifier(AnimationModifier(
            animation: currentAnimation,
            emotion: currentEmotion
        ))
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
                    id: "test_ai",
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
                    callDownTendency: 0.3,
                    riskTolerance: 0.5,
                    bluffDetection: 0.5,
                    deepStackThreshold: 200
                )
            ),
            isActive: true,
            isDealer: true
        )
        .previewLayout(.sizeThatFits)
    }
}
#endif
