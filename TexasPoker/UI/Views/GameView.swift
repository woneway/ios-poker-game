import SwiftUI
import SpriteKit
import Combine

struct GameView: View {
    @ObservedObject var settings: GameSettings
    @StateObject private var store: PokerGameStore
    @Environment(\.colorScheme) var colorScheme
    
    init(settings: GameSettings) {
        self.settings = settings
        let config = settings.getTournamentConfig()
        _store = StateObject(wrappedValue: PokerGameStore(
            mode: settings.gameMode,
            config: config
        ))
    }
    @State private var showSettings = false
    @State private var showRaisePanel = false
    @State private var raiseSliderValue: Double = 0  // 0..1 mapped to minRaise..allIn
    
    // MARK: - Action Log State (Portrait)
    @State private var isActionLogExpanded: Bool = false
    @State private var unreadLogCount: Int = 0
    @State private var toastEntry: ActionLogEntry? = nil
    @State private var lastKnownLogCount: Int = 0
    
    @State private var scene: PokerTableScene = {
        let scene = PokerTableScene()
        scene.size = CGSize(width: 300, height: 600)
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        return scene
    }()
    
    var body: some View {
        GeometryReader { geo in
            Group {
                if DeviceHelper.isIPad && DeviceHelper.isLandscape(geo) {
                    landscapeLayout(geo: geo)
                } else {
                    portraitLayout(geo: geo)
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
            scene.onAnimationComplete = {
                DispatchQueue.main.async { store.send(.dealComplete) }
            }
            
            // Listen for chip animation notifications
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ChipAnimation"),
                object: nil,
                queue: .main
            ) { notification in
                if let seatIndex = notification.userInfo?["seatIndex"] as? Int,
                   let amount = notification.userInfo?["amount"] as? Int {
                    scene.animateChipToPot(from: seatIndex, amount: amount)
                }
            }
            
            // Listen for winner chip animation notifications
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("WinnerChipAnimation"),
                object: nil,
                queue: .main
            ) { notification in
                if let seatIndex = notification.userInfo?["seatIndex"] as? Int,
                   let amount = notification.userInfo?["amount"] as? Int {
                    scene.animateWinnerChips(to: seatIndex, amount: amount)
                }
            }
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
                    .frame(width: geo.size.width * 0.92, height: geo.size.height * 0.52)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.42 + 10)
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
                    .frame(width: geo.size.width * 0.92, height: geo.size.height * 0.52)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
                    .overlay(
                        Ellipse()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            .frame(width: geo.size.width * 0.92, height: geo.size.height * 0.52)
                            .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
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
                    .frame(width: geo.size.width * 0.86, height: geo.size.height * 0.48)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5) // Inner shadow simulation
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
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.38)
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 5)
                
                // Pot display
                GamePotDisplay(store: store)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.30)
            }
            
            // HUD
            VStack(spacing: 0) {
                // Top bar
                GameTopBar(
                    store: store,
                    showSettings: $showSettings,
                    unreadLogCount: unreadLogCount,
                    onToggleActionLog: toggleActionLog
                )
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
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
                            onToggleActionLog: toggleActionLog
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
        let cardWidth = DeviceHelper.cardWidth(for: geo)
        let cardHeight = DeviceHelper.cardHeight(for: geo)
        
        // Calculate total width to ensure it fits
        let spacing: CGFloat = 6
        let totalWidth = (cardWidth * 5) + (spacing * 4)
        let scale = totalWidth > geo.size.width * 0.8 ? (geo.size.width * 0.8) / totalWidth : 1.0
        
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
        .scaleEffect(scale)
    }
    
    // MARK: - 8-Player Oval Layout
    
    /// Layout 8 players around an oval table
    /// Seat 0 (Hero): bottom center
    /// Seats 1-7: clockwise around the oval
    private func playerOvalLayout(geo: GeometryProxy) -> some View {
        let w = geo.size.width
        let h = geo.size.height
        
        // Adjust layout to pull Hero up and avoid overlap with bottom controls
        let centerX = w / 2
        let centerY = h * 0.38  // Moved up from 0.42
        let radiusX = w * 0.40  // Slightly narrower
        let radiusY = h * 0.26  // Reduced from 0.30 to pull bottom player up
        
        // Seat positions as angles (starting from bottom, going clockwise)
        // Seat 0: 270° (bottom), Seat 1: 225° (bottom-left), ...
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
                let x = centerX + radiusX * cos(angle)
                let y = centerY - radiusY * sin(angle)
                let isShowdown = store.state == .showdown
                
                if i == 0 {
                    // Hero - slightly larger, always shows cards
                    let isActiveInPlay = store.engine.activePlayerIndex == i
                        && (store.state == .waitingForAction || store.state == .betting)
                    PlayerView(
                        player: store.engine.players[i],
                        isActive: isActiveInPlay,
                        isDealer: store.engine.dealerIndex == i,
                        showCards: true,
                        compact: false,
                        gameMode: store.engine.gameMode
                    )
                    .position(x: x, y: y) // Removed +15 offset to keep it higher
                    .zIndex(100) // Ensure Hero is always on top
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
                    .zIndex(Double(10 - i)) // Lower z-index for background players
                }
            }
        }
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
