import SwiftUI

/// Player list view showing all players with search and filter
struct PlayerListView: View {
    @StateObject private var viewModel = PlayerListViewModel()

    private var aiProfileNames: [String] {
        PlayerDataProvider.allAINames
    }

    var body: some View {
        ZStack {
            Color(hex: "0f0f23").ignoresSafeArea()
            VStack(spacing: 0) {
                Picker("模式", selection: $viewModel.selectedGameMode) {
                    Text("现金局").tag(GameMode.cashGame)
                    Text("锦标赛").tag(GameMode.tournament)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .onChange(of: viewModel.selectedGameMode) { _, _ in
                    Task {
                        await viewModel.loadData()
                    }
                }
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("搜索玩家名称", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.searchText = "" }) {
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
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                    Spacer()
                } else if viewModel.filteredPlayers.isEmpty {
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
                        ForEach(viewModel.filteredPlayers, id: \.playerName) { stats in
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
            Task {
                await viewModel.loadData()
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    NavigationStack {
        PlayerListView()
    }
}
