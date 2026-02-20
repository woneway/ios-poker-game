import SwiftUI
import CoreData

// MARK: - Optimized Settings View
struct SettingsView: View {
    @ObservedObject var settings: GameSettings
    @Binding var isPresented: Bool
    var onQuit: (() -> Void)? = nil
    
    @StateObject private var historyManager = GameHistoryManager.shared
    @StateObject private var profiles = ProfileManager.shared
    @StateObject private var statsManager = TournamentStatsManager.shared
    
    @State private var showHistory = false
    @State private var showStatistics = false
    @State private var showPlayerAnalysis = false
    @State private var showPlayerList = false
    @State private var showNewProfileAlert = false
    @State private var newProfileName = ""
    @State private var showResetConfirmation = false
    @State private var showTournamentSetup = false
    @State private var selectedTab: SettingsTab = .game
    @State private var showWeChatQR = false
    @State private var showDonateQR = false
    @State private var showDeleteProfileAlert = false
    @State private var profileToDelete: UserProfile?
    
    enum SettingsTab {
        case game, sound, statistics, about
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0f0f23").ignoresSafeArea()
                
                Form {
                    // Profile Section
                    profileSection
                    
                    // Game Settings Section
                    gameSettingsSection
                    
                    // Sound Settings Section
                    soundSettingsSection
                    
                    // AI Difficulty Section
                    difficultySection
                    
                    // Statistics Section
                    statisticsSection
                    
                    // About Section
                    aboutSection
                    
                    // Quit Button
                    quitSection
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .preferredColorScheme(.dark)
            .navigationTitle("游戏设置")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                }
            }
            .alert("新建档案", isPresented: $showNewProfileAlert) {
                TextField("档案名称", text: $newProfileName)
                Button("取消", role: .cancel) {}
                Button("创建") {
                    if !newProfileName.isEmpty {
                        _ = profiles.createProfile(name: newProfileName)
                    }
                }
            } message: {
                Text("创建新档案后，游戏数据和统计将独立保存。")
            }
            .alert("重置设置", isPresented: $showResetConfirmation) {
                Button("取消", role: .cancel) {}
                Button("重置", role: .destructive) {
                    settings.resetToDefaults()
                }
            } message: {
                Text("确定要将所有设置恢复为默认值吗？")
            }
            .alert("删除档案", isPresented: $showDeleteProfileAlert) {
                Button("取消", role: .cancel) {
                    profileToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let profile = profileToDelete {
                        profiles.deleteProfile(id: profile.id)
                    }
                    profileToDelete = nil
                }
            } message: {
                if let profile = profileToDelete {
                    Text("确定要删除档案「\(profile.name)」吗？\n此操作将永久删除该档案的所有游戏数据和统计数据，且不可恢复。")
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(isPresented: $showHistory)
            }
            .sheet(isPresented: $showStatistics) {
                EnhancedStatisticsView()
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            }
            .sheet(isPresented: $showPlayerAnalysis) {
                PlayerAnalysisView(hideBackButton: true)
            }
            .sheet(isPresented: $showPlayerList) {
                NavigationView {
                    PlayerListView()
                }
            }
            .sheet(isPresented: $showTournamentSetup) {
                TournamentSetupView { config, difficulty in
                    settings.gameMode = .tournament
                    settings.aiDifficulty = difficulty
                }
            }
            .sheet(isPresented: $showWeChatQR) {
                QRCodeSheetView(
                    title: "联系开发者",
                    subtitle: "微信号: VVE_1001",
                    imageName: "wechat_qr",
                    description: "扫一扫添加好友，交流游戏心得",
                    accentColor: .green
                )
            }
            .sheet(isPresented: $showDonateQR) {
                QRCodeSheetView(
                    title: "赞赏支持",
                    subtitle: nil,
                    imageName: "donate_qr",
                    description: "觉得好玩？给开发者 All-in 一杯咖啡吧！\n你的每一份支持，都是下一次更新的筹码。",
                    accentColor: .pink
                )
            }
        }
    }
    
    // MARK: - Profile Section
    private var profileSection: some View {
        Section {
            Picker("当前档案", selection: $profiles.currentProfileId) {
                ForEach(profiles.profiles) { profile in
                    HStack {
                        Text(profile.name)
                        if profile.id == ProfileManager.defaultProfileId {
                            Text("(默认)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(profile.id)
                }
            }

            Button(action: {
                newProfileName = ""
                showNewProfileAlert = true
            }) {
                HStack {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(.blue)
                    Text("新建档案")
                        .foregroundColor(.primary)
                }
            }

            // Delete profile button (only for non-default profiles)
            ForEach(profiles.profiles) { profile in
                if profile.id != ProfileManager.defaultProfileId {
                    Button(action: {
                        profileToDelete = profile
                        showDeleteProfileAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("删除「\(profile.name)」")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        } header: {
            Text("档案管理")
        } footer: {
            Text("不同档案的数据和统计相互独立")
                .font(.caption)
        }
    }
    
    // MARK: - Game Settings Section
    private var gameSettingsSection: some View {
        Section {
            // Game Speed
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("游戏速度")
                    Spacer()
                    Text(settings.gameSpeedDescription)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                
                Slider(
                    value: $settings.gameSpeed,
                    in: 0.5...3.0,
                    step: 0.5
                ) {
                    Text("游戏速度")
                } minimumValueLabel: {
                    Text("慢")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("快")
                        .font(.caption)
                }
            }
            .padding(.vertical, 4)
            
            // Game Mode
            Picker("游戏模式", selection: $settings.gameMode) {
                Text("现金局").tag(GameMode.cashGame)
                Text("锦标赛").tag(GameMode.tournament)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Tournament Settings
            if settings.gameMode == .tournament {
                tournamentSettings
            }
            
        } header: {
            Text("游戏设置")
        }
    }
    
    // MARK: - Tournament Settings
    private var tournamentSettings: some View {
        Group {
            Picker("锦标赛类型", selection: $settings.tournamentPreset) {
                ForEach(GameSettings.TournamentPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            
            if let config = settings.getTournamentConfig() {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("起始筹码: \(config.startingChips)", systemImage: "dollarsign.circle")
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    HStack {
                        Label("升级间隔: \(config.handsPerLevel) 手", systemImage: "clock")
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    HStack {
                        Label("奖励圈: 前 \(config.payoutStructure.count) 名", systemImage: "trophy")
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Sound Settings Section
    private var soundSettingsSection: some View {
        Section {
            Toggle(isOn: $settings.soundEnabled) {
                HStack {
                    Image(systemName: settings.soundEnabled ? "speaker.wave.3" : "speaker.slash")
                        .foregroundColor(settings.soundEnabled ? .blue : .gray)
                    Text("启用音效")
                }
            }
            
            if settings.soundEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("音量")
                        Spacer()
                        Text(settings.volumePercentage)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    
                    Slider(
                        value: $settings.soundVolume,
                        in: 0...1,
                        step: 0.1
                    ) {
                        Text("音量")
                    } minimumValueLabel: {
                        Image(systemName: "speaker")
                            .font(.caption)
                    } maximumValueLabel: {
                        Image(systemName: "speaker.wave.3")
                            .font(.caption)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("音效设置")
        }
    }
    
    // MARK: - Difficulty Section
    private var difficultySection: some View {
        Section {
            Picker("AI 难度", selection: $settings.aiDifficulty) {
                ForEach(AIProfile.Difficulty.allCases) { difficulty in
                    HStack {
                        Text(difficulty.rawValue)
                        Text(difficulty.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(difficulty)
                }
            }
            
            Toggle(isOn: $settings.useRandomOpponents) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("随机对手")
                    Text("每局随机选择不同类型的 AI 对手")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !settings.useRandomOpponents {
                NavigationLink(destination: OpponentSelectorView(settings: settings)) {
                    HStack {
                        Text("自选对手")
                        Spacer()
                        Text("7 个对手")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
        } header: {
            Text("难度设置")
        } footer: {
            Text(settings.aiDifficulty.recommendedFor)
                .font(.caption)
        }
    }
    
    // MARK: - Statistics Section
    private var statisticsSection: some View {
        Section {
            // Game History
            Button(action: { showHistory = true }) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.blue)
                    Text("游戏历史")
                    Spacer()
                    
                    if !historyManager.records.isEmpty {
                        Text("\(historyManager.records.count) 局")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            
            // Player Statistics
            Button(action: { showStatistics = true }) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.green)
                    Text("数据统计")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            
            // Player Analysis
            Button(action: { showPlayerAnalysis = true }) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.purple)
                    Text("玩家分析")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            
            // Player List
            Button(action: { showPlayerList = true }) {
                HStack {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.orange)
                    Text("对手列表")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            
            // Quick Stats Summary
            if !historyManager.records.isEmpty {
                QuickStatsView(historyManager: historyManager)
            }
            
        } header: {
            Text("历史与统计")
        }
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
        Section {
            HStack {
                Text("版本")
                Spacer()
                Text("1.2.0")
                    .foregroundColor(.secondary)
            }
            
            Button(action: { showWeChatQR = true }) {
                HStack {
                    Image(systemName: "message.fill")
                        .foregroundColor(.green)
                    Text("联系开发者")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("微信: VVE_1001")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Image(systemName: "qrcode")
                        .foregroundColor(.secondary.opacity(0.5))
                        .font(.caption)
                }
            }
            
            Button(action: { showDonateQR = true }) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.pink)
                    Text("赞赏支持")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "qrcode")
                        .foregroundColor(.secondary.opacity(0.5))
                        .font(.caption)
                }
            }
            
            Button(action: { showResetConfirmation = true }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.orange)
                    Text("恢复默认设置")
                        .foregroundColor(.orange)
                }
            }
            
        } header: {
            Text("关于")
        } footer: {
            Text("独立开发不易，你的支持是持续更新的最大动力")
                .font(.caption)
        }
    }
    
    // MARK: - Quit Section
    private var quitSection: some View {
        Group {
            if let onQuit = onQuit {
                Section {
                    Button(action: {
                        onQuit()
                        isPresented = false
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "xmark.circle")
                            Text("退出当前游戏")
                            Spacer()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

// MARK: - Quick Stats View
struct QuickStatsView: View {
    @ObservedObject var historyManager: GameHistoryManager
    
    var body: some View {
        let stats = calculateStats()
        
        HStack(spacing: 12) {
            QuickStatBadge(title: "总局数", value: "\(stats.total)", color: .blue, icon: "number")
            QuickStatBadge(title: "冠军", value: "\(stats.wins)", color: .yellow, icon: "crown")
            QuickStatBadge(title: "胜率", value: "\(stats.winRate)%", color: .green, icon: "percent")
            QuickStatBadge(title: "均名", value: "#\(stats.avgRank)", color: .purple, icon: "list.number")
        }
        .padding(.vertical, 8)
    }
    
    private func calculateStats() -> (total: Int, wins: Int, winRate: Int, avgRank: Int) {
        let total = historyManager.records.count
        guard total > 0 else { return (0, 0, 0, 0) }
        
        let wins = historyManager.records.filter { $0.heroRank == 1 }.count
        let winRate = Int(round(Double(wins) * 100.0 / Double(total)))
        let avgRank = Int(round(Double(historyManager.records.map { $0.heroRank }.reduce(0, +)) / Double(total)))
        
        return (total, wins, winRate, avgRank)
    }
}

// MARK: - Stat Badge
struct QuickStatBadge: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Opponent Selector View
struct OpponentSelectorView: View {
    @ObservedObject var settings: GameSettings
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedOpponents: [AIProfile] = []
    
    var body: some View {
        List {
            Section(header: Text("选择对手类型")) {
                ForEach(AIProfile.allProfiles, id: \.name) { profile in
                    OpponentRow(
                        profile: profile,
                        isSelected: selectedOpponents.contains(where: { $0.name == profile.name })
                    ) {
                        toggleOpponent(profile)
                    }
                }
            }
            
            Section {
                Text("已选择 \(selectedOpponents.count)/7 个对手")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("自选对手")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") {
                    dismiss()
                }
                .disabled(selectedOpponents.count != 7)
            }
        }
        .onAppear {
            // Initialize with random opponents if empty
            if selectedOpponents.isEmpty {
                selectedOpponents = settings.aiDifficulty.randomOpponents(count: 7)
            }
        }
    }
    
    private func toggleOpponent(_ profile: AIProfile) {
        if let index = selectedOpponents.firstIndex(where: { $0.name == profile.name }) {
            selectedOpponents.remove(at: index)
        } else if selectedOpponents.count < 7 {
            selectedOpponents.append(profile)
        }
    }
}

// MARK: - Opponent Row
struct OpponentRow: View {
    let profile: AIProfile
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(profile.avatar)
                    .font(.system(size: 32))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(profile.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 22))
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary.opacity(0.3))
                        .font(.system(size: 22))
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - QR Code Sheet View
struct QRCodeSheetView: View {
    let title: String
    let subtitle: String?
    let imageName: String
    let description: String
    let accentColor: Color
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                // Title
                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2.bold())
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // QR Code Image
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280, maxHeight: 280)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                
                // Description
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Spacer()
                
                // Close Button
                Button(action: { dismiss() }) {
                    Text("关闭")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(accentColor)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - AIProfile Extension for Settings
extension AIProfile.Difficulty {
    var recommendedFor: String {
        switch self {
        case .easy:
            return "推荐：刚接触德州扑克的新手玩家"
        case .normal:
            return "推荐：有一定经验的休闲玩家"
        case .hard:
            return "推荐：熟悉基本策略的玩家"
        case .expert:
            return "推荐：追求挑战的资深玩家"
        }
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            settings: GameSettings(),
            isPresented: .constant(true)
        )
    }
}
