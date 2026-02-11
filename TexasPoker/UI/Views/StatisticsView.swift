import SwiftUI
import CoreData

struct StatisticsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PlayerStatsEntity.totalHands, ascending: false)],
        animation: .default
    ) private var playerStats: FetchedResults<PlayerStatsEntity>
    
    @State private var selectedMode: GameMode = .cashGame
    
    var body: some View {
        NavigationView {
            VStack {
                // Mode selector
                Picker("Mode", selection: $selectedMode) {
                    Text("Cash Game").tag(GameMode.cashGame)
                    Text("Tournament").tag(GameMode.tournament)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Stats list
                List {
                    let filteredStats = playerStats.filter { 
                        $0.gameMode == selectedMode.rawValue
                    }
                    
                    if filteredStats.isEmpty {
                        Text("No statistics available yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        // Hero section
                        if let heroStats = filteredStats.first(where: { 
                            $0.playerName == "Hero"
                        }) {
                            Section(header: Text("Hero")) {
                                PlayerStatsRow(statsEntity: heroStats)
                            }
                        }
                        
                        // AI opponents section
                        let aiStats = filteredStats.filter { 
                            $0.playerName != "Hero"
                        }
                        if !aiStats.isEmpty {
                            Section(header: Text("AI Opponents")) {
                                ForEach(aiStats, id: \.self) { stats in
                                    PlayerStatsRow(statsEntity: stats)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Statistics")
        }
    }
}

struct PlayerStatsRow: View {
    let statsEntity: PlayerStatsEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(statsEntity.playerName ?? "Unknown")
                .font(.headline)
            
            HStack(spacing: 16) {
                StatBadge(
                    label: "VPIP",
                    value: "\(Int(statsEntity.vpip))%",
                    color: .blue
                )
                StatBadge(
                    label: "PFR",
                    value: "\(Int(statsEntity.pfr))%",
                    color: .orange
                )
                StatBadge(
                    label: "AF",
                    value: String(format: "%.1f", statsEntity.af),
                    color: .red
                )
                StatBadge(
                    label: "WTSD",
                    value: "\(Int(statsEntity.wtsd))%",
                    color: .green
                )
            }
            
            HStack(spacing: 12) {
                Text("\(statsEntity.totalHands) hands")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(statsEntity.handsWon) wins")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatBadge: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}
