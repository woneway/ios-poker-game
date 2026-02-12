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
        case easy = "Easy"
        case normal = "Normal"
        case hard = "Hard"
        case pro = "Pro"
        
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
                Section(header: Text("Profile")) {
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
                            Text("New Profile")
                        }
                    }
                }

                Section(header: Text("General")) {
                    VStack(alignment: .leading) {
                        Text("Game Speed: \(String(format: "%.1fx", settings.gameSpeed))")
                        Slider(value: $settings.gameSpeed, in: 0.5...3.0, step: 0.5)
                    }
                    
                    Picker("Difficulty", selection: $settings.difficulty) {
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
                
                Section(header: Text("Game Mode")) {
                    Picker("Mode", selection: $settings.gameMode) {
                        Text("Cash Game").tag(GameMode.cashGame)
                        Text("Tournament").tag(GameMode.tournament)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: settings.gameMode) {
                        // Trigger UI update when mode changes
                    }
                    
                    if settings.gameMode == .tournament {
                        Picker("Tournament Type", selection: $settings.tournamentPreset) {
                            Text("Turbo").tag("Turbo")
                            Text("Standard").tag("Standard")
                            Text("Deep Stack").tag("Deep Stack")
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        // Show preset details
                        if let config = settings.getTournamentConfig() {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Starting Chips: \(config.startingChips)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Hands per Level: \(config.handsPerLevel)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Payouts: Top \(config.payoutStructure.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                
                Section(header: Text("AI 难度")) {
                    Toggle("自动难度调整", isOn: $settings.autoDifficulty)
                        .onChange(of: settings.autoDifficulty) { _, newValue in
                            DecisionEngine.difficultyManager.isAutoDifficulty = newValue
                        }
                    
                    if !settings.autoDifficulty {
                        Picker("难度等级", selection: $settings.manualDifficulty) {
                            ForEach(DifficultyLevel.allCases, id: \.self) { level in
                                Text(level.description).tag(level)
                            }
                        }
                        .onChange(of: settings.manualDifficulty) { _, newValue in
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
                
                Section(header: Text("History & Stats")) {
                    Button(action: { showHistory = true }) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.blue)
                            Text("Game History")
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
                            Text("Player Statistics")
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
                            statBadge(title: "Games", value: "\(total)", color: .blue)
                            statBadge(title: "Wins", value: "\(wins)", color: .green)
                            statBadge(title: "Win %", value: "\(winPct)%", color: .orange)
                            statBadge(title: "Avg Rank", value: "#\(avgRank)", color: .purple)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("About")) {
                    Text("Texas Poker v1.1")
                    Text("Built with SwiftUI + SpriteKit")
                }
                
                if let onQuit = onQuit {
                    Section {
                        Button(action: {
                            onQuit()
                            isPresented = false
                        }) {
                            Text("Quit Current Game")
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                isPresented = false
            })
            .alert("New Profile", isPresented: $showNewProfileAlert) {
                TextField("Profile name", text: $newProfileName)
                Button("Create") {
                    _ = profiles.createProfile(name: newProfileName)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Statistics and history are isolated per profile.")
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
