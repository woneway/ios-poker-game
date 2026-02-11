import SwiftUI

struct PlayerView: View {
    let player: Player
    let isActive: Bool
    let isDealer: Bool
    var showCards: Bool = false
    var compact: Bool = false
    var gameMode: GameMode = .cashGame
    
    @State private var showProfile = false
    @State private var playerStats: PlayerStats? = nil
    @State private var isWinner = false
    
    private var avatar: String {
        return player.aiProfile?.avatar ?? (player.isHuman ? "🤠" : "🤖")
    }
    
    private var shouldShowCardFace: Bool {
        return player.isHuman || showCards
    }
    
    private var avatarSize: CGFloat { compact ? 44 : 56 }
    private var cardWidth: CGFloat { compact ? 28 : 36 }
    
    var body: some View {
        VStack(spacing: 2) {
            // Cards
            if !player.holeCards.isEmpty && player.status != .folded {
                HStack(spacing: -(cardWidth * 0.35)) {
                    ForEach(player.holeCards) { card in
                        if shouldShowCardFace {
                            CardView(card: card, width: cardWidth)
                        } else {
                            CardView(card: nil, width: cardWidth)
                        }
                    }
                }
                .padding(.bottom, -6)
                .zIndex(1)
            } else if player.status == .folded || player.status == .eliminated {
                Color.clear.frame(height: compact ? 16 : 24)
            } else {
                Color.clear.frame(height: compact ? 16 : 24)
            }
            
            // Avatar (tappable)
            ZStack {
                if isActive {
                    Circle()
                        .fill(Color.yellow.opacity(0.5))
                        .frame(width: avatarSize + 12, height: avatarSize + 12)
                        .blur(radius: 4)
                }
                
                Circle()
                    .fill(Color(white: 0.15))
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay(
                        Circle().stroke(
                            isActive ? Color.yellow : (player.status == .folded ? Color.gray.opacity(0.3) : Color.gray.opacity(0.6)),
                            lineWidth: isActive ? 2.5 : 1
                        )
                    )
                    .shadow(
                        color: isWinner ? .yellow : .clear,
                        radius: isWinner ? 20 : 0
                    )
                    .scaleEffect(isWinner ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatCount(3, autoreverses: true), value: isWinner)
                
                Text(avatar)
                    .font(.system(size: avatarSize * 0.5))
                
                // Dealer Button
                if isDealer {
                    Text("D")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.black)
                        .frame(width: 14, height: 14)
                        .background(Color.white)
                        .clipShape(Circle())
                        .offset(x: avatarSize * 0.4, y: -avatarSize * 0.35)
                }
                
                // Statistics HUD Badge (VPIP/PFR)
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
                
                // Status Overlay
                if player.status == .folded {
                    Text("FOLD")
                        .font(.system(size: 7, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(3)
                } else if player.status == .allIn {
                    Text("ALL IN")
                        .font(.system(size: 7, weight: .black))
                        .foregroundColor(.red)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(3)
                }
            }
            .onTapGesture {
                showProfile = true
            }
            .onAppear {
                loadPlayerStats()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PlayerWon"))) { notification in
                if let winnerID = notification.userInfo?["playerID"] as? UUID, winnerID == player.id {
                    isWinner = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isWinner = false
                    }
                }
            }
            
            // Name & Chips
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
            .background(Color.black.opacity(0.5))
            .cornerRadius(4)
            
            // Statistics HUD
            PlayerHUD(playerName: player.name, gameMode: gameMode)
            
            // Current Bet
            if player.currentBet > 0 {
                Text("$\(player.currentBet)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.orange.opacity(0.7)))
            }
        }
        .opacity(player.status == .folded || player.status == .eliminated ? 0.45 : 1.0)
        .scaleEffect(isActive ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isActive)
        .popover(isPresented: $showProfile) {
            ProfilePopover(player: player, stats: playerStats)
        }
    }
    
    // MARK: - Load Statistics
    
    private func loadPlayerStats() {
        playerStats = StatisticsCalculator.shared.calculateStats(
            playerName: player.name,
            gameMode: gameMode
        )
    }
}

// MARK: - Profile Popover

struct ProfilePopover: View {
    let player: Player
    let stats: PlayerStats?
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack(spacing: 10) {
                Text(player.aiProfile?.avatar ?? (player.isHuman ? "🤠" : "🤖"))
                    .font(.system(size: 40))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name)
                        .font(.system(size: 18, weight: .bold))
                    
