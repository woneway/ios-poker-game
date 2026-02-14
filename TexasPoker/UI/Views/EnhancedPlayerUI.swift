import SwiftUI

// MARK: - Enhanced Player Cards View
/// Displays player cards with enhanced visual effects for Hero
struct PlayerCardsView: View {
    let player: Player
    let isHero: Bool
    let showCards: Bool
    let cardWidth: CGFloat
    
    @State private var glowAnimation = false
    
    var body: some View {
        ZStack {
            // Card backs (hidden state)
            if !showCards {
                HStack(spacing: -cardWidth * 0.3) {
                    cardBack
                    cardBack
                }
            } else {
                // Visible cards
                HStack(spacing: -cardWidth * 0.3) {
                    ForEach(player.holeCards) { card in
                        CardView(card: card, width: cardWidth)
                            .overlay(
                                // Premium glow effect for Hero
                                heroGlowOverlay
                            )
                    }
                }
            }
        }
        .onAppear {
            if isHero && showCards {
                startGlowAnimation()
            }
        }
        .onChange(of: showCards) { newValue in
            if isHero && newValue {
                startGlowAnimation()
            }
        }
    }
    
    private var cardBack: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "1E3A5F"),
                        Color(hex: "0D1B2A")
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                // Pattern on card back
                Image(systemName: "suit.spade.fill")
                    .font(.system(size: cardWidth * 0.3))
                    .foregroundColor(.white.opacity(0.15))
            )
            .frame(width: cardWidth, height: cardWidth * 1.4)
            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
    }
    
    @ViewBuilder
    private var heroGlowOverlay: some View {
        if isHero && showCards {
            GeometryReader { geo in
                ZStack {
                    // Outer glow
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.yellow.opacity(glowAnimation ? 0.8 : 0.3),
                                    Color.orange.opacity(glowAnimation ? 0.6 : 0.2),
                                    Color.yellow.opacity(glowAnimation ? 0.8 : 0.3)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .blur(radius: glowAnimation ? 4 : 2)
                    
                    // Inner highlight
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                }
            }
        }
    }
    
    private func startGlowAnimation() {
        withAnimation(
            Animation.easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
        ) {
            glowAnimation = true
        }
    }
}

// MARK: - All In Effect View
/// Displays dramatic All-in visual effect
struct AllInEffectView: View {
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 1
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Explosion ring
            Circle()
                .stroke(Color.orange.opacity(opacity), lineWidth: 4)
                .frame(width: 200 * scale, height: 200 * scale)
            
            // Inner burst
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.yellow.opacity(opacity),
                            Color.orange.opacity(opacity * 0.5),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 100 * scale
                    )
                )
                .frame(width: 150 * scale, height: 150 * scale)
            
            // "ALL IN" text
            Text("ALL IN")
                .font(.system(size: 36, weight: .black))
                .foregroundColor(.white)
                .shadow(color: .orange, radius: 10, x: 0, y: 0)
                .shadow(color: .red, radius: 20, x: 0, y: 0)
                .rotationEffect(.degrees(rotation))
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                scale = 1.5
            }
            
            withAnimation(.easeInOut(duration: 0.5).delay(0.1)) {
                rotation = 5
            }
            
            withAnimation(.easeOut(duration: 1.0).delay(0.5)) {
                opacity = 0
                scale = 3.0
            }
        }
    }
}

// MARK: - Haptic Feedback Helper
/// Helper for haptic feedback on user actions
enum HapticFeedback {
    static func buttonPress() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    static func actionConfirm() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    static func allIn() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
        
        // Secondary impact for dramatic effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let generator2 = UIImpactFeedbackGenerator(style: .rigid)
            generator2.impactOccurred()
        }
    }
    
    static func win() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    static func loss() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
    
    static func fold() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }
}

// MARK: - Enhanced Action Button
/// Action button with haptic feedback and enhanced visuals
struct EnhancedActionButton: View {
    let title: String
    let color: Color
    let icon: String?
    let hapticStyle: HapticStyle
    let action: () -> Void
    
    enum HapticStyle {
        case light, medium, heavy, allIn, fold
    }
    
    var body: some View {
        Button(action: {
            triggerHaptic()
            action()
        }) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                Text(title)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(minWidth: 60, minHeight: 40)
            .padding(.horizontal, 8)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [color.opacity(0.8), color]),
                    startPoint: .top, endPoint: .bottom
                )
            )
            .cornerRadius(10)
            .shadow(color: color.opacity(0.4), radius: 3, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .pressEffect()
    }
    
    private func triggerHaptic() {
        switch hapticStyle {
        case .light:
            HapticFeedback.buttonPress()
        case .medium:
            HapticFeedback.actionConfirm()
        case .heavy:
            HapticFeedback.actionConfirm()
        case .allIn:
            HapticFeedback.allIn()
        case .fold:
            HapticFeedback.fold()
        }
    }
}

// MARK: - Button Press Effect Modifier
struct PressEffectModifier: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

extension View {
    func pressEffect() -> some View {
        modifier(PressEffectModifier())
    }
}

// MARK: - Preview
struct EnhancedUI_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            // Hero cards with glow
            HStack(spacing: 40) {
                VStack {
                    Text("Hero (with glow)")
                        .font(.caption)
                    PlayerCardsView(
                        player: Player(name: "Hero", chips: 1000, isHuman: true),
                        isHero: true,
                        showCards: true,
                        cardWidth: 50
                    )
                }
                
                VStack {
                    Text("AI (hidden)")
                        .font(.caption)
                    PlayerCardsView(
                        player: Player(name: "AI", chips: 1000, isHuman: false),
                        isHero: false,
                        showCards: false,
                        cardWidth: 50
                    )
                }
            }
            
            // Action buttons
            HStack(spacing: 10) {
                EnhancedActionButton(title: "Fold", color: .red, icon: "xmark", hapticStyle: .fold) {}
                EnhancedActionButton(title: "Call", color: .green, icon: "phone", hapticStyle: .light) {}
                EnhancedActionButton(title: "Raise", color: .orange, icon: "arrow.up", hapticStyle: .medium) {}
                EnhancedActionButton(title: "All In", color: .purple, icon: "flame", hapticStyle: .allIn) {}
            }
            
            // All-in effect
            AllInEffectView()
                .frame(height: 150)
        }
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
