import SwiftUI
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
        didSet { UserDefaults.standard.set(soundEnabled, forKey: soundEnabledKey) }
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
    @State private var showHistory = false
    @ObservedObject private var historyManager = GameHistoryManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("General")) {
                    Toggle("Sound Effects", isOn: $settings.soundEnabled)
                    
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
                
                Section(header: Text("Game Mode")) {
                    Picker("Mode", selection: $settings.gameMode) {
                        Text("Cash Game").tag(GameMode.cashGame)
                        Text("Tournament").tag(GameMode.tournament)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: settings.gameMode) { _ in
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
                
                Section(header: Text("History")) {
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
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                isPresented = false
            })
            .sheet(isPresented: $showHistory) {
                HistoryView(isPresented: $showHistory)
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
