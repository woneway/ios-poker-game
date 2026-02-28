import SwiftUI

struct AIVerificationView: View {
    @State private var runner = AIVerificationRunner()
    @State private var config = AIVerificationConfig.default
    @State private var showingResults = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                playerSelectionCard
                parametersCard
                actionButtons
                
                if !runner.results.isEmpty || runner.isRunning {
                    resultsCard
                }
            }
            .padding()
        }
        .background(Color(hex: "0f0f23"))
        .onAppear {
            runner.setSelectedDifficulties(Array(runner.selectedDifficulties))
        }
    }
    
    private var playerSelectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.3")
                    .foregroundColor(.blue)
                Text("玩家选择")
                    .font(.headline)
                Spacer()
                Text("已选 \(runner.selectedProfiles.count) 人")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            difficultyFilter
            
            HStack(spacing: 12) {
                Button(action: {
                    runner.selectAll()
                }) {
                    Text("全选")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                }
                
                Button(action: {
                    runner.deselectAll()
                }) {
                    Text("清空")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(6)
                }
                
                Spacer()
            }
            
            playerList
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var difficultyFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AIProfile.Difficulty.allCases) { difficulty in
                    difficultyChip(difficulty)
                }
            }
        }
    }
    
    private func difficultyChip(_ difficulty: AIProfile.Difficulty) -> some View {
        let isSelected = runner.selectedDifficulties.contains(difficulty)
        return Button(action: {
            var newDifficulties = runner.selectedDifficulties
            if isSelected {
                newDifficulties.remove(difficulty)
            } else {
                newDifficulties.insert(difficulty)
            }
            runner.setSelectedDifficulties(Array(newDifficulties))
        }) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                }
                Text(difficulty.description)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color.white.opacity(0.05))
            .foregroundColor(isSelected ? .white : .gray)
            .cornerRadius(16)
        }
    }
    
    private var playerList: some View {
        Group {
            if runner.selectedProfiles.isEmpty {
                Text("请选择难度级别")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                    ForEach(runner.selectedProfiles, id: \.id) { profile in
                        playerChip(name: profile.name, aggression: profile.aggression, tightness: profile.tightness)
                    }
                }
            }
        }
    }
    
    private func playerChip(name: String, aggression: Double, tightness: Double) -> some View {
        VStack(spacing: 4) {
            Text(String(name.prefix(1)))
                .font(.title2)
                .foregroundColor(.yellow)
            Text(name)
                .font(.caption2)
                .lineLimit(1)
            Text("A:\(Int(aggression*10)) T:\(Int(tightness*10))")
                .font(.system(size: 8))
                .foregroundColor(.gray)
        }
        .frame(width: 70, height: 60)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var parametersCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape")
                    .foregroundColor(.green)
                Text("参数设置")
                    .font(.headline)
            }
            
            parameterRow(title: "比赛场次", value: $config.tournamentCount, range: 1...20)
            parameterRow(title: "每场手牌", value: $config.handsPerTournament, range: 20...200)
            parameterRow(title: "初始筹码", value: $config.startingChips, range: 500...5000)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func parameterRow(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            HStack(spacing: 8) {
                TextField("", value: value, formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 70)
                    .onChange(of: value.wrappedValue) { _, newValue in
                        if newValue < range.lowerBound {
                            value.wrappedValue = range.lowerBound
                        } else if newValue > range.upperBound {
                            value.wrappedValue = range.upperBound
                        }
                    }
            }
            .font(.system(.body, design: .monospaced))
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if runner.isRunning {
                HStack(spacing: 12) {
                    VStack(spacing: 8) {
                        ProgressView(value: runner.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        Text("正在进行 \(runner.currentGame)/\(config.tournamentCount) 场")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Button(action: {
                        runner.stopVerification()
                    }) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("停止")
                        }
                        .font(.headline)
                        .padding(.vertical, 14)
                        .frame(width: 80)
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Button(action: {
                        runner.runVerification(config: config)
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("开始测试")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(runner.selectedProfiles.isEmpty ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(runner.selectedProfiles.isEmpty)
                    
                    if !runner.results.isEmpty {
                        Button(action: {
                            runner.results = []
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("清空")
                            }
                            .font(.headline)
                            .padding(.vertical, 14)
                            .frame(width: 80)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(12)
                        }
                    }
                }
            }
        }
    }
    
    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(.yellow)
                Text(runner.isRunning ? "实时排名 (第\(runner.currentGame)场)" : "结果对比")
                    .font(.headline)
                Spacer()
                Text("\(runner.selectedProfiles.count) 人")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            resultsTable
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var resultsTable: some View {
        VStack(spacing: 8) {
            tableHeader
            
            ForEach(Array(runner.results.enumerated()), id: \.element.id) { index, result in
                tableRow(index: index + 1, result: result)
            }
        }
    }
    
    private var tableHeader: some View {
        HStack {
            Text("排名")
                .frame(width: 40, alignment: .center)
            Text("玩家")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("预期")
                .frame(width: 50, alignment: .center)
            Text("实际")
                .frame(width: 50, alignment: .center)
            Text("偏差")
                .frame(width: 40, alignment: .center)
            Text("状态")
                .frame(width: 50, alignment: .center)
        }
        .font(.caption)
        .foregroundColor(.gray)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func tableRow(index: Int, result: AIVerificationResult) -> some View {
        HStack {
            Text("\(index)")
                .frame(width: 40, alignment: .center)
                .foregroundColor(.yellow)
            
            HStack(spacing: 4) {
                Text(String(result.profileName.prefix(1)))
                    .foregroundColor(.yellow)
                Text(result.profileName)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.caption)
            
            Text("\(result.expectedRank)-\(result.expectedRank + 5)")
                .frame(width: 50, alignment: .center)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(String(format: "%.1f", result.actualRank))
                .frame(width: 50, alignment: .center)
                .font(.caption.bold())
            
            Text("\(result.deviation > 0 ? "+" : "")\(result.deviation)")
                .frame(width: 40, alignment: .center)
                .font(.caption)
                .foregroundColor(deviationColor(result.deviation))
            
            statusBadge(result.status)
                .frame(width: 50, alignment: .center)
        }
        .font(.caption)
        .padding(.vertical, 6)
        .background(index % 2 == 0 ? Color.white.opacity(0.02) : Color.clear)
    }
    
    private func deviationColor(_ deviation: Int) -> Color {
        if deviation <= -5 { return .green }
        if deviation >= 5 { return .red }
        return .gray
    }
    
    private func statusBadge(_ status: AIVerificationResult.VerificationStatus) -> some View {
        let color: Color = {
            switch status {
            case .ahead: return .green
            case .behind: return .red
            case .onTrack: return .blue
            }
        }()
        
        return Text(status.rawValue)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}
