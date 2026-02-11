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
                    onNewGame: { store.resetGame() }
                )
                .animation(.easeInOut(duration: 0.3), value: store.showRankings)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings, isPresented: $showSettings)
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
        }
        .onChange(of: store.state) { newState in
            if newState == .dealing {
                let activeSeats = store.engine.players.enumerated()
                    .filter { $0.element.status == .active || $0.element.status == .allIn }
                    .map { $0.offset }
                scene.playDealAnimation(activeSeatIndices: activeSeats)
            }
        }
        .onChange(of: store.engine.isHandOver) { isOver in
            if isOver && settings.soundEnabled { SoundManager.shared.playSound(.win) }
        }
    }
    
    // MARK: - Layout Functions
    
    private func portraitLayout(geo: GeometryProxy) -> some View {
        ZStack {
            // Background
            RadialGradient(
                gradient: Gradient(colors: [Color(hex: "1a5c1a"), Color(hex: "0d3d0d")]),
                center: .center,
                startRadius: 50,
                endRadius: max(geo.size.width, geo.size.height) * 0.6
            )
            .edgesIgnoringSafeArea(.all)
            
            // Table felt ellipse
            Ellipse()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color(hex: "1e6b1e"), Color(hex: "145214")]),
                        center: .center,
                        startRadius: 20,
                        endRadius: 200
                    )
                )
                .overlay(
                    Ellipse()
                        .strokeBorder(Color(hex: "8B4513").opacity(0.8), lineWidth: 6)
                )
                .frame(width: geo.size.width * 0.88, height: geo.size.height * 0.5)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
            
            // SpriteKit layer
            SpriteView(scene: scene, options: [.allowsTransparency])
                .edgesIgnoringSafeArea(.all)
            
            // HUD
            VStack(spacing: 0) {
                // Top bar
                topBar
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                
                // Main game area
                ZStack {
                    // 8-player oval layout
                    playerOvalLayout(geo: geo)
                    
                    // Community cards (center of table)
                    communityCardsView(geo: geo)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.38)
                    
                    // Tournament info bar (only visible in tournament mode)
                    if store.engine.gameMode == .tournament {
                        tournamentInfoBar
                            .position(x: geo.size.width / 2, y: geo.size.height * 0.22)
                    }
                    
                    // Pot display
                    potDisplay
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.30)
                    
                    // Action log (right side)
                    actionLogPanel
                        .frame(width: 130, height: geo.size.height * 0.30)
                        .position(x: geo.size.width - 72, y: geo.size.height * 0.42)
                }
                
                Spacer(minLength: 0)
                
                // Hero controls (bottom)
                heroControls
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }
    
    private func landscapeLayout(geo: GeometryProxy) -> some View {
        ZStack {
            // Background
            RadialGradient(
                gradient: Gradient(colors: [Color(hex: "1a5c1a"), Color(hex: "0d3d0d")]),
                center: .center,
                startRadius: 50,
                endRadius: max(geo.size.width, geo.size.height) * 0.6
            )
            .edgesIgnoringSafeArea(.all)
            
            HStack(spacing: 0) {
                // Left: Game area (75%)
                ZStack {
                    // Table felt ellipse (wider for landscape)
                    Ellipse()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [Color(hex: "1e6b1e"), Color(hex: "145214")]),
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
                        topBar
                            .padding(.horizontal, 12)
                        
                        Spacer()
                        
                        // Tournament info bar
                        if store.engine.gameMode == .tournament {
                            tournamentInfoBar
                                .padding(.horizontal, 20)
                        }
                        
                        Spacer()
                        
                        // Community cards (larger for iPad)
                        communityCardsView(geo: geo)
                            .scaleEffect(DeviceHelper.scaleFactor)
                        
                        Spacer()
                        
                        // Pot display
                        potDisplay
                        
                        Spacer()
                    }
                    
                    // 8-player oval layout
                    playerOvalLayout(geo: geo)
                }
                .frame(width: geo.size.width * 0.75)
                
                // Right: Controls (25%)
                VStack(spacing: 16) {
                    // Action log
                    actionLogPanel
                        .frame(height: geo.size.height * 0.4)
                    
                    Spacer()
                    
                    // Hero controls
                    heroControls
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
                .frame(width: geo.size.width * 0.25)
                .background(Color.black.opacity(0.3))
            }
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Text(streetName)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.4)))
            
            Spacer()
            
            Text("Hand #\(store.engine.handNumber)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    private var streetName: String {
        switch store.engine.currentStreet {
        case .preFlop: return "Pre-Flop"
        case .flop: return "Flop"
        case .turn: return "Turn"
        case .river: return "River"
        }
    }
    
    // MARK: - Pot Display
    
    private var potDisplay: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.yellow)
                Text("底池：$\(formattedPot)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.yellow)
            }
            
            // 只在 showdown 阶段且有边池时显示边池详情
            if store.state == .showdown && store.engine.pot.hasSidePots {
                let mainAmount = store.engine.pot.portions.first?.amount ?? 0
                Text("主池: $\(mainAmount)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.yellow.opacity(0.8))
                ForEach(Array(store.engine.pot.sidePots.enumerated()), id: \.offset) { idx, sidePot in
                    Text("边池\(idx + 1): $\(sidePot.amount)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.5))
        )
    }
    
    /// 格式化底池金额（千位逗号）
    private var formattedPot: String {
        let amount = store.engine.pot.total
        if amount >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        }
        return "\(amount)"
    }
    
    // MARK: - Tournament Info Bar
    
    private var tournamentInfoBar: some View {
        HStack(spacing: 12) {
            // Current blinds
            VStack(alignment: .leading, spacing: 2) {
                Text("Blinds")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(store.engine.smallBlindAmount)/\(store.engine.bigBlindAmount)")
                    .font(.system(size: 14, weight: .bold))
            }
            
            Divider()
                .frame(height: 30)
            
            // Level
            VStack(alignment: .leading, spacing: 2) {
                Text("Level")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(store.engine.currentBlindLevel + 1)")
                    .font(.system(size: 14, weight: .bold))
            }
            
            Divider()
                .frame(height: 30)
            
            // Hands until next level
            VStack(alignment: .leading, spacing: 2) {
                Text("Next in")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                let remaining = (store.engine.tournamentConfig?.handsPerLevel ?? 10) - store.engine.handsAtCurrentLevel
                Text("\(remaining) hands")
                    .font(.system(size: 14, weight: .bold))
            }
            
            if store.engine.anteAmount > 0 {
                Divider()
                    .frame(height: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ante")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(store.engine.anteAmount)")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
    
    // MARK: - Community Cards
    
    private func communityCardsView(geo: GeometryProxy) -> some View {
        let cardWidth = DeviceHelper.cardWidth(for: geo)
        let cardHeight = DeviceHelper.cardHeight(for: geo)
        
        return HStack(spacing: 4) {
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
        let centerX = w / 2
        let centerY = h * 0.42  // Slightly above vertical center
        let radiusX = w * 0.42
        let radiusY = h * 0.30
        
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
                    .position(x: x, y: y + 15)
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
                }
            }
        }
    }
    
    // MARK: - Action Log Panel
    
    private var actionLogPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
                Text("操作日志")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                if !store.engine.actionLog.isEmpty {
                    Text("\(store.engine.actionLog.count)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(0.15)))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.5))
            
            // Log entries (scrollable, most recent at bottom)
            if store.engine.actionLog.isEmpty {
                Spacer()
                Text("等待操作...")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(store.engine.actionLog) { entry in
                                actionLogRow(entry)
                                    .id(entry.id)
                            }
                        }
                    }
                    .onChange(of: store.engine.actionLog.count) { _ in
                        if let last = store.engine.actionLog.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .background(Color.black.opacity(0.35))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
    
    private func actionLogRow(_ entry: ActionLogEntry) -> some View {
        HStack(spacing: 4) {
            // Avatar
            Text(entry.avatar)
                .font(.system(size: 10))
            
            // Action icon with color
            Image(systemName: entry.iconName)
                .font(.system(size: 8))
                .foregroundColor(actionColor(entry))
            
            // Action text
            Text(entry.actionText)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(actionColor(entry))
                .lineLimit(1)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            actionColor(entry).opacity(0.08)
        )
    }
    
    private func actionColor(_ entry: ActionLogEntry) -> Color {
        switch entry.action {
        case .fold: return .gray
        case .check: return .green
        case .call: return Color(hex: "4A90D9")
        case .raise: return .orange
        case .allIn: return .red
        }
    }
    
    // MARK: - Hero Controls
    
    @ViewBuilder
    private var heroControls: some View {
        let heroIndex = store.engine.players.firstIndex(where: { $0.isHuman }) ?? 0
        let hero = store.engine.players.count > heroIndex ? store.engine.players[heroIndex] : nil
        
        switch store.state {
        case .idle:
            Button(action: { store.send(.start) }) {
                Text("DEAL HAND")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.blue))
                    .shadow(color: .blue.opacity(0.4), radius: 6, y: 3)
            }
            .padding(.horizontal, 40)
            
        case .dealing:
            Text("Dealing...")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
            
        case .showdown:
            VStack(spacing: 10) {
                // Hand result
                Text(store.engine.winMessage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.yellow)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                
                if store.isGameOver {
                    // Tournament ended - show rankings button
                    VStack(spacing: 8) {
                        if let winner = store.finalWinner {
                            if winner.isHuman {
                                Text("🏆 YOU WIN!")
                                    .font(.system(size: 22, weight: .black))
                                    .foregroundColor(.yellow)
                            } else {
                                Text("🏆 \(winner.name) Wins!")
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Button(action: { store.showRankings = true }) {
                            Text("View Final Standings")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.yellow)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Color.black.opacity(0.6)))
                                .overlay(Capsule().stroke(Color.yellow.opacity(0.5), lineWidth: 1))
                        }
                        .padding(.horizontal, 40)
                        
                        Button(action: { store.resetGame() }) {
                            Text("New Game")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.blue))
                        }
                        .padding(.horizontal, 60)
                    }
                } else if let hero = hero, hero.chips <= 0 {
                    // Hero eliminated but game continues
                    VStack(spacing: 6) {
                        Text("YOU'RE OUT!")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(.red)
                        
                        Text("Finished \(eliminatedRank)th of 8")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        
                        HStack(spacing: 12) {
                            Button(action: { store.send(.nextHand) }) {
                                Text("Watch")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 100, height: 40)
                                    .background(Capsule().fill(Color.gray))
                            }
                            Button(action: { store.resetGame() }) {
                                Text("New Game")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 100, height: 40)
                                    .background(Capsule().fill(Color.blue))
                            }
                        }
                    }
                } else {
                    // Hero alive, continue
                    Button(action: { store.send(.nextHand) }) {
                        Text("Next Hand")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color.green))
                    }
                    .padding(.horizontal, 60)
                }
            }
            
        case .waitingForAction:
            if let hero = hero,
               store.engine.activePlayerIndex == heroIndex,
               hero.status == .active {
                let callAmount = store.engine.currentBet - hero.currentBet
                let minRaiseTo = store.engine.currentBet + store.engine.minRaise
                let maxRaiseTo = hero.currentBet + hero.chips  // All-in amount
                
                if showRaisePanel {
                    // Raise selection panel
                    raisePanel(
                        hero: hero,
                        minRaiseTo: minRaiseTo,
                        maxRaiseTo: maxRaiseTo,
                        potSize: store.engine.pot.total
                    )
                } else {
                    // Main action buttons
                    HStack(spacing: 10) {
                        ActionButton(title: "Fold", color: .red) {
                            store.engine.processAction(.fold)
                            store.send(.playerActed)
                            if settings.soundEnabled { SoundManager.shared.playSound(.fold) }
                        }
                        
                        ActionButton(
                            title: callAmount == 0 ? "Check" : "Call $\(callAmount)",
                            color: .green
                        ) {
                            store.engine.processAction(callAmount == 0 ? .check : .call)
                            store.send(.playerActed)
                            if settings.soundEnabled { SoundManager.shared.playSound(.chip) }
                        }
                        
                        // Open raise panel
                        ActionButton(title: "Raise", color: .orange) {
                            raiseSliderValue = 0
                            showRaisePanel = true
                        }
                    }
                }
            } else {
                // Fallback: shouldn't normally happen in waitingForAction
                HStack(spacing: 4) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                    Text("Waiting...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
        case .betting:
            HStack(spacing: 4) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.7)
                Text("AI Thinking...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    /// Hero's finishing position (e.g. 5th of 8)
    private var eliminatedRank: Int {
        let alive = store.engine.players.filter { $0.chips > 0 }.count
        return alive + 1  // Hero is out, so rank = alive + 1
    }
    
    // MARK: - Raise Panel
    
    private func raisePanel(hero: Player, minRaiseTo: Int, maxRaiseTo: Int, potSize: Int) -> some View {
        let range = max(1, maxRaiseTo - minRaiseTo)
        let currentRaiseTo = minRaiseTo + Int(raiseSliderValue * Double(range))
        let bb = store.engine.bigBlindAmount
        
        // Preset amounts
        let presets: [(String, Int)] = {
            var list: [(String, Int)] = []
            list.append(("Min", minRaiseTo))
            
            let twoBB = store.engine.currentBet + bb * 2
            if twoBB > minRaiseTo && twoBB < maxRaiseTo {
                list.append(("2x", twoBB))
            }
            let threeBB = store.engine.currentBet + bb * 3
            if threeBB > minRaiseTo && threeBB < maxRaiseTo {
                list.append(("3x", threeBB))
            }
            let halfPot = store.engine.currentBet + max(1, potSize / 2)
            if halfPot > minRaiseTo && halfPot < maxRaiseTo {
                list.append(("1/2 Pot", halfPot))
            }
            let fullPot = store.engine.currentBet + potSize
            if fullPot > minRaiseTo && fullPot < maxRaiseTo {
                list.append(("Pot", fullPot))
            }
            list.append(("All In", maxRaiseTo))
            return list
        }()
        
        return VStack(spacing: 8) {
            // Current raise amount display
            Text("Raise to $\(currentRaiseTo)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.yellow)
            
            // Slider
            HStack(spacing: 8) {
                Text("$\(minRaiseTo)")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                
                Slider(value: $raiseSliderValue, in: 0...1, step: Double(bb) / Double(max(1, range)))
                    .accentColor(.orange)
                
                Text("$\(maxRaiseTo)")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 10)
            
            // Preset buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(presets, id: \.0) { preset in
                        Button(action: {
                            let normalizedValue = Double(preset.1 - minRaiseTo) / Double(max(1, range))
                            raiseSliderValue = min(1.0, max(0.0, normalizedValue))
                        }) {
                            Text(preset.0)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(
                                        preset.1 == currentRaiseTo ? Color.orange : Color.white.opacity(0.2)
                                    )
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            
            // Confirm / Cancel
            HStack(spacing: 12) {
                Button(action: {
                    showRaisePanel = false
                }) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 38)
                        .background(Color.gray.opacity(0.5))
                        .cornerRadius(10)
                }
                
                Button(action: {
                    if currentRaiseTo >= maxRaiseTo {
                        store.engine.processAction(.allIn)
                    } else {
                        store.engine.processAction(.raise(currentRaiseTo))
                    }
                    store.send(.playerActed)
                    if settings.soundEnabled { SoundManager.shared.playSound(.chip) }
                    showRaisePanel = false
                }) {
                    Text("Raise $\(currentRaiseTo)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(minWidth: 120, minHeight: 38)
                        .padding(.horizontal, 10)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.orange.opacity(0.8), Color.orange]),
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .cornerRadius(10)
                        .shadow(color: .orange.opacity(0.4), radius: 3, y: 2)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.75))
        .cornerRadius(14)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(minWidth: 60, minHeight: 40)
                .padding(.horizontal, 8)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [color.opacity(0.8), color]),
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .cornerRadius(10)
                .shadow(color: color.opacity(0.4), radius: 3, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
}
