import SwiftUI

struct ChipView: View {
    let amount: Int
    let size: CGFloat
    
    // Determine color based on amount (Standard Casino Colors)
    var color: Color {
        switch amount {
        case 1..<5: return .white
        case 5..<25: return .red
        case 25..<100: return .green
        case 100..<500: return .black
        case 500..<1000: return .purple
        case 1000..<5000: return .yellow
        default: return .blue
        }
    }
    
    var body: some View {
        ZStack {
            // 1. Main Body
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 2)
            
            // 2. Dashed Border (The "Stripes")
            Circle()
                .strokeBorder(Color.white, style: StrokeStyle(lineWidth: size * 0.15, dash: [size * 0.15, size * 0.15]))
                .frame(width: size * 0.85, height: size * 0.85)
                .opacity(0.7)
            
            // 3. Inner Circle
            Circle()
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                .background(Circle().fill(Color.clear)) // Just the border
                .frame(width: size * 0.6, height: size * 0.6)
            
            // 4. Value Text
            Text("\(amount)")
                .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                .foregroundColor(amount >= 100 ? .white : .black)
                .shadow(color: .black.opacity(0.5), radius: 1)
        }
    }
}

struct ChipStackView: View {
    let amount: Int
    let height: CGFloat = 20
    
    var body: some View {
        // Simple representation: Just one chip with the total value
        // In a real game, we would stack multiple ChipViews
        ChipView(amount: amount, size: 24)
    }
}
