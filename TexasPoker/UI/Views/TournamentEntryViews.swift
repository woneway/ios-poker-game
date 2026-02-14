import SwiftUI

// MARK: - Tournament Entry Notification
/// Shows when a new player enters the tournament
struct TournamentEntryNotification: View {
    let player: Player
    let entryNumber: Int // Which entry this is (1st, 2nd, etc.)
    
    @State private var showAnimation = false
    @State private var offset: CGFloat = 100
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Text(player.aiProfile?.avatar ?? "🤖")
                .font(.system(size: 32))
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("新玩家入场!")
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text("#\(entryNumber)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(player.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    if let profile = player.aiProfile {
                        Text(profile.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Text("$\(player.chips)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                )
        )
        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
        .offset(y: offset)
        .opacity(showAnimation ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                offset = 0
                showAnimation = true
            }
            
            // Auto dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.3)) {
                    offset = -100
                    showAnimation = false
                }
            }
        }
    }
}

// MARK: - Tournament Info Panel
/// Enhanced tournament info with entry tracking
struct EnhancedTournamentInfo: View {
    @ObservedObject var store: PokerGameStore
    @State private var showNewEntry: Bool = false
    @State private var newEntryPlayer: Player?
    @State private var entryCount: Int = 0
    
    var body: some View {
        VStack(spacing: 8) {
            // Main info bar
            HStack(spacing: 16) {
                // Level
                VStack(alignment: .leading, spacing: 2) {
                    Text("Level \(store.engine.currentBlindLevel + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(blindDisplay)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Next level timer
                VStack(alignment: .trailing, spacing: 2) {
                    Text("升级倒计时")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(handsUntilLevelUp) 手")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.orange)
                }
                
                Divider()
                    .frame(height: 30)
                
                // Players remaining
                VStack(alignment: .trailing, spacing: 2) {
                    Text("剩余人数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(store.engine.players.count)/\(maxPlayers)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.cyan)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)
            
            // New entry notification
            if showNewEntry, let player = newEntryPlayer {
                TournamentEntryNotification(
                    player: player,
                    entryNumber: entryCount
                )
                .transition(.move(edge: .top))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TournamentNewEntry"))) { notification in
            if let player = notification.userInfo?["player"] as? Player {
                entryCount += 1
                newEntryPlayer = player
                withAnimation {
                    showNewEntry = true
                }
                
                // Auto hide
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation {
                        showNewEntry = false
                    }
                }
            }
        }
    }
    
    private var blindDisplay: String {
        let sb = store.engine.smallBlindAmount
        let bb = store.engine.bigBlindAmount
        let ante = store.engine.anteAmount
        
        if ante > 0 {
            return "\(sb)/\(bb) (\(ante))"
        }
        return "\(sb)/\(bb)"
    }
    
    private var handsUntilLevelUp: Int {
        guard let config = store.engine.tournamentConfig else { return 0 }
        return max(0, config.handsPerLevel - store.engine.handsAtCurrentLevel)
    }
    
    private var maxPlayers: Int {
        store.engine.tournamentConfig?.totalEntrants ?? 8
    }
}

// MARK: - Tournament Setup View
/// Setup view for tournament with difficulty selection
struct TournamentSetupView: View {
    @State private var selectedDifficulty: AIProfile.Difficulty = .normal
    @State private var startingChips: Double = 1000
    @State private var totalEntrants: Double = 64
    @State private var useRandomEntry: Bool = true
    
    @Environment(\.dismiss) var dismiss
    var onStart: (TournamentConfig, AIProfile.Difficulty) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                setupSection
                difficultyInfoSection
            }
            .navigationTitle("锦标赛设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始", action: startTournament)
                }
            }
        }
    }
    
    private var setupSection: some View {
        Section(header: Text("锦标赛设置")) {
            Picker("难度", selection: $selectedDifficulty) {
                ForEach(AIProfile.Difficulty.allCases) { difficulty in
                    Text(difficulty.rawValue).tag(difficulty)
                }
            }
            
            VStack(alignment: .leading) {
                Text("起始筹码: \(Int(startingChips))")
                Slider(value: $startingChips, in: 500...5000, step: 500)
            }
            
            VStack(alignment: .leading) {
                Text("总参赛人数: \(Int(totalEntrants))")
                Slider(value: $totalEntrants, in: 8...200, step: 8)
            }
            
            Toggle("允许中途入场", isOn: $useRandomEntry)
            
            if useRandomEntry {
                Text("新玩家会在锦标赛进行中随机加入")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var difficultyInfoSection: some View {
        Section(header: Text("难度说明")) {
            DifficultyInfoRow(
                difficulty: .easy,
                opponents: "新手鲍勃、玛丽、安娜、疯子麦克",
                description: "适合练习基础策略"
            )
            DifficultyInfoRow(
                difficulty: .normal,
                opponents: "石头、老狐狸、大卫",
                description: "平衡的游戏体验"
            )
            DifficultyInfoRow(
                difficulty: .hard,
                opponents: "鲨鱼汤姆、杰克、托尼、山姆",
                description: "需要扎实的扑克知识"
            )
            DifficultyInfoRow(
                difficulty: .expert,
                opponents: "艾米、皮特、维克多、史蒂夫",
                description: "地狱难度，GTO对抗"
            )
        }
    }
    
    private func startTournament() {
        let baseConfig = TournamentConfig.standard
        let config = TournamentConfig(
            name: baseConfig.name,
            startingChips: Int(startingChips),
            blindSchedule: baseConfig.blindSchedule,
            handsPerLevel: baseConfig.handsPerLevel,
            payoutStructure: baseConfig.payoutStructure
        )
        onStart(config, selectedDifficulty)
        dismiss()
    }
}

// MARK: - Difficulty Info Row
struct DifficultyInfoRow: View {
    let difficulty: AIProfile.Difficulty
    let opponents: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(difficulty.rawValue)
                .font(.system(size: 14, weight: .semibold))
            
            Text("对手: \(opponents)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
struct TournamentViews_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            TournamentEntryNotification(
                player: Player(
                    name: "新手鲍勃",
                    chips: 1500,
                    isHuman: false,
                    aiProfile: .newbieBob
                ),
                entryNumber: 3
            )
            .padding()
        }
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