                    if let profile = player.aiProfile {
                        Text(profile.description)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else if player.isHuman {
                        Text("你自己")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.top, 8)
            
            Divider()
            
            if let profile = player.aiProfile {
                // AI Character Traits
                VStack(spacing: 8) {
                    traitRow(label: "打法风格",
                             value: playStyleText(profile),
                             icon: "suit.spade.fill",
                             color: .blue)
                    
                    traitBar(label: "紧度",
                             detail: tightnessText(profile),
                             value: profile.tightness,
                             color: .cyan)
                    
                    traitBar(label: "凶度",
                             detail: aggressionText(profile),
                             value: profile.aggression,
                             color: .red)
                    
                    traitBar(label: "诈唬频率",
                             detail: bluffText(profile),
                             value: profile.bluffFreq,
                             color: .purple)
                    
                    traitBar(label: "位置意识",
                             detail: positionText(profile),
                             value: profile.positionAwareness,
                             color: .green)
                    
                    traitBar(label: "情绪化程度",
                             detail: tiltText(profile),
                             value: profile.tiltSensitivity,
                             color: .orange)
                    
                    if profile.currentTilt > 0.05 {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 12))
                            Text("当前上头: \(Int(profile.currentTilt * 100))%")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
                
                Divider()
                
                // Tips for playing against this type
                VStack(alignment: .leading, spacing: 4) {
                    Text("对策建议")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Text(strategyTip(profile))
                        .font(.system(size: 12))
                        .foregroundColor(.primary.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                
            } else if player.isHuman {
                // Hero stats
                VStack(spacing: 6) {
                    traitRow(label: "身份", value: "主角（你）", icon: "person.fill", color: .blue)
                    
                    HStack {
                        Text("筹码")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("$\(player.chips)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            // Statistics Section (for all players if available)
            if let stats = stats, stats.totalHands > 0 {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("统计数据 (\(stats.totalHands) 手)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        statItem(label: "VPIP", value: String(format: "%.1f%%", stats.vpip), color: .blue)
                        statItem(label: "PFR", value: String(format: "%.1f%%", stats.pfr), color: .purple)
                        statItem(label: "AF", value: String(format: "%.2f", stats.af), color: .red)
                    }
                    
                    HStack(spacing: 16) {
                        statItem(label: "WTSD", value: String(format: "%.1f%%", stats.wtsd), color: .green)
                        statItem(label: "W$SD", value: String(format: "%.1f%%", stats.wsd), color: .orange)
                    }
                    
                    HStack {
                        Text("胜率")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(stats.handsWon)/\(stats.totalHands) (\(String(format: "%.1f%%", Double(stats.handsWon) / Double(stats.totalHands) * 100)))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.cyan)
                    }
                    
                    HStack {
                        Text("总盈利")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("$\(stats.totalWinnings)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(stats.totalWinnings >= 0 ? .green : .red)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 280)
    }
    
    // MARK: - Trait Row with Icon
    
    private func traitRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
                .frame(width: 16)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Trait Bar
    
    private func traitBar(label: String, detail: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Text(detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(color)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(value), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
    
    // MARK: - Text Descriptions
    
    private func playStyleText(_ p: AIProfile) -> String {
        if p.tightness >= 0.75 && p.aggression >= 0.6 { return "紧凶型 (TAG)" }
        if p.tightness >= 0.75 && p.aggression < 0.4 { return "紧弱型 (岩石)" }
        if p.tightness < 0.35 && p.aggression >= 0.7 { return "松凶型 (LAG)" }
        if p.tightness < 0.35 && p.aggression < 0.3 { return "松弱型 (鱼)" }
        if p.name == "艾米" { return "GTO 数学流" }
        if p.tiltSensitivity > 0.7 { return "情绪型 / 易上头" }
        return "平衡型 (TAG)"
    }
    
    private func tightnessText(_ p: AIProfile) -> String {
        let vpip = Int((1.0 - p.tightness) * 100)
        if p.tightness >= 0.80 { return "极紧 (VPIP ~\(vpip)%)" }
        if p.tightness >= 0.55 { return "偏紧 (VPIP ~\(vpip)%)" }
        if p.tightness >= 0.35 { return "偏松 (VPIP ~\(vpip)%)" }
        return "极松 (VPIP ~\(vpip)%)"
    }
    
    private func aggressionText(_ p: AIProfile) -> String {
        if p.aggression >= 0.80 { return "极度凶猛" }
        if p.aggression >= 0.60 { return "凶猛" }
        if p.aggression >= 0.40 { return "中等" }
        return "被动"
    }
    
    private func bluffText(_ p: AIProfile) -> String {
        if p.bluffFreq >= 0.35 { return "频繁诈唬" }
        if p.bluffFreq >= 0.20 { return "适度诈唬" }
        if p.bluffFreq >= 0.10 { return "很少诈唬" }
        return "几乎不诈唬"
    }
    
    private func positionText(_ p: AIProfile) -> String {
        if p.positionAwareness >= 0.80 { return "大师级" }
        if p.positionAwareness >= 0.50 { return "中等" }
        return "忽略位置"
    }
    
    private func tiltText(_ p: AIProfile) -> String {
        if p.tiltSensitivity >= 0.70 { return "容易上头" }
        if p.tiltSensitivity >= 0.30 { return "偶尔失控" }
        if p.tiltSensitivity >= 0.10 { return "心态稳定" }
        return "铁石心肠"
    }
    
    // MARK: - Stat Item
    
    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
        }
    }
    
    // MARK: - Strategy Tips
    
    private func strategyTip(_ p: AIProfile) -> String {
        if p.tightness >= 0.80 {
            return "这个玩家下注时几乎总有强牌。面对他的加注果断弃掉中等牌，但要频繁偷他的盲注。"
        }
        if p.tightness < 0.35 && p.aggression >= 0.7 {
            return "这个玩家什么牌都敢打。拿到强牌别弃！让他对你诈唬，用大牌设陷阱。"
        }
        if p.callDownTendency >= 0.70 {
            return "永远不要对这个玩家诈唬——他什么都跟。拿到任何成牌都要猛下价值注，哪怕只有小对子。"
        }
        if p.name == "艾米" {
            return "这个玩家严格按GTO策略打牌。可以利用她在某些位置防守不足的弱点，或在小底池打得比她更紧。"
        }
        if p.tiltSensitivity >= 0.70 {
            return "输了大底池后这个玩家会失控乱打。耐心等待强牌，在他上头时狠狠收割。"
        }
        if p.positionAwareness >= 0.80 {
            return "在有利位置时非常危险。尽量避免在他有位置优势时对抗，多用3-bet反击他的后位开池。"
        }
        return "平衡型玩家。寻找他的小漏洞——凶度略高或某些位置偏紧的弱点。"
    }
}
