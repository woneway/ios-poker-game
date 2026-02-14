import SwiftUI

struct GameHeroControls: View {
    @ObservedObject var store: PokerGameStore
    @ObservedObject var settings: GameSettings
    @Binding var showRaisePanel: Bool
    @Binding var raiseSliderValue: Double
    @Binding var showRankings: Bool
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let heroIndex = store.engine.players.firstIndex(where: { $0.isHuman }) ?? 0
        let hero = store.engine.players.count > heroIndex ? store.engine.players[heroIndex] : nil
        
        switch store.state {
        case .idle:
            Button(action: { store.send(.start) }) {
                Text("发牌")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.adaptiveButtonPrimary(colorScheme)))
                    .shadow(color: .blue.opacity(0.4), radius: 6, y: 3)
            }
            .padding(.horizontal, 40)
            
        case .dealing:
            Text("发牌中...")
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
                                Text("🏆 你赢了!")
                                    .font(.system(size: 22, weight: .black))
                                    .foregroundColor(.yellow)
                            } else {
                                Text("🏆 \(winner.name) 获胜!")
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Button(action: { showRankings = true }) {
                            Text("查看最终排名")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.yellow)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Color.black.opacity(0.6)))
                                .overlay(Capsule().stroke(Color.yellow.opacity(0.5), lineWidth: 1))
                        }
                        .padding(.horizontal, 40)
                        
                        Button(action: {
                            store.resetGame(
                                mode: settings.gameMode,
                                config: settings.getTournamentConfig()
                            )
                        }) {
                            Text("新游戏")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.adaptiveButtonPrimary(colorScheme)))
                        }
                        .padding(.horizontal, 60)
                    }
                } else if let hero = hero, hero.chips <= 0 {
                    // Hero eliminated but game continues
                    VStack(spacing: 6) {
                        Text("你被淘汰了!")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(.red)
                        
                        Text("排名第 \(eliminatedRank) / 8")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        
                        HStack(spacing: 12) {
                            Button(action: { store.send(.nextHand) }) {
                                Text("观战")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 100, height: 40)
                                    .background(Capsule().fill(Color.gray))
                            }
                            Button(action: {
                                store.resetGame(
                                    mode: settings.gameMode,
                                    config: settings.getTournamentConfig()
                                )
                            }) {
                                Text("新游戏")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 100, height: 40)
                                    .background(Capsule().fill(Color.adaptiveButtonPrimary(colorScheme)))
                            }
                        }
                    }
                } else {
                    // Hero alive, continue
                    Button(action: { store.send(.nextHand) }) {
                        Text("下一手")
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
                        ActionButton(title: "Fold", color: Color.adaptiveButtonDanger(colorScheme)) {
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
                    Text("等待中...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
        case .betting:
            HStack(spacing: 4) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.7)
                Text("AI 思考中...")
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
            // Only show Min if it's valid (less than Max)
            if minRaiseTo < maxRaiseTo {
                list.append(("Min", minRaiseTo))
            }
            
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
            // If maxRaiseTo < minRaiseTo, user can only All-In, so show that amount
            let displayAmount = minRaiseTo > maxRaiseTo ? maxRaiseTo : currentRaiseTo
            Text(minRaiseTo > maxRaiseTo ? "全下 $\(displayAmount)" : "加注至 $\(displayAmount)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.yellow)
            
            // Slider
            // Only show slider if we have a range to slide
            if minRaiseTo < maxRaiseTo {
                HStack(spacing: 8) {
                    Text("$\(minRaiseTo)")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    
                    // Ensure step is valid (<= 1.0) and non-zero
                    let step = min(1.0, max(0.0001, Double(bb) / Double(max(1, range))))
                    Slider(value: $raiseSliderValue, in: 0...1, step: step)
                        .accentColor(.orange)
                    
                    Text("$\(maxRaiseTo)")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 10)
            } else {
                // Placeholder to keep layout consistent
                Text("筹码不足以进行最小加注，只能全压")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.vertical, 10)
            }
            
            // Preset buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(presets, id: \.0) { preset in
                        Button(action: {
                            if range > 0 {
                                let normalizedValue = Double(preset.1 - minRaiseTo) / Double(max(1, range))
                                raiseSliderValue = min(1.0, max(0.0, normalizedValue))
                            }
                        }) {
                            Text(preset.0)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(
                                        // Highlight if matches current, OR if it's All-In and we are forced All-In
                                        (preset.1 == displayAmount) || (minRaiseTo > maxRaiseTo && preset.0 == "All In")
                                            ? Color.orange : Color.white.opacity(0.2)
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
                    Text("取消")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 38)
                        .background(Color.gray.opacity(0.5))
                        .cornerRadius(10)
                }
                
                Button(action: {
                    if currentRaiseTo >= maxRaiseTo || minRaiseTo > maxRaiseTo {
                        store.engine.processAction(.allIn)
                    } else {
                        store.engine.processAction(.raise(currentRaiseTo))
                    }
                    store.send(.playerActed)
                    if settings.soundEnabled { SoundManager.shared.playSound(.chip) }
                    showRaisePanel = false
                }) {
                    Text(minRaiseTo > maxRaiseTo || currentRaiseTo >= maxRaiseTo ? "全下 $\(maxRaiseTo)" : "加注 $\(currentRaiseTo)")
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
