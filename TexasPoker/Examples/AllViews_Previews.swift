import SwiftUI

struct AllViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // ==================== 大厅视图 ====================
            LobbyView(settings: GameSettings())
                .previewDisplayName("1. 大厅 - LobbyView")
                .previewDevice("iPhone 15 Pro")
            
            // ==================== 设置视图 ====================
            SettingsView(settings: GameSettings(), isPresented: .constant(true))
                .previewDisplayName("2. 设置 - SettingsView")
                .previewDevice("iPhone 15 Pro")
            
            // ==================== 难度选择Chip ====================
            VStack(spacing: 20) {
                Text("难度筛选 Chips")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    ForEach(AIProfile.Difficulty.allCases) { difficulty in
                        DifficultyChip(
                            difficulty: difficulty,
                            isSelected: difficulty == .normal
                        ) { }
                    }
                }
                .padding()
                .background(Color(hex: "0f0f23"))
            }
            .previewDisplayName("3. 难度筛选 Chips")
            .previewDevice("iPhone 15 Pro")
            
            // ==================== 桌位卡片 ====================
            ScrollView {
                VStack(spacing: 16) {
                    Text("桌位卡片")
                        .font(.headline)
                    
                    // 模拟桌位数据
                    TableCard(
                        table: GameTable(
                            id: UUID(),
                            tableNumber: 1,
                            gameMode: .cashGame,
                            difficulty: .normal,
                            smallBlind: 5,
                            bigBlind: 10,
                            maxPlayers: 8,
                            currentPlayers: 6,
                            players: [
                                TablePlayer(id: UUID(), name: "Hero", avatar: "🎯", aiProfile: nil, chips: 1000, isHero: true),
                                TablePlayer(id: UUID(), name: "鲨鱼", avatar: "🦈", aiProfile: AIProfile.allProfiles[0], chips: 1500, isHero: false)
                            ],
                            buyInRange: 400...1000
                        ),
                        isSelected: false
                    ) { }
                    
                    TableCard(
                        table: GameTable(
                            id: UUID(),
                            tableNumber: 2,
                            gameMode: .tournament,
                            difficulty: .hard,
                            smallBlind: 25,
                            bigBlind: 50,
                            maxPlayers: 8,
                            currentPlayers: 8,
                            players: [],
                            buyInRange: 1000...5000
                        ),
                        isSelected: true
                    ) { }
                }
                .padding()
            }
            .background(Color(hex: "0f0f23"))
            .previewDisplayName("4. 桌位卡片 TableCard")
            .previewDevice("iPhone 15 Pro")
            
            // ==================== 空状态视图 ====================
            emptyStatePreview
                .previewDisplayName("5. 空状态视图")
                .previewDevice("iPhone 15 Pro")
            
            // ==================== 快速开始按钮 ====================
            VStack(spacing: 20) {
                Text("快速开始按钮")
                    .font(.headline)
                
                // 启用状态
                Button(action: {}) {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text("快速开始")
                        Text("普通")
                            .opacity(0.8)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // 禁用状态
                Button(action: {}) {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text("快速开始")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.gray)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(true)
                .opacity(0.5)
            }
            .padding()
            .background(Color(hex: "0f0f23"))
            .previewDisplayName("6. 快速开始按钮")
            .previewDevice("iPhone 15 Pro")
        }
    }
    
    static var emptyStatePreview: some View {
        ZStack {
            Color(hex: "0f0f23")
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "tray")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                
                Text("暂无符合条件的桌子")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("试试选择其他难度筛选")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 60)
        }
    }
}
