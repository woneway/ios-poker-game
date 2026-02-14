import SwiftUI

// MARK: - Win Rate Chart View
/// Displays win rate trend over time using simple line chart
struct WinRateChartView: View {
    let dataPoints: [Double] // Profit/loss over time (BB)
    let labels: [String] // Hand numbers or dates
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 8) {
                Text("盈亏趋势 (BB)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if dataPoints.isEmpty {
                    emptyState
                } else {
                    chartView(in: geo)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("暂无数据")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func chartView(in geo: GeometryProxy) -> some View {
        let width = geo.size.width
        let height = geo.size.height - 30 // Reserve space for labels
        let padding: CGFloat = 8
        
        let chartWidth = width - padding * 2
        let chartHeight = height - padding * 2
        
        // Calculate min/max for scaling
        let minValue = dataPoints.min() ?? 0
        let maxValue = dataPoints.max() ?? 0
        let range = max(abs(minValue), abs(maxValue), 1)
        
        let stepX = chartWidth / CGFloat(max(dataPoints.count - 1, 1))
        
        return ZStack {
            // Background grid
            VStack(spacing: 0) {
                HStack {
                    Text("+\(Int(range))")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                Spacer()
                HStack {
                    Text("0")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                Spacer()
                HStack {
                    Text("-\(Int(range))")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(.leading, 4)
            
            // Zero line
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)
                .position(x: width / 2, y: height / 2)
            
            // Line chart
            linePath(in: CGSize(width: chartWidth, height: chartHeight), 
                    range: range, stepX: stepX)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [chartColor.opacity(0.5), chartColor]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
                .position(x: width / 2, y: height / 2)
            
            // Data points
            ForEach(0..<dataPoints.count, id: \.self) { index in
                let x = padding + CGFloat(index) * stepX
                let normalizedY = (dataPoints[index] + range) / (range * 2) // Normalize to 0-1
                let y = padding + chartHeight * (1 - CGFloat(normalizedY))
                
                Circle()
                    .fill(chartColor)
                    .frame(width: 6, height: 6)
                    .position(x: x, y: y)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func linePath(in size: CGSize, range: Double, stepX: CGFloat) -> Path {
        Path { path in
            guard !dataPoints.isEmpty else { return }
            
            let padding: CGFloat = 8
            let chartHeight = size.height - padding * 2
            
            // Start point
            let startX = padding
            let startNormalizedY = (dataPoints[0] + range) / (range * 2)
            let startY = padding + chartHeight * (1 - CGFloat(startNormalizedY))
            
            path.move(to: CGPoint(x: startX, y: startY))
            
            // Line to each point
            for index in 1..<dataPoints.count {
                let x = padding + CGFloat(index) * stepX
                let normalizedY = (dataPoints[index] + range) / (range * 2)
                let y = padding + chartHeight * (1 - CGFloat(normalizedY))
                
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
    }
    
    private var chartColor: Color {
        let total = dataPoints.reduce(0, +)
        return total >= 0 ? .green : .red
    }
}

// MARK: - Position Win Rate Chart
/// Displays win rate by position (BTN, SB, BB, etc.)
struct PositionWinRateChart: View {
    let positionData: [(position: String, winRate: Double, hands: Int)]
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("位置胜率")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if positionData.isEmpty {
                emptyState
            } else {
                barChart
            }
        }
    }
    
    private var emptyState: some View {
        VStack {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("暂无数据")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var barChart: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(positionData, id: \.position) { data in
                VStack(spacing: 4) {
                    // Win rate label
                    Text("\(Int(data.winRate))%")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    
                    // Bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor(for: data.winRate))
                        .frame(width: 24, height: max(4, CGFloat(data.winRate) * 1.2))
                    
                    // Position label
                    Text(data.position)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    
                    // Hands count
                    Text("\(data.hands)")
                        .font(.system(size: 7))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func barColor(for winRate: Double) -> Color {
        if winRate >= 50 {
            return Color.green.opacity(0.7 + (winRate - 50) / 100 * 0.3)
        } else {
            return Color.red.opacity(0.7 + (50 - winRate) / 100 * 0.3)
        }
    }
}

// MARK: - Hand Distribution Chart
/// Displays distribution of starting hands played
struct HandDistributionChart: View {
    let handTypes: [(type: String, count: Int, color: Color)]
    
    var total: Int {
        handTypes.reduce(0) { $0 + $1.count }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("手牌分布")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if handTypes.isEmpty || total == 0 {
                emptyState
            } else {
                pieChart
            }
        }
    }
    
    private var emptyState: some View {
        VStack {
            Image(systemName: "chart.pie")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("暂无数据")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var pieChart: some View {
        HStack(spacing: 16) {
            // Pie chart
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                
                let sortedTypes = handTypes.sorted { $0.count > $1.count }
                let segments = createSegments(from: sortedTypes)
                
                ForEach(0..<segments.count, id: \.self) { index in
                    PieSegment(
                        startAngle: segments[index].startAngle,
                        endAngle: segments[index].endAngle,
                        color: segments[index].color
                    )
                }
            }
            .frame(width: 100, height: 100)
            
            // Legend
            VStack(alignment: .leading, spacing: 6) {
                ForEach(handTypes.sorted { $0.count > $1.count }, id: \.type) { hand in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(hand.color)
                            .frame(width: 8, height: 8)
                        Text(hand.type)
                            .font(.caption)
                        Spacer()
                        Text("\(hand.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func createSegments(from types: [(type: String, count: Int, color: Color)]) -> [(startAngle: Double, endAngle: Double, color: Color)] {
        var segments: [(startAngle: Double, endAngle: Double, color: Color)] = []
        var currentAngle: Double = -90 // Start from top
        
        for type in types {
            let percentage = Double(type.count) / Double(total)
            let angle = percentage * 360
            segments.append((
                startAngle: currentAngle,
                endAngle: currentAngle + angle,
                color: type.color
            ))
            currentAngle += angle
        }
        
        return segments
    }
}

// MARK: - Pie Segment
struct PieSegment: View {
    let startAngle: Double
    let endAngle: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let radius = min(geo.size.width, geo.size.height) / 2 - 2
                
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(startAngle),
                    endAngle: .degrees(endAngle),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(color)
        }
    }
}

// MARK: - Enhanced Statistics Row
struct EnhancedStatBadge: View {
    let label: String
    let value: String
    let subValue: String?
    let color: Color
    let icon: String?
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 8))
                        .foregroundColor(color)
                }
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
            }
            
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
            
            if let subValue = subValue {
                Text(subValue)
                    .font(.system(size: 7))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .frame(minWidth: 45)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview
struct ChartsView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            WinRateChartView(
                dataPoints: [0, 5, 3, 8, 12, 10, 15, 18, 22, 25, 23, 28, 30, 35, 32],
                labels: (1...15).map { "\($0)" }
            )
            .frame(height: 150)
            
            PositionWinRateChart(positionData: [
                ("BTN", 65, 45),
                ("CO", 58, 38),
                ("MP", 48, 42),
                ("EP", 42, 35),
                ("BB", 35, 50),
                ("SB", 32, 48)
            ])
            
            HandDistributionChart(handTypes: [
                ("Premium", 25, .purple),
                ("Strong", 35, .blue),
                ("Medium", 45, .green),
                ("Weak", 20, .orange),
                ("Trash", 15, .gray)
            ])
        }
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
