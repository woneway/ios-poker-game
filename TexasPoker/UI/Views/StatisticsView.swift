import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct StatisticsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var profiles = ProfileManager.shared
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PlayerStatsEntity.totalHands, ascending: false)],
        animation: .default
    ) private var playerStats: FetchedResults<PlayerStatsEntity>
    
    @State private var selectedMode: GameMode = .cashGame
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    
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
                    let profileId = profiles.currentProfileIdForData
                    let filteredStats = playerStats.filter {
                        $0.gameMode == selectedMode.rawValue && matchesProfile($0, profileId: profileId)
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: exportStatistics) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }

    private func matchesProfile(_ stats: PlayerStatsEntity, profileId: String) -> Bool {
        // Default profile is backward compatible: treat nil as default
        if profileId == ProfileManager.defaultProfileId {
            return stats.profileId == nil || stats.profileId == ProfileManager.defaultProfileId
        }
        return stats.profileId == profileId
    }
    
    // MARK: - Export Statistics
    
    private func exportStatistics() {
        if let url = DataExporter.exportStatistics(gameMode: selectedMode) {
            exportURL = url
            showExportSheet = true
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct PlayerStatsRow: View {
    let statsEntity: PlayerStatsEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(statsEntity.playerName ?? "Unknown")
                    .font(.headline)
                Spacer()
                Text("$\(statsEntity.totalWinnings)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(statsEntity.totalWinnings >= 0 ? .green : .red)
            }
            
            HStack(spacing: 12) {
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
                StatBadge(
                    label: "W$SD",
                    value: "\(Int(statsEntity.wsd))%",
                    color: .purple
                )
            }
            
            HStack(spacing: 12) {
                Text("\(statsEntity.totalHands) hands")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(statsEntity.handsWon) wins")
                    .font(.caption)
                    .foregroundColor(.secondary)
                let winRate = statsEntity.totalHands > 0 
                    ? Double(statsEntity.handsWon) / Double(statsEntity.totalHands) * 100 
                    : 0.0
                Text(String(format: "%.1f%% win rate", winRate))
                    .font(.caption)
                    .foregroundColor(.cyan)
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
