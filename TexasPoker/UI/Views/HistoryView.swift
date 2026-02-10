import SwiftUI

struct HistoryView: View {
    @ObservedObject var historyManager = GameHistoryManager.shared
    @Binding var isPresented: Bool
    @State private var selectedRecord: GameRecord? = nil
    @State private var showClearConfirm: Bool = false
    
    var body: some View {
        NavigationView {
            Group {
                if historyManager.records.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("No games played yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Complete a game to see your history here")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.6))
                    }
                } else {
                    List {
                        ForEach(historyManager.records) { record in
                            Button(action: { selectedRecord = record }) {
                                historyRow(record)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Game History")
            .navigationBarItems(
                leading: historyManager.records.isEmpty ? nil : Button("Clear") {
                    showClearConfirm = true
                },
                trailing: Button("Done") {
                    isPresented = false
                }
            )
            .alert("确认清除", isPresented: $showClearConfirm) {
                Button("清除", role: .destructive) {
                    historyManager.clearHistory()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("确定要清除所有游戏历史记录吗？此操作不可恢复。")
            }
            .sheet(item: $selectedRecord) { record in
                historyDetail(record)
            }
        }
    }
    
    // MARK: - Row
    
    private func historyRow(_ record: GameRecord) -> some View {
        HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(heroRankColor(record.heroRank))
                    .frame(width: 42, height: 42)
                
                VStack(spacing: 0) {
                    Text("#\(record.heroRank)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("of \(record.totalPlayers)")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(dateFormatted(record.date))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Label("\(record.totalHands) hands", systemImage: "suit.spade.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Text(heroResultText(record))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(record.heroRank == 1 ? .green : .orange)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Detail
    
    private func historyDetail(_ record: GameRecord) -> some View {
        NavigationView {
            List {
                Section(header: Text("Game Info")) {
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(dateFormatted(record.date))
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Total Hands")
                        Spacer()
                        Text("\(record.totalHands)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Players")
                        Spacer()
                        Text("\(record.totalPlayers)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Your Rank")
                        Spacer()
                        Text("#\(record.heroRank) of \(record.totalPlayers)")
                            .foregroundColor(record.heroRank == 1 ? .green : .orange)
                            .fontWeight(.bold)
                    }
                }
                
                Section(header: Text("Final Standings")) {
                    ForEach(record.results) { result in
                        HStack(spacing: 10) {
                            Text(rankEmoji(result.rank))
                                .font(.system(size: 20))
                            
                            Text(result.avatar)
                                .font(.system(size: 18))
                            
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 4) {
                                    Text(result.name)
                                        .font(.system(size: 14, weight: result.isHuman ? .bold : .regular))
                                    if result.isHuman {
                                        Text("(You)")
                                            .font(.system(size: 11))
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                Text(result.rank == 1 ? "Winner" : "Out at Hand #\(result.handsPlayed)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("#\(result.rank)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(result.rank <= 3 ? .yellow : .secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Game Detail")
            .navigationBarItems(trailing: Button("Close") {
                selectedRecord = nil
            })
        }
    }
    
    // MARK: - Helpers
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()
    
    private func dateFormatted(_ date: Date) -> String {
        return Self.dateFormatter.string(from: date)
    }
    
    private func heroRankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .green
        case 2: return .yellow.opacity(0.8)
        case 3: return .orange
        default: return .gray
        }
    }
    
    private func heroResultText(_ record: GameRecord) -> String {
        if record.heroRank == 1 { return "Winner!" }
        return "Finished #\(record.heroRank)"
    }
    
    private func rankEmoji(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "  \(rank)."
        }
    }
}
