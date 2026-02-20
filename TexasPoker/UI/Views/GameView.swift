import SwiftUI
import SpriteKit
import Combine

struct GameView: View {
    @ObservedObject var settings: GameSettings
    @StateObject private var store: PokerGameStore
    @Environment(\.colorScheme) var colorScheme
    
    @State private var cancellables = Set<AnyCancellable>()
    
    init(settings: GameSettings, difficulty: AIProfile.Difficulty? = nil, playerCount: Int = 8) {
        self.settings = settings
        let config = settings.getTournamentConfig()
        let cashGameConfig = settings.getCashGameConfig()
        _store = StateObject(wrappedValue: PokerGameStore(
            mode: settings.gameMode,
            config: config,
            cashGameConfig: cashGameConfig,
            difficulty: difficulty ?? settings.aiDifficulty,
            playerCount: playerCount
        ))
    }
    
    private func setupCombineSubscribers() {
        let scene = self.scene
        GameEventPublisher.shared.chipAnimation
            .receive(on: DispatchQueue.main)
            .sink { event in
                scene.animateChipToPot(from: event.seatIndex, amount: event.amount)
            }
            .store(in: &cancellables)
        
        GameEventPublisher.shared.winnerChipAnimation
            .receive(on: DispatchQueue.main)
            .sink { event in
                scene.animateWinnerChips(to: event.seatIndex, amount: event.amount)
            }
            .store(in: &cancellables)
        
        GameEventPublisher.shared.playerAction
            .receive(on: DispatchQueue.main)
            .sink { event in
                if event.isThinking {
                    PlayerAnimationManager.shared.startAnimation(for: event.playerID.uuidString, type: .thinking)
                }
            }
            .store(in: &cancellables)
        
        GameEventPublisher.shared.playerWon
            .receive(on: DispatchQueue.main)
            .sink { event in
                if let index = store.engine.players.firstIndex(where: { $0.id == event.playerID }) {
                    scene.animateWinnerChips(to: index, amount: store.engine.pot.total / store.engine.winners.count)
                }
            }
            .store(in: &cancellables)
        
        GameEventPublisher.shared.playerStatsUpdated
            .receive(on: DispatchQueue.main)
            .sink { _ in
                store.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        GameEventPublisher.shared.aiDecision
            .receive(on: DispatchQueue.main)
            .sink { event in
                #if DEBUG
                print("🤔 \(event.playerName): \(event.action) - \(event.reasoning)")
                print("   Equity: \(String(format:"%.1f%%", event.equity * 100)) | PotOdds: \(String(format:"%.1f%%", event.potOdds * 100))")
                #endif
                // Show AI decision toast
                self.aiDecisionToast = event
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    if self.aiDecisionToast?.playerID == event.playerID {
                        self.aiDecisionToast = nil
                    }
                }
            }
            .store(in: &cancellables)
        
        // AI入场事件 - 记录买入次数
        GameEventPublisher.shared.aiEntry
            .receive(on: DispatchQueue.main)
            .sink { [self] event in
                for _ in 0..<event.count {
                    store.recordAIPurchase()
                }
            }
            .store(in: &cancellables)
    }
    
    @State private var showSettings = false
    @State private var lastProfileId: String = ProfileManager.shared.currentProfileId
    @State private var showRaisePanel = false
    @State private var raiseSliderValue: Double = 0  // 0..1 mapped to minRaise..allIn
    
    // MARK: - Action Log State (Portrait)
    @State private var isActionLogExpanded: Bool = false
    @State private var unreadLogCount: Int = 0
    @State private var toastEntry: ActionLogEntry? = nil
    @State private var lastKnownLogCount: Int = 0
    @State private var aiDecisionToast: AIDecisionEvent? = nil
    
    // MARK: - Session Summary State
    @State private var showSessionSummary = false
    @State private var sessionSummaryData: SessionSummaryData?
    
    // MARK: - Tournament Leaderboard State
    @State private var showTournamentLeaderboard = false
    
