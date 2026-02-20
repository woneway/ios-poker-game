import SwiftUI

/// Player list view showing all players with search and filter
struct PlayerListView: View {
    @State private var selectedMode: GameMode = .cashGame
    @State private var searchText: String = ""
    @State private var players: [PlayerStats] = []
    @State private var isLoading: Bool = false
    
    private let aiProfileNames = ["石头", "疯子麦克", "安娜", "老狐狸", "鲨鱼汤姆", "艾米", "大卫", "小鱼", "乌龟", "冷面杀手", "面具男", "富豪", "蜘蛛", "教授", "愤怒的小强", "金牌选手"]
    
    var filteredPlayers: [PlayerStats] {
        if searchText.isEmpty {
            return players
        }
        return players.filter { $0.playerName.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        ZStack {
            Color(hex: "0f0f23").ignoresSafeArea()
            VStack(spacing: 0) {
                // Mode picker
                Picker("模式", selection: $selectedMode) {
                    Text("现金局").tag(GameMode.cashGame)
                    Text("锦标赛").tag(GameMode.tournament)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .onChange(of: selectedMode) { _, _ in
                    loadPlayers()
                }
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("搜索玩家名称", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(Color(hex: "1a1a2e"))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                    Spacer()
                } else if filteredPlayers.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "person.3")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("暂无玩家数据")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("开始游戏后会显示对手数据")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.6))
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredPlayers, id: \.playerName) { stats in
                            NavigationLink(destination: PlayerDetailView(playerStats: stats)) {
                                PlayerListRowView(playerStats: stats)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .onAppear {
            loadPlayers()
        }
        .preferredColorScheme(.dark)
    }
    
    private func loadPlayers() {
        isLoading = true
        
        // Get all player names
        let playerNames = StatisticsCalculator.shared.fetchAllPlayerNames(gameMode: selectedMode)
        
        // Get stats for all players
        let statsDict = StatisticsCalculator.shared.fetchAllPlayersStats(gameMode: selectedMode)
        
        // Convert to array and sort by total hands (descending)
        let allStats = playerNames.compactMap { name -> PlayerStats? in
            statsDict[name]
        }.sorted { $0.totalHands > $1.totalHands }
        
        self.players = allStats
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        PlayerListView()
    }
}
