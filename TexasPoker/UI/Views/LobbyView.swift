import SwiftUI

struct LobbyView: View {
    @ObservedObject var settings: GameSettings
    @StateObject private var tableManager = TableManager.shared
    @State private var selectedTable: GameTable?
    @State private var showGameView = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0f0f23")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    gameModeSelector
                    difficultyFilter
                    tableList
                }
            }
            .navigationTitle("游戏大厅")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView(settings: settings, isPresented: .constant(true))) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.white)
                    }
                }
            }
            .fullScreenCover(isPresented: $showGameView) {
                if let table = selectedTable {
                    GameViewWithTable(settings: settings, table: table)
                }
            }
        }
    }
    
    private var gameModeSelector: some View {
        VStack(spacing: 12) {
            Picker("游戏模式", selection: $tableManager.selectedGameMode) {
                Text("现金局").tag(GameMode.cashGame)
                Text("锦标赛").tag(GameMode.tournament)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .onChange(of: tableManager.selectedGameMode) { _, _ in
                tableManager.regenerateWithFilter()
            }
        }
        .padding(.vertical)
    }
    
    private var difficultyFilter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("难度筛选")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AIProfile.Difficulty.allCases) { difficulty in
                        DifficultyChip(
                            difficulty: difficulty,
                            isSelected: tableManager.selectedDifficulty == difficulty
                        ) {
                            tableManager.selectedDifficulty = difficulty
                            tableManager.regenerateWithFilter()
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
    }
    
    private var tableList: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(tableManager.filteredTables()) { table in
                        TableCard(
                            table: table,
                            isSelected: selectedTable?.id == table.id
                        ) {
                            selectedTable = table
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            
            if selectedTable != nil {
                VStack {
                    Button(action: {
                        showGameView = true
                    }) {
                        Text("入桌")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom))
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color(hex: "0f0f23").opacity(0.9),
                            Color(hex: "0f0f23")
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 80)
                    .offset(y: 50)
                )
            }
        }
    }
}

struct DifficultyChip: View {
    let difficulty: AIProfile.Difficulty
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(difficulty.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: index <= difficultyRating ? "star.fill" : "star")
                            .font(.system(size: 8))
                            .foregroundColor(index <= difficultyRating ? .yellow : .gray.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var difficultyRating: Int {
        switch difficulty {
        case .easy: return 1
        case .normal: return 2
        case .hard: return 3
        case .expert: return 5
        }
    }
}

struct TableCard: View {
    let table: GameTable
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(table.tableName)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(table.gameMode == .cashGame ? "现金局" : "锦标赛")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(table.stakesText)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.yellow)
                        
                        Text("\(table.currentPlayers)/\(table.maxPlayers) 人")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                opponentList
                
                HStack {
                    Text(difficultyText)
                        .font(.caption)
                        .foregroundColor(.yellow)
                    
                    Spacer()
                    
                    if isSelected {
                        Text("已选择")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(isSelected ? 0.2 : 0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var opponentList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(table.players.filter { !$0.isHero }) { player in
                    VStack(spacing: 4) {
                        Text(player.avatar)
                            .font(.system(size: 24))
                        
                        Text(player.name)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .frame(width: 50)
                }
            }
        }
    }
    
    private var difficultyText: String {
        let stars = table.difficulty == .easy ? "★" :
                   table.difficulty == .normal ? "★★" :
                   table.difficulty == .hard ? "★★★" : "★★★★★"
        return "\(stars) \(table.difficulty.rawValue)"
    }
}

struct GameViewWithTable: View {
    @ObservedObject var settings: GameSettings
    let table: GameTable
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            GameView(
                settings: modifiedSettings,
                difficulty: table.difficulty,
                playerCount: table.currentPlayers
            )
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
    
    private var modifiedSettings: GameSettings {
        let newSettings = GameSettings()
        newSettings.gameMode = table.gameMode
        newSettings.aiDifficulty = table.difficulty
        
        if table.gameMode == .tournament {
            newSettings.tournamentPreset = .standard
        }
        
        return newSettings
    }
}

struct LobbyView_Previews: PreviewProvider {
    static var previews: some View {
        LobbyView(settings: GameSettings())
    }
}
