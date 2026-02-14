import SwiftUI
import CoreData
import Combine

class GameSettings: ObservableObject {
    // Persistence keys
    private let gameSpeedKey = "gameSpeed"
    private let soundEnabledKey = "soundEnabled"
    private let difficultyKey = "difficulty"
    private let gameModeKey = "gameMode"
    private let tournamentPresetKey = "tournamentPreset"
    
    // Game speed
    @Published var gameSpeed: Double {
        didSet { UserDefaults.standard.set(gameSpeed, forKey: gameSpeedKey) }
    }
    
    // Sound
    @Published var soundEnabled: Bool {
        didSet { 
            UserDefaults.standard.set(soundEnabled, forKey: soundEnabledKey)
            SoundManager.shared.isMuted = !soundEnabled
        }
    }
    
    @Published var soundVolume: Double {
        didSet {
            SoundManager.shared.volume = Float(soundVolume)
        }
    }
    
    // Difficulty
    @Published var difficulty: Difficulty {
        didSet { UserDefaults.standard.set(difficulty.rawValue, forKey: difficultyKey) }
    }
    
    // Game mode
    @Published var gameMode: GameMode {
        didSet { UserDefaults.standard.set(gameMode.rawValue, forKey: gameModeKey) }
    }
    
    // Tournament preset
    @Published var tournamentPreset: String {
        didSet { UserDefaults.standard.set(tournamentPreset, forKey: tournamentPresetKey) }
    }
    
    // Dynamic difficulty
    @Published var autoDifficulty: Bool = true
    @Published var manualDifficulty: DifficultyLevel = .medium
    
    enum Difficulty: String, CaseIterable, Identifiable {
        case easy = "简单"
        case normal = "普通"
        case hard = "困难"
        case pro = "专业"
        
        var id: String { self.rawValue }
    }
    
    init() {
        let defaults = UserDefaults.standard
        
        // Load existing values or defaults
        self.gameSpeed = defaults.object(forKey: gameSpeedKey) as? Double ?? 1.0
        self.soundEnabled = defaults.object(forKey: soundEnabledKey) as? Bool ?? true
        self.soundVolume = Double(SoundManager.shared.volume)
        
        let diffRaw = defaults.string(forKey: difficultyKey) ?? "Normal"
        self.difficulty = Difficulty(rawValue: diffRaw) ?? .normal
        
        let modeRaw = defaults.string(forKey: gameModeKey) ?? GameMode.cashGame.rawValue
        self.gameMode = GameMode(rawValue: modeRaw) ?? .cashGame
        
        self.tournamentPreset = defaults.string(forKey: tournamentPresetKey) ?? "Standard"
    }
    
