import SwiftUI
import Combine

class GameSettings: ObservableObject {
    @Published var gameSpeed: Double {
        didSet { UserDefaults.standard.set(gameSpeed, forKey: "gameSpeed") }
    }
    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }
    @Published var difficulty: Difficulty {
        didSet { UserDefaults.standard.set(difficulty.rawValue, forKey: "difficulty") }
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
        self.gameSpeed = defaults.object(forKey: "gameSpeed") as? Double ?? 1.0
        self.soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? true
        let diffRaw = defaults.string(forKey: "difficulty") ?? "Normal"
        self.difficulty = Difficulty(rawValue: diffRaw) ?? .normal
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
                Section(header: Text("Game Options")) {
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
