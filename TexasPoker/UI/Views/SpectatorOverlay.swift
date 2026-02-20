import SwiftUI

/// 观战模式覆盖层 — 显示 AI 对局进度、速度控制、暂停/退出
struct SpectatorOverlay: View {
    @ObservedObject var store: PokerGameStore
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "eye.fill")
                        .foregroundColor(.purple)
                    Text("观战模式")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("第 \(store.spectateHandCount) 手")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Last hand result
                if !store.lastSpectateWinner.isEmpty {
                    HStack {
                        Text("🏆 \(store.lastSpectateWinner)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.yellow)
                        if store.lastSpectateWinAmount > 0 {
                            Text("+$\(store.lastSpectateWinAmount)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green)
                        }
                        Spacer()
                    }
                }
                
                // Player chips overview
                chipsBarsView
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                // Speed control
                HStack {
                    Text("速度")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Picker("", selection: $store.spectateSpeed) {
                        ForEach(PokerGameStore.SpectateSpeed.allCases) { speed in
                            Text(speed.displayName).tag(speed)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Control buttons
                HStack(spacing: 16) {
                    // Pause / Resume
                    Button(action: {
                        if store.spectatePaused {
                            store.send(.resumeSpectating)
                        } else {
                            store.send(.pauseSpectating)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: store.spectatePaused ? "play.fill" : "pause.fill")
                            Text(store.spectatePaused ? "继续" : "暂停")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(store.spectatePaused ? Color.green.opacity(0.8) : Color.orange.opacity(0.8)))
                    }
                    
                    // Exit
                    Button(action: {
                        store.send(.stopSpectating)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("退出观战")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.red.opacity(0.7)))
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.85))
                    .shadow(color: .black.opacity(0.5), radius: 10, y: -5)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Chips Bars

    private var chipsBarsView: some View {
        let alivePlayers = store.engine.players.filter { $0.chips > 0 }
        let maxChips = alivePlayers.map(\.chips).max() ?? 1
        
        return VStack(spacing: 4) {
            ForEach(store.engine.players.indices, id: \.self) { i in
                let player = store.engine.players[i]
                if player.chips > 0 {
                    // 存活玩家显示筹码条
                    HStack(spacing: 6) {
                        Text(player.aiProfile?.avatar ?? (player.isHuman ? "🧑" : "🤖"))
                            .font(.system(size: 12))
                        
                        Text(player.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(player.isHuman ? .yellow : .white.opacity(0.8))
                            .frame(width: 60, alignment: .leading)
                            .lineLimit(1)
                        
                        GeometryReader { geo in
                            let ratio = CGFloat(player.chips) / CGFloat(max(1, maxChips))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(player.isHuman ? Color.yellow.opacity(0.7) : Color.green.opacity(0.6))
                                .frame(width: geo.size.width * ratio)
                        }
                        .frame(height: 8)
                        
                        Text("$\(player.chips)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 50, alignment: .trailing)
                    }
                } else {
                    // 已淘汰玩家显示为空座位占位符
                    HStack(spacing: 6) {
                        Text("💺")
                            .font(.system(size: 12))
                            .opacity(0.5)
                        
                        Text("空座位")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.3))
                            .frame(width: 60, alignment: .leading)
                            .lineLimit(1)
                        
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 0)
                        }
                        .frame(height: 8)
                        
                        Text("淘汰")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.red.opacity(0.5))
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }
        }
    }
}
