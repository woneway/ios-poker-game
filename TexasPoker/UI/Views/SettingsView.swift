import SwiftUI
import UIKit
import CoreData

struct SettingsView: View {
    @ObservedObject var settings: GameSettings
    @Binding var isPresented: Bool
    var onQuit: (() -> Void)? = nil
    
    @StateObject private var historyManager = GameHistoryManager.shared
    @StateObject private var profiles = ProfileManager.shared
    
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0f0f23")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    tabPicker
                    TabView(selection: $selectedTab) {
                        gameSettingsTab
                            .tag(0)
                        difficultyTab
                            .tag(1)
                        statisticsTab
                            .tag(2)
                        aboutTab
                            .tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("重置设置", isPresented: .init(
                get: { false },
                set: { if $0 { settings.resetToDefaults() } }
            )) {
                Button("取消", role: .cancel) {}
                Button("重置", role: .destructive) {
                    settings.resetToDefaults()
                }
            } message: {
                Text("确定要将所有设置恢复为默认值吗？")
            }
        }
    }
    
    private var navigationTitle: String {
        switch selectedTab {
        case 0: return "游戏设置"
        case 1: return "难度设置"
        case 2: return "数据统计"
        case 3: return "关于"
        default: return "设置"
        }
    }
    
    // MARK: - Tab Picker
    private var tabPicker: some View {
        HStack(spacing: 4) {
            tabButton(icon: "gamecontroller", title: "游戏", tag: 0)
            tabButton(icon: "brain.head.profile", title: "难度", tag: 1)
            tabButton(icon: "chart.bar", title: "统计", tag: 2)
            tabButton(icon: "info.circle", title: "关于", tag: 3)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(Color(hex: "1a1a2e"))
    }
    
    @State private var selectedTabScale: CGFloat = 1.0
    
    private func tabButton(icon: String, title: String, tag: Int) -> some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTabScale = 1.1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTabScale = 1.0
                }
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tag
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(selectedTab == tag ? .yellow : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == tag ? Color.yellow.opacity(0.15) : Color.clear)
            )
            .scaleEffect(selectedTab == tag ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: selectedTab)
        }
    }
    
    // MARK: - Game Settings Tab
    private var gameSettingsTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                speedCard
                cashGameSettingsCard
                soundCard
            }
            .padding()
        }
    }
    
    private var speedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundColor(.blue)
                Text("游戏速度")
                    .font(.headline)
            }
            
            HStack {
                Text("慢")
                    .font(.caption)
                    .foregroundColor(.gray)
                Slider(
                    value: $settings.gameSpeed,
                    in: 0.5...3.0,
                    step: 0.5
                )
                Text("快")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Text(settings.gameSpeedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var cashGameSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "dollarsign.circle")
                    .foregroundColor(.green)
                Text("现金局设置")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("最大买入次数")
                    Spacer()
                    Text("\(settings.cashGameMaxBuyIns) 次")
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.cashGameMaxBuyIns) },
                        set: { settings.cashGameMaxBuyIns = Int($0) }
                    ),
                    in: 1...10,
                    step: 1
                )
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func infoItem(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.yellow)
            Text(value)
                .font(.subheadline.bold())
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var soundCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $settings.soundEnabled) {
                HStack {
                    Image(systemName: settings.soundEnabled ? "speaker.wave.3" : "speaker.slash")
                        .foregroundColor(settings.soundEnabled ? .blue : .gray)
                    Text("音效")
                        .font(.headline)
                }
            }
            .tint(.blue)
            
            if settings.soundEnabled {
                HStack {
                    Image(systemName: "speaker")
                        .foregroundColor(.gray)
                    Slider(value: $settings.soundVolume, in: 0...1, step: 0.1)
                    Image(systemName: "speaker.wave.3")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Difficulty Tab
    private var difficultyTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                difficultySelector
                quickStats
            }
            .padding()
        }
    }
    
    private var difficultySelector: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("AI 难度")
                    .font(.headline)
            }
            
            ForEach(AIProfile.Difficulty.allCases) { difficulty in
                difficultyRow(difficulty)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func difficultyRow(_ difficulty: AIProfile.Difficulty) -> some View {
        Button(action: { settings.aiDifficulty = difficulty }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(difficulty.rawValue)
                        .font(.headline)
                    Text(difficulty.difficultyDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: index <= difficulty.stars ? "star.fill" : "star")
                            .font(.system(size: 10))
                            .foregroundColor(index <= difficulty.stars ? .yellow : .gray.opacity(0.3))
                    }
                }
                
                if settings.aiDifficulty == difficulty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(settings.aiDifficulty == difficulty ? Color.blue.opacity(0.15) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(settings.aiDifficulty == difficulty ? Color.blue : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var quickStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.green)
                Text("快速统计")
                    .font(.headline)
            }
            
            if historyManager.records.isEmpty {
                Text("暂无游戏记录")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                let stats = calculateStats()
                HStack(spacing: 12) {
                    statBox(title: "总局数", value: "\(stats.total)", color: .blue)
                    statBox(title: "冠军", value: "\(stats.wins)", color: .yellow)
                    statBox(title: "胜率", value: "\(stats.winRate)%", color: .green)
                    statBox(title: "均名", value: "#\(stats.avgRank)", color: .purple)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func statBox(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func calculateStats() -> (total: Int, wins: Int, winRate: Int, avgRank: Int) {
        let total = historyManager.records.count
        guard total > 0 else { return (0, 0, 0, 0) }
        
        let wins = historyManager.records.filter { $0.heroRank == 1 }.count
        let winRate = Int(round(Double(wins) * 100.0 / Double(total)))
        let avgRank = Int(round(Double(historyManager.records.map { $0.heroRank }.reduce(0, +)) / Double(total)))
        
        return (total, wins, winRate, avgRank)
    }
    
    // MARK: - Statistics Tab
    private var statisticsTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                NavigationLink(destination: HistoryView(isPresented: .constant(true))) {
                    menuRow(icon: "clock.arrow.circlepath", title: "游戏历史", color: .blue)
                }
                
                NavigationLink(destination: EnhancedStatisticsView().environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)) {
                    menuRow(icon: "chart.bar.fill", title: "详细统计", color: .green)
                }
                
                NavigationLink(destination: PlayerAnalysisView(hideBackButton: true)) {
                    menuRow(icon: "person.2.fill", title: "玩家分析", color: .purple)
                }
                
                NavigationLink(destination: PlayerListView()) {
                    menuRow(icon: "list.bullet", title: "对手列表", color: .orange)
                }
            }
            .padding()
        }
    }
    
    private func menuRow(icon: String, title: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - About Tab
    private var aboutTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                versionCard
                featuresCard
                contactCard
                supportCard
                
                if let onQuit = onQuit {
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
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
    }
    
    private var featuresCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("功能特点")
                    .font(.headline)
            }
            
            VStack(spacing: 12) {
                featureRow(icon: "person.2.fill", title: "多种游戏模式", desc: "现金局与锦标赛")
                featureRow(icon: "brain.head.profile", title: "智能AI对手", desc: "4种难度可选")
                featureRow(icon: "chart.bar.fill", title: "详细数据统计", desc: "VPIP/PFR/AF分析")
                featureRow(icon: "clock.arrow.circlepath", title: "完整游戏历史", desc: "回顾每一局精彩瞬间")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var versionCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "suit.spade.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
            
            Text("德州扑克")
                .font(.title2.bold())
            
            Text("版本 1.2.0 (Build 2024)")
                .font(.caption)
                .foregroundColor(.gray)
            
            Text("最专业的单机德州扑克游戏")
                .font(.subheadline)
                .foregroundColor(.yellow.opacity(0.8))
                .multilineTextAlignment(.center)
            
            HStack(spacing: 8) {
                featureTag("AI对手")
                featureTag("现金局")
                featureTag("锦标赛")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 25)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func featureTag(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.3))
            .cornerRadius(12)
    }
    
    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "message.fill")
                    .foregroundColor(.green)
                Text("联系开发者")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "wechat")
                        .foregroundColor(.green)
                    Text("微信号: VVE_1001")
                        .font(.subheadline)
                }
                
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.blue)
                    Text("Email: dev@example.com")
                        .font(.subheadline)
                }
            }
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var supportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.pink)
                Text("赞赏支持")
                    .font(.headline)
            }
            
            Text("独立开发不易，你的支持是持续更新的最大动力")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - AIProfile Difficulty Extension
extension AIProfile.Difficulty {
    var difficultyDescription: String {
        switch self {
        case .easy: return "适合新手，熟悉规则"
        case .normal: return "休闲难度，适度挑战"
        case .hard: return "需要策略基础"
        case .expert: return "高强度对抗"
        }
    }
    
    var stars: Int {
        switch self {
        case .easy: return 1
        case .normal: return 2
        case .hard: return 3
        case .expert: return 5
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            settings: GameSettings(),
            isPresented: .constant(true)
        )
    }
}
