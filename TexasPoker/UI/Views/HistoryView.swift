import SwiftUI

struct HistoryView: View {
    @ObservedObject var historyManager = GameHistoryManager.shared
    @Binding var isPresented: Bool
    @State private var selectedRecord: GameRecord? = nil
    @State private var showClearConfirm: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0f0f23").ignoresSafeArea()
                Group {
                    if historyManager.records.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "clock.badge.questionmark")
                                .font(.system(size: 50))
                                .foregroundColor(.gray.opacity(0.4))
                            Text("暂无游戏记录")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text("完成游戏后即可在此查看历史记录")
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
                        .scrollContentBackground(.hidden)
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("游戏历史")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !historyManager.records.isEmpty {
                        Button("清除") {
                            showClearConfirm = true
                        }
                        .foregroundColor(.red)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                }
            }
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
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Row
    
    private func historyRow(_ record: GameRecord) -> some View {
        HStack(spacing: 12) {
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
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Label("\(record.totalHands) 手", systemImage: "suit.spade.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    
                    Text(heroResultText(record))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(record.heroRank == 1 ? .green : .orange)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(.vertical, 4)
        .listRowBackground(Color(hex: "1a1a2e"))
    }
    
    // MARK: - Detail

    private func historyDetail(_ record: GameRecord) -> some View {
        ZStack {
            Color(hex: "0f0f23").ignoresSafeArea()
            List {
                Section(header: Text("游戏信息")) {
                    HStack {
                        Text("日期")
                            .foregroundColor(.white)
                        Spacer()
                        Text(dateFormatted(record.date))
                            .foregroundColor(.gray)
                    }
                    .listRowBackground(Color(hex: "1a1a2e"))
                    HStack {
                        Text("总局数")
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(record.totalHands)")
                            .foregroundColor(.gray)
                    }
                    .listRowBackground(Color(hex: "1a1a2e"))
                    HStack {
                        Text("玩家数")
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(record.totalPlayers)")
                            .foregroundColor(.gray)
                    }
                    .listRowBackground(Color(hex: "1a1a2e"))
                    HStack {
                        Text("你的排名")
                            .foregroundColor(.white)
                        Spacer()
                        Text("#\(record.heroRank) / \(record.totalPlayers)")
                            .foregroundColor(record.heroRank == 1 ? .green : .orange)
                            .fontWeight(.bold)
                    }
                    .listRowBackground(Color(hex: "1a1a2e"))
                }

                Section(header: Text("最终排名")) {
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
                                            .foregroundColor(.white)
                                        if result.isHuman {
                                            Text("(You)")
                                                .font(.system(size: 11))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    
                                    Text(result.rank == 1 ? "获胜者" : "淘汰于第 \(result.handsPlayed) 手")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Text("#\(result.rank)")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(result.rank <= 3 ? .yellow : .gray)
                            }
                            .padding(.vertical, 2)
                            .listRowBackground(Color(hex: "1a1a2e"))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
            .navigationTitle("游戏详情")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        selectedRecord = nil
                    }
                }
            }
        .preferredColorScheme(.dark)
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
