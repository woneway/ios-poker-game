import SwiftUI

// MARK: - Difficulty Selector View
/// Allows players to select AI difficulty and configure opponents
struct DifficultySelectorView: View {
    @Binding var selectedDifficulty: AIProfile.Difficulty
    @Binding var playerCount: Int
    @Binding var isRandomOpponents: Bool
    
    @State private var selectedOpponents: [AIProfile] = []
    @State private var showOpponentPicker = false
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            // Difficulty selection
            difficultySection
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Player count
            playerCountSection
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Opponent selection mode
            opponentModeSection
            
            // Preview of opponents
            if !isRandomOpponents {
                opponentPreviewSection
            }
        }
        .padding()
        .background(Color(hex: "1a1a2e"))
        .cornerRadius(12)
    }
    
    // MARK: - Difficulty Section
    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("游戏难度")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(AIProfile.Difficulty.allCases) { difficulty in
                DifficultyRow(
                    difficulty: difficulty,
                    isSelected: selectedDifficulty == difficulty,
                    onTap: { selectedDifficulty = difficulty }
                )
            }
        }
    }
    
    // MARK: - Player Count Section
    private var playerCountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("玩家人数")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(playerCount) 人")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Slider(value: .init(
                get: { Double(playerCount) },
                set: { playerCount = Int($0) }
            ), in: 2...8, step: 1)
            .accentColor(.blue)
            
            HStack {
                Text("2人")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("8人")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - Opponent Mode Section
    private var opponentModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("对手配置")
                .font(.headline)
                .foregroundColor(.white)
            
            Picker("对手模式", selection: $isRandomOpponents) {
                Text("随机对手").tag(true)
                Text("自选对手").tag(false)
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    // MARK: - Opponent Preview Section
    private var opponentPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("对手预览")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { showOpponentPicker = true }) {
                    Text("更换")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if selectedOpponents.isEmpty {
                // Generate random opponents for preview
                let previewOpponents = selectedDifficulty.randomOpponents(count: playerCount - 1)
                
                FlowLayout(spacing: 8) {
                    ForEach(previewOpponents, id: \.name) { profile in
                        OpponentBadge(profile: profile)
                    }
                }
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(selectedOpponents, id: \.name) { profile in
                        OpponentBadge(profile: profile)
                    }
                }
            }
        }
    }
}

// MARK: - Difficulty Row
struct DifficultyRow: View {
    let difficulty: AIProfile.Difficulty
    let isSelected: Bool
    let onTap: () -> Void
    
    private var difficultyColor: Color {
        switch difficulty {
        case .easy: return .green
        case .normal: return .blue
        case .hard: return .orange
        case .expert: return .red
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Icon
                ZStack {
                    Circle()
                        .fill(difficultyColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 16))
                        .foregroundColor(difficultyColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(difficulty.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(difficulty.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? difficultyColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconName: String {
        switch difficulty {
        case .easy: return "leaf.fill"
        case .normal: return "bolt.fill"
        case .hard: return "flame.fill"
        case .expert: return "crown.fill"
        }
    }
}

// MARK: - Opponent Badge
struct OpponentBadge: View {
    let profile: AIProfile

    var body: some View {
        HStack(spacing: 4) {
            profile.avatar.view(size: 16)
            Text(profile.name)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// MARK: - Preview
struct DifficultySelectorView_Previews: PreviewProvider {
    static var previews: some View {
        DifficultySelectorView(
            selectedDifficulty: .constant(.normal),
            playerCount: .constant(6),
            isRandomOpponents: .constant(true)
        )
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
