import SwiftUI

struct FlippingCard: View {
    let card: Card
    let delay: Double
    @State private var isFlipped = false
    
    var body: some View {
        ZStack {
            // Card back
            CardBackView()
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isFlipped ? 90 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
            
            // Card front
            CardView(card: card, width: 40)
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : -90),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).delay(delay)) {
                isFlipped = true
            }
        }
    }
}

struct CardBackView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
            )
            .frame(width: 40, height: 40)
    }
}