    /// Get the tournament config based on current preset selection
    func getTournamentConfig() -> TournamentConfig? {
        guard gameMode == .tournament else { return nil }
        switch tournamentPreset {
        case "Turbo":
            return .turbo
        case "Deep Stack":
            return .deepStack
        default:
            return .standard
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: GameSettings
    @Binding var isPresented: Bool
    var onQuit: (() -> Void)? = nil
    @State private var showHistory = false
    @State private var showStatistics = false
    @ObservedObject private var historyManager = GameHistoryManager.shared
    @ObservedObject private var profiles = ProfileManager.shared
    @State private var showNewProfileAlert = false
    @State private var newProfileName: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("档案")) {
                    Picker("Active Profile", selection: $profiles.currentProfileId) {
                        ForEach(profiles.profiles) { p in
                            Text(p.name).tag(p.id)
                        }
                    }

                    Button(action: {
                        newProfileName = ""
                        showNewProfileAlert = true
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(.blue)
                            Text("新建档案")
                        }
                    }
                }

                Section(header: Text("通用")) {
                    VStack(alignment: .leading) {
                        Text("Game Speed: \(String(format: "%.1fx", settings.gameSpeed))")
                        Slider(value: $settings.gameSpeed, in: 0.5...3.0, step: 0.5)
                    }
                    
                    Picker("难度", selection: $settings.difficulty) {
                        ForEach(GameSettings.Difficulty.allCases) { diff in
                            Text(diff.rawValue).tag(diff)
                        }
                    }
                }
                
                Section(header: Text("音效设置")) {
                    Toggle("音效", isOn: $settings.soundEnabled)
                    
                    if settings.soundEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("音量")
                                Spacer()
                                Text("\(Int(settings.soundVolume * 100))%")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $settings.soundVolume, in: 0...1, step: 0.1)
                        }
                    }
                }
                
                Section(header: Text("游戏模式")) {
                    Picker("模式", selection: $settings.gameMode) {
                        Text("现金局").tag(GameMode.cashGame)
                        Text("锦标赛").tag(GameMode.tournament)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if settings.gameMode == .tournament {
                        Picker("锦标赛类型", selection: $settings.tournamentPreset) {
                            Text("Turbo").tag("Turbo")
                            Text("标准").tag("Standard")
                            Text("深筹赛").tag("Deep Stack")
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        // Show preset details
                        if let config = settings.getTournamentConfig() {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("起始筹码: \(config.startingChips)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("每级别手牌数: \(config.handsPerLevel)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("奖励圈: 前 \(config.payoutStructure.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                
                Section(header: Text("AI 难度")) {
                    Toggle("自动难度调整", isOn: $settings.autoDifficulty)
                        .onChangeCompat(of: settings.autoDifficulty) { newValue in
                            DecisionEngine.difficultyManager.isAutoDifficulty = newValue
                        }
                    
                    if !settings.autoDifficulty {
                        Picker("难度等级", selection: $settings.manualDifficulty) {
                            ForEach(DifficultyLevel.allCases, id: \.self) { level in
                                Text(level.description).tag(level)
                            }
                        }
                        .onChangeCompat(of: settings.manualDifficulty) { newValue in
                            DecisionEngine.difficultyManager.currentDifficulty = newValue
                        }
                    }
                    
                    if settings.autoDifficulty {
                        HStack {
                            Text("当前难度")
                            Spacer()
                            Text(DecisionEngine.difficultyManager.currentDifficulty.description)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("你的胜率")
                            Spacer()
                            let winRate = DecisionEngine.difficultyManager.heroWinRate
                            Text(String(format: "%.1f%%", winRate * 100))
                                .foregroundColor(winRate > 0.55 ? .green : (winRate < 0.45 ? .red : .orange))
                        }
                    }
                }
                
                Section(header: Text("历史与统计")) {
                    Button(action: { showHistory = true }) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.blue)
                            Text("游戏历史")
                                .foregroundColor(.primary)
                            Spacer()
                            
                            if !historyManager.records.isEmpty {
                                Text("\(historyManager.records.count) games")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                    }
                    
                    Button(action: { showStatistics = true }) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.green)
                            Text("玩家统计")
                                .foregroundColor(.primary)
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                    }
                    
                    if !historyManager.records.isEmpty {
                        // Quick stats
                        let wins = historyManager.records.filter { $0.heroRank == 1 }.count
                        let total = historyManager.records.count
                        let winPct = total > 0 ? Int(round(Double(wins) * 100.0 / Double(total))) : 0
                        let avgRank = total > 0 ? Int(round(Double(historyManager.records.map { $0.heroRank }.reduce(0, +)) / Double(total))) : 0
                        
                        HStack {
                            statBadge(title: "总局数", value: "\(total)", color: .blue)
                            statBadge(title: "获胜次数", value: "\(wins)", color: .green)
                            statBadge(title: "胜率", value: "\(winPct)%", color: .orange)
                            statBadge(title: "平均排名", value: "#\(avgRank)", color: .purple)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("About")) {
                    Text("德州扑克 v1.1")
                    Text("基于 SwiftUI + SpriteKit")
                }
                
                if let onQuit = onQuit {
                    Section {
                        Button(action: {
                            onQuit()
                            isPresented = false
                        }) {
                            Text("退出当前游戏")
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarItems(trailing: Button("完成") {
                isPresented = false
            })
            .alert("新建档案", isPresented: $showNewProfileAlert) {
                TextField("档案名称", text: $newProfileName)
                Button("创建") {
                    _ = profiles.createProfile(name: newProfileName)
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("统计数据和游戏记录将按档案隔离保存。")
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(isPresented: $showHistory)
            }
            .sheet(isPresented: $showStatistics) {
                StatisticsView()
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            }
        }
    }
    
    private func statBadge(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