    @State private var scene: PokerTableScene = {
        let scene = PokerTableScene()
        scene.size = CGSize(width: 300, height: 600)  // 高度增加到 600
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        return scene
    }()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Premium background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "1a1a2e"),
                        Color(hex: "16213e"),
                        Color(hex: "0f3460")
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                Group {
                    if DeviceHelper.isIPad && DeviceHelper.isLandscape(geo) {
                        landscapeLayout(geo: geo)
                    } else {
                        portraitLayout(geo: geo)
                    }
                }
            }
        }
        .overlay {
            if store.showRankings && !store.finalResults.isEmpty {
                RankingsView(
                    results: store.finalResults,
                    totalHands: store.engine.handNumber,
                    onNewGame: {
                        store.resetGame(
                            mode: settings.gameMode,
                            config: settings.getTournamentConfig()
                        )
                    }
                )
                .animation(.easeInOut(duration: 0.3), value: store.showRankings)
            }
            
            // Tournament Leaderboard Overlay
            if showTournamentLeaderboard {
                TournamentLeaderboardOverlay(
                    store: store,
                    isPresented: $showTournamentLeaderboard
                )
                .transition(.move(edge: .trailing))
            }
            
            // Spectator Overlay
            if store.state == .spectating {
                SpectatorOverlay(store: store)
                    .transition(.move(edge: .bottom))
                    .animation(.easeInOut(duration: 0.3), value: store.state)
            }
        }
        // Leave confirmation dialog
        .alert("离开牌桌", isPresented: $store.showLeaveConfirm) {
            Button("确认离开", role: .destructive) {
                store.send(.leaveTable)
            }
            Button("取消", role: .cancel) {}
        } message: {
            let hero = store.engine.players.first(where: { $0.isHuman })
            let chips = hero?.chips ?? 0
            let profit = store.currentSession?.netProfit ?? 0
            Text("当前筹码: $\(chips)\n本次盈亏: \(profit >= 0 ? "+" : "")\(profit)")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                settings: settings,
                isPresented: $showSettings,
                onQuit: {
                    store.resetGame(
                        mode: settings.gameMode,
                        config: settings.getTournamentConfig()
                    )
                }
            )
        }
        .onAppear {
            setupCombineSubscribers()

            scene.onAnimationComplete = {
                DispatchQueue.main.async { store.send(.dealComplete) }
            }
        }
        .onDisappear {
            cancellables.removeAll()
        }
        .onChangeCompat(of: store.state) { newState in
            if newState == .dealing {
                let activeSeats = store.engine.players.enumerated()
                    .filter { $0.element.status == .active || $0.element.status == .allIn }
                    .map { $0.offset }
                scene.playDealAnimation(activeSeatIndices: activeSeats)
            }
        }
        .onChangeCompat(of: store.engine.isHandOver) { isOver in
            if isOver && settings.soundEnabled { SoundManager.shared.playSound(.win) }
            if isOver {
                // Update tournament stats
                if store.engine.gameMode == .tournament {
                    TournamentStatsManager.shared.updateAfterHand(
                        handNumber: store.engine.handNumber,
                        players: store.engine.players,
                        engine: store.engine
                    )
                }
                
                // 现金局：检查Hero是否被淘汰，如果可以买入则显示买入界面
                if store.engine.gameMode == .cashGame,
                   let hero = store.engine.players.first(where: { $0.isHuman }),
                   hero.chips <= 0 {
                    // Hero被淘汰，检查是否还可以买入
                    let canBuyIn: Bool
                    if let session = store.currentSession {
                        canBuyIn = !session.isBuyInLimitReached
                    } else {
                        // 没有session（第一手牌），允许买入
                        canBuyIn = true
                    }
                    
                    if canBuyIn {
                        // 可以买入，显示买入界面
                        store.showBuyIn = true
                        #if DEBUG
                        print("💰 Hero被淘汰，显示rebuy界面 (from GameView)")
                        #endif
                    }
                }
                
                // Trigger session summary
                prepareSessionSummary()
            }
        }
        .onChangeCompat(of: store.engine.actionLog.count) { newCount in
            let delta = newCount - lastKnownLogCount
            if delta <= 0 {
                // 日志被清空（新一手牌开始）
                lastKnownLogCount = newCount
                unreadLogCount = 0
                return
            }
            lastKnownLogCount = newCount
            
            guard !isActionLogExpanded else { return }
            unreadLogCount += delta
            if let latest = store.engine.actionLog.last {
                showToast(latest)
            }
        }
        .onChangeCompat(of: settings.gameMode) { newMode in
            if store.state == .idle {
                store.resetGame(
                    mode: newMode,
                    config: settings.getTournamentConfig()
                )
            }
        }
        .onChangeCompat(of: settings.tournamentPreset) { _ in
            if store.state == .idle && settings.gameMode == .tournament {
                store.resetGame(
                    mode: .tournament,
                    config: settings.getTournamentConfig()
                )
            }
        }
        // Profile switch handling - reset game when profile changes
        .onChangeCompat(of: ProfileManager.shared.currentProfileId) { newProfileId in
            // Only reset if profile actually changed (not initial load)
            if newProfileId != lastProfileId {
                #if DEBUG
                print("👤 Profile changed from \(lastProfileId) to \(newProfileId) - resetting game")
                #endif
                lastProfileId = newProfileId
                store.resetGame(
                    mode: settings.gameMode,
                    config: settings.getTournamentConfig()
                )
            }
        }
        .overlay(sessionSummaryOverlay)
        // Cash Game Session Summary Overlay
        .overlay {
            if store.showCashSessionSummary, let session = store.currentSession {
                CashSessionSummaryView(
                    session: session,
                    onBackToMenu: {
                        store.resetGame(mode: .cashGame)
                    },
                    onRejoin: {
                        store.showCashSessionSummary = false
                        store.showBuyIn = true
                    }
                )
            }
        }
        // Buy-in Overlay
        .overlay {
            if store.showBuyIn && store.engine.gameMode == .cashGame {
                let config = store.engine.cashGameConfig ?? .default
                let remainingBuyIns = store.currentSession?.remainingBuyIns ?? config.maxBuyIns
                
                BuyInView(
                    config: config,
                    remainingBuyIns: remainingBuyIns,
                    onConfirm: { buyInAmount in
                        // 关闭买入界面
                        store.showBuyIn = false
                        
                        // 检查是首次买入还是rebuy
                        if store.currentSession != nil {
                            // Rebuy: 更新现有session
                            if var session = store.currentSession {
                                session.topUpTotal += buyInAmount
                                store.currentSession = session
                            }
                        } else {
                            // 首次买入：创建新session，使用配置中的maxBuyIns
                            store.startCashSession(buyIn: buyInAmount, maxBuyIns: config.maxBuyIns)
                        }
                        
                        // 设置 Hero 筹码并设为active
                        if let idx = store.engine.players.firstIndex(where: { $0.isHuman }) {
                            store.engine.players[idx].chips = buyInAmount
                            store.engine.players[idx].status = .active
                        }
                        // 设置 AI 筹码 - 只对已淘汰的 AI 设置新买入
                        for i in 0..<store.engine.players.count {
                            guard !store.engine.players[i].isHuman else { continue }
                            if store.engine.players[i].status == .eliminated {
                                store.engine.players[i].chips = CashGameManager.randomAIBuyIn(
                                    config: store.engine.cashGameConfig ?? .default
                                )
                                store.engine.players[i].status = .active
                                // 记录AI买入
                                store.recordAIPurchase()
                            }
                        }
                        
                        // 重置盈利计算起点
                        store.resetHeroChipsAtHandStart()
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Session Summary
    
    private var sessionSummaryOverlay: some View {
        Group {
            if showSessionSummary, let data = sessionSummaryData {
                SessionSummaryView(
                    handNumber: data.handNumber,
                    heroWinnings: data.winnings,
                    heroCards: data.heroCards,
                    communityCards: data.communityCards,
                    handResult: data.result,
                    totalHands: data.totalHands,
                    totalProfit: data.totalProfit,
                    onDismiss: {
                        withAnimation { showSessionSummary = false }
                    },
                    onNextHand: {
                        withAnimation { showSessionSummary = false }
                        store.send(.nextHand)
                    }
                )
                .transition(.opacity)
            }
        }
    }
    
    private func prepareSessionSummary() {
        guard let hero = store.engine.players.first(where: { $0.isHuman }) else { return }
        
        // Calculate winnings from the last hand
        let heroWasWinner = store.engine.winners.contains(hero.id)
        let winnings = heroWasWinner ? store.engine.pot.total : -hero.currentBet
        
        // Determine hand result
        let result: SessionHandResult = {
            if hero.status == .folded { return .fold }
            if heroWasWinner { return .win }
            return .loss
        }()
        
        sessionSummaryData = SessionSummaryData(
            handNumber: store.engine.handNumber,
            winnings: winnings,
            heroCards: hero.holeCards,
            communityCards: store.engine.communityCards,
            result: result,
            totalHands: store.engine.handNumber,
            totalProfit: calculateTotalProfit()
        )
        
        // Delay showing the summary slightly for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation { showSessionSummary = true }
        }
    }
    
    private func calculateTotalProfit() -> Int {
        // This would ideally calculate from hand history
        // For now, return approximate value
        return store.engine.players.first(where: { $0.isHuman })?.chips ?? 0 - 1000
    }
    
    // MARK: - Layout Functions
    
    private func portraitLayout(geo: GeometryProxy) -> some View {
        ZStack {
            // Background - Premium dark gradient
            Color.adaptiveTableBackground(colorScheme)
                .edgesIgnoringSafeArea(.all)
            
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.8)
                ]),
                center: .center,
                startRadius: 200,
                endRadius: max(geo.size.width, geo.size.height)
            )
            .edgesIgnoringSafeArea(.all)
            
            // Table felt ellipse - Premium look
            ZStack {
                // Table Shadow
                Ellipse()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: geo.size.width * 0.90, height: geo.size.height * 0.72)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.48 + 10)
                    .blur(radius: 20)
                
                // Table Border (Wood/Leather)
                Ellipse()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "3E2723"), Color(hex: "1B0000")]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: geo.size.width * 0.90, height: geo.size.height * 0.72)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.48)
                    .overlay(
                        Ellipse()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            .frame(width: geo.size.width * 0.90, height: geo.size.height * 0.72)
                            .position(x: geo.size.width / 2, y: geo.size.height * 0.48)
                    )
                
                // Table Felt
                Ellipse()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.adaptiveTableFelt(colorScheme),
                                Color.adaptiveTableFelt(colorScheme).opacity(0.8)
                            ]),
                            center: .center,
                            startRadius: 20,
                            endRadius: 200
                        )
                    )
                    .frame(width: geo.size.width * 0.85, height: geo.size.height * 0.68)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.48)
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
            }
            
            // SpriteKit layer
            SpriteView(scene: scene, options: [.allowsTransparency])
                .edgesIgnoringSafeArea(.all)
                .allowsHitTesting(false)
            
            // Main game area (Moved out of HUD VStack to fix coordinate system issues)
            ZStack {
                // 8-player oval layout
                playerOvalLayout(geo: geo)
                
                // Community cards (center of table)
                communityCardsView(geo: geo)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 5)
                
                // Pot display
                GamePotDisplay(store: store)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.34)
            }
            
            // HUD
            VStack(spacing: 0) {
                // Top bar
                GameTopBar(
                    store: store,
                    showSettings: $showSettings,
                    unreadLogCount: unreadLogCount,
                    onToggleActionLog: toggleActionLog,
                    onShowLeaderboard: {
                        withAnimation { showTournamentLeaderboard = true }
                    }
                )
                .padding(.horizontal, 12)
                
                // Tournament info bar (below top bar, above table)
                if store.engine.gameMode == .tournament {
                    GameTournamentInfo(store: store)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                }
                
                Spacer(minLength: 0)
                
                // Hero controls (bottom)
                GameHeroControls(
                    store: store,
                    settings: settings,
                    showRaisePanel: $showRaisePanel,
                    raiseSliderValue: $raiseSliderValue,
                    showRankings: $store.showRankings
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            
            // 操作日志浮层（竖屏，条件渲染，从右侧滑入）
            if isActionLogExpanded {
                ActionLogOverlay(
                    entries: store.engine.actionLog,
                    panelWidth: min(160, geo.size.width * 0.38),
                    onClose: { toggleActionLog() }
                )
                .frame(height: geo.size.height * 0.35)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, geo.size.height * 0.28)
                .frame(maxHeight: .infinity, alignment: .top)
                .transition(.move(edge: .trailing))
            }
            
            // Toast 即时提示（面板收起时）
            if let entry = toastEntry, !isActionLogExpanded {
                ActionLogToast(entry: entry)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 12)
                    .padding(.top, 44)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            
            // AI 决策推理提示
            if let aiDecision = aiDecisionToast {
                AIDecisionToast(event: aiDecision)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                    .padding(.top, 80)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
    }
    
    private func landscapeLayout(geo: GeometryProxy) -> some View {
        ZStack {
            // Background - adaptive color
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.adaptiveTableBackground(colorScheme),
                    Color.adaptiveTableBackground(colorScheme).opacity(0.8)
                ]),
                center: .center,
                startRadius: 50,
                endRadius: max(geo.size.width, geo.size.height) * 0.6
            )
            .edgesIgnoringSafeArea(.all)
            
            HStack(spacing: 0) {
                // Left: Game area (75%)
                ZStack {
                    // Table felt ellipse (wider for landscape) - adaptive color
                    Ellipse()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.adaptiveTableFelt(colorScheme),
                                    Color.adaptiveTableFelt(colorScheme).opacity(0.8)
                                ]),
                                center: .center,
                                startRadius: 20,
                                endRadius: 300
                            )
                        )
                        .overlay(
                            Ellipse()
                                .strokeBorder(Color(hex: "8B4513").opacity(0.8), lineWidth: 6)
                        )
                        .frame(width: geo.size.width * 0.60, height: geo.size.height * 0.7)
                    
                    // SpriteKit layer
                    SpriteView(scene: scene, options: [.allowsTransparency])
                    
                    // Players and community cards
                    VStack {
                        GameTopBar(
                            store: store,
                            showSettings: $showSettings,
                            unreadLogCount: unreadLogCount,
                            onToggleActionLog: toggleActionLog,
                            onShowLeaderboard: {
                                withAnimation { showTournamentLeaderboard = true }
                            }
                        )
                        .padding(.horizontal, 12)
                        
                        Spacer()
                        
                        // Tournament info bar
                        if store.engine.gameMode == .tournament {
                            GameTournamentInfo(store: store)
                                .padding(.horizontal, 20)
                        }
                        
                        Spacer()
                        
                        // Community cards (larger for iPad)
                        communityCardsView(geo: geo)
                            .scaleEffect(DeviceHelper.scaleFactor)
                        
                        Spacer()
                        
                        // Pot display
                        GamePotDisplay(store: store)
                        
                        Spacer()
                    }
                    
                    // 8-player oval layout
                    playerOvalLayout(geo: geo)
                }
                .frame(width: geo.size.width * 0.75)
                
                // Right: Controls (25%)
                VStack(spacing: 16) {
                    // Action log
                    GameActionLogPanel(store: store)
                        .frame(height: geo.size.height * 0.4)
                    
                    Spacer()
                    
                    // Hero controls
                    GameHeroControls(
                        store: store,
                        settings: settings,
                        showRaisePanel: $showRaisePanel,
                        raiseSliderValue: $raiseSliderValue,
                        showRankings: $store.showRankings
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .frame(width: geo.size.width * 0.25)
                .background(Color.black.opacity(0.3))
            }
        }
    }
    
    // MARK: - Community Cards
    
    private func communityCardsView(geo: GeometryProxy) -> some View {
        let cardWidth: CGFloat = DeviceHelper.isIPad ? 52 : 40
        let cardHeight = cardWidth * 1.2
        let spacing: CGFloat = 4
        
        return HStack(spacing: spacing) {
            ForEach(Array(store.engine.communityCards.enumerated()), id: \.offset) { index, card in
                FlippingCard(card: card, delay: Double(index) * 0.15, width: cardWidth)
            }
            ForEach(0..<(5 - store.engine.communityCards.count), id: \.self) { _ in
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .frame(width: cardWidth, height: cardHeight)
            }
        }
    }
    
    // MARK: - 8-Player Oval Layout
    
    /// Layout 8 players around an oval table
    /// Seat 0 (Hero): bottom center
    /// Seats 1-7: clockwise around the oval
    private func playerOvalLayout(geo: GeometryProxy) -> some View {
        let w = geo.size.width
        let h = geo.size.height
        let heroIndex = store.engine.players.firstIndex(where: { $0.isHuman }) ?? 0
        
        // 牌桌边框椭圆: rx = w*0.45, ry = h*0.34, center = (w/2, h*0.45)
        // 玩家头像中心应在边框外约 24pt
        let centerX = w / 2
        let centerY = h * 0.44
        let radiusX = w * 0.45 + 24   // 桌布边框半径 + 外推
        let radiusY = h * 0.34 + 24   // 桌布边框半径 + 外推
        
        // Seat positions as angles (starting from bottom, going clockwise)
        let seatAngles: [Double] = [
            270,  // 0: Hero (bottom center)
            225,  // 1: bottom-left
            180,  // 2: left
            135,  // 3: top-left
            90,   // 4: top center
            45,   // 5: top-right
            0,    // 6: right
            315   // 7: bottom-right
        ]
        
        return ZStack {
            ForEach(0..<min(store.engine.players.count, 8), id: \.self) { i in
                let angle = seatAngles[i] * .pi / 180
                let rawX = centerX + radiusX * cos(angle)
                let rawY = centerY - radiusY * sin(angle)
                let isShowdown = store.state == .showdown
                // 屏幕边界保护
                let x = min(max(rawX, 52), w - 52)
                let y = min(max(rawY, 60), h - 100)
                
                if i == heroIndex {
                    let isActiveInPlay = store.engine.activePlayerIndex == i
                        && (store.state == .waitingForAction || store.state == .betting)
                    PlayerView(
                        player: store.engine.players[i],
                        isActive: isActiveInPlay,
                        isDealer: store.engine.dealerIndex == i,
                        isHero: true,
                        showCards: true,
                        compact: false,
                        gameMode: store.engine.gameMode
                    )
                    .position(x: x, y: min(y, h - 120))
                    .zIndex(100)
                } else {
                    let isActiveInPlay = store.engine.activePlayerIndex == i
                        && (store.state == .waitingForAction || store.state == .betting)
                    PlayerView(
                        player: store.engine.players[i],
                        isActive: isActiveInPlay,
                        isDealer: store.engine.dealerIndex == i,
                        showCards: isShowdown,
                        compact: true,
                        gameMode: store.engine.gameMode
                    )
                    .position(x: x, y: y)
                    .zIndex(Double(10 - i))
                }
            }
        }
        .frame(width: w, height: h)
    }
    
    // MARK: - Action Log Toggle (Portrait)
    
    private func toggleActionLog() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isActionLogExpanded.toggle()
        }
        if isActionLogExpanded {
            unreadLogCount = 0
        }
    }
    
    private func showToast(_ entry: ActionLogEntry) {
        withAnimation(.easeInOut(duration: 0.2)) {
            toastEntry = entry
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                if toastEntry?.id == entry.id {
                    toastEntry = nil
                }
            }
        }
    }
}

