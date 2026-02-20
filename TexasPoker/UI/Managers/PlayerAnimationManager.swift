import SwiftUI
import Combine

enum PlayerAnimationType {
    case idle
    case thinking
    case acting
    case winning
    case losing
    case folding
    case allIn
    case celebration
    case cardReveal
    case bigWin
    case tilt
    case calm
}

enum PlayerEmotion {
    case neutral
    case happy
    case sad
    case angry
    case surprised
    case confused
    case scared
    case confident
    
    var emoji: String {
        switch self {
        case .neutral: return "😐"
        case .happy: return "😊"
        case .sad: return "😢"
        case .angry: return "😠"
        case .surprised: return "😲"
        case .confused: return "😕"
        case .scared: return "😨"
        case .confident: return "😎"
        }
    }
    
    var animation: PlayerAnimationType {
        switch self {
        case .happy: return .winning
        case .sad: return .losing
        case .angry: return .tilt
        case .surprised, .scared: return .acting
        case .confident, .neutral: return .idle
        case .confused: return .thinking
        }
    }
}

struct PlayerAnimationConfig {
    var scale: CGFloat = 1.0
    var offset: CGSize = .zero
    var rotation: Double = 0
    var opacity: Double = 1.0
    var blur: CGFloat = 0
    var shake: Bool = false
    var glow: Bool = false
    var emotion: PlayerEmotion = .neutral
}

class PlayerAnimationManager: ObservableObject {
    static let shared = PlayerAnimationManager()
    
    @Published var currentAnimations: [String: PlayerAnimationType] = [:]
    @Published var animationConfigs: [String: PlayerAnimationConfig] = [:]
    @Published var playerEmotions: [String: PlayerEmotion] = [:]
    @Published var cardRevealAnimations: [String: Bool] = [:]
    
    private var animationTimers: [String: Timer] = [:]
    private var emotionTimers: [String: Timer] = [:]
    private var continuousAnimations: [String: Timer] = [:]
    
    private init() {}
    
    func startAnimation(for playerId: String, type: PlayerAnimationType) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var config = self.configFor(type: type)
            config.emotion = self.emotionFor(type: type)
            
            self.currentAnimations[playerId] = type
            self.animationConfigs[playerId] = config
            
            self.stopTimer(for: playerId)
            
            let duration = self.durationFor(type: type)
            self.startTimer(for: playerId, duration: duration)
            
            if type == .thinking || type == .tilt {
                self.startContinuousAnimation(for: playerId, type: type)
            }
        }
    }
    
    func stopAnimation(for playerId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.currentAnimations[playerId] = .idle
            self.animationConfigs[playerId] = PlayerAnimationConfig()
            self.stopTimer(for: playerId)
            self.stopContinuousAnimation(for: playerId)
        }
    }
    
    func setEmotion(for playerId: String, emotion: PlayerEmotion, duration: TimeInterval = 3.0) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.playerEmotions[playerId] = emotion
            
            self.emotionTimers[playerId]?.invalidate()
            self.emotionTimers[playerId] = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.playerEmotions[playerId] = .neutral
            }
        }
    }
    
    func triggerCardReveal(for playerId: String, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.cardRevealAnimations[playerId] = true
            
            Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
                self?.cardRevealAnimations[playerId] = false
                completion?()
            }
        }
    }
    
    func getEmotion(for playerId: String) -> PlayerEmotion {
        return playerEmotions[playerId] ?? .neutral
    }
    
    func isRevealingCards(for playerId: String) -> Bool {
        return cardRevealAnimations[playerId] ?? false
    }
    
    func getConfig(for playerId: String) -> PlayerAnimationConfig {
        var config = animationConfigs[playerId] ?? PlayerAnimationConfig()
        config.emotion = getEmotion(for: playerId)
        return config
    }
    
    func getType(for playerId: String) -> PlayerAnimationType {
        return currentAnimations[playerId] ?? .idle
    }
    
    private func emotionFor(type: PlayerAnimationType) -> PlayerEmotion {
        switch type {
        case .winning, .celebration, .bigWin: return .happy
        case .losing: return .sad
        case .tilt: return .angry
        case .allIn: return .surprised
        case .acting: return .confident
        case .thinking: return .confused
        case .folding: return .scared
        case .idle: return .neutral
        case .cardReveal: return .neutral
        case .calm: return .neutral
        }
    }
    
    private func configFor(type: PlayerAnimationType) -> PlayerAnimationConfig {
        switch type {
        case .idle: return PlayerAnimationConfig()
        case .thinking: return PlayerAnimationConfig(scale: 1.0, opacity: 0.8, shake: true)
        case .acting: return PlayerAnimationConfig(scale: 1.1, rotation: 5)
        case .winning: return PlayerAnimationConfig(scale: 1.2, rotation: 10, glow: true)
        case .losing: return PlayerAnimationConfig(scale: 0.95, opacity: 0.6)
        case .folding: return PlayerAnimationConfig(scale: 0.8, opacity: 0.3, blur: 2)
        case .allIn: return PlayerAnimationConfig(scale: 1.3, rotation: 15, shake: true)
        case .celebration: return PlayerAnimationConfig(scale: 1.2, rotation: 10, glow: true)
        case .bigWin: return PlayerAnimationConfig(scale: 1.5, rotation: 20, glow: true)
        case .tilt: return PlayerAnimationConfig(scale: 1.1, rotation: -5, shake: true)
        case .calm: return PlayerAnimationConfig(scale: 0.95, opacity: 0.9)
        case .cardReveal: return PlayerAnimationConfig(scale: 1.0, blur: 0)
        }
    }
    
    private func durationFor(type: PlayerAnimationType) -> TimeInterval {
        switch type {
        case .idle: return 0
        case .thinking: return 3.0
        case .acting: return 0.5
        case .winning: return 2.0
        case .losing: return 2.5
        case .folding: return 1.0
        case .allIn: return 1.5
        case .celebration: return 3.0
        case .bigWin: return 4.0
        case .tilt: return 2.0
        case .calm: return 1.5
        case .cardReveal: return 0.8
        }
    }
    
    private func startTimer(for playerId: String, duration: TimeInterval) {
        guard duration > 0 else { return }
        animationTimers[playerId] = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.stopAnimation(for: playerId)
        }
    }
    
    private func stopTimer(for playerId: String) {
        animationTimers[playerId]?.invalidate()
        animationTimers.removeValue(forKey: playerId)
    }
    
    private func startContinuousAnimation(for playerId: String, type: PlayerAnimationType) {
        continuousAnimations[playerId] = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            var config = self.animationConfigs[playerId] ?? PlayerAnimationConfig()
            config.rotation = config.rotation == 5 ? -5 : 5
            self.animationConfigs[playerId] = config
        }
    }
    
    private func stopContinuousAnimation(for playerId: String) {
        continuousAnimations[playerId]?.invalidate()
        continuousAnimations.removeValue(forKey: playerId)
    }
}

struct ActionBubbleView: View {
    let action: String
    let isThinking: Bool
    
    @State private var scale: CGFloat = 0.5
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.8))
                .frame(height: 40)
            
            HStack(spacing: 8) {
                if isThinking {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                }
                
                Text(action)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
        }
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.spring(response: 0.3)) {
                scale = 1.0
            }
        }
    }
}

struct ChipAnimationView: View {
    let amount: Int
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(Color.orange)
                    .frame(width: 20, height: 20)
                    .offset(x: isAnimating ? CGFloat.random(in: -30...30) : 0,
                            y: isAnimating ? CGFloat.random(in: -30...30) : 0)
                    .opacity(isAnimating ? 0 : 1)
            }
            
            Text("+\(amount)")
                .font(.headline)
                .foregroundColor(.yellow)
                .scaleEffect(isAnimating ? 1.5 : 0.5)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                isAnimating = true
            }
        }
    }
}

struct EmotionBadgeView: View {
    let emotion: PlayerEmotion
    let size: CGFloat
    
    init(emotion: PlayerEmotion, size: CGFloat = 30) {
        self.emotion = emotion
        self.size = size
    }
    
    var body: some View {
        Text(emotion.emoji)
            .font(.system(size: size))
            .scaleEffect(isAppearing ? 1.0 : 0.5)
            .opacity(isAppearing ? 1.0 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isAppearing = true
                }
            }
    }
    
    @State private var isAppearing = false
}

struct CardRevealAnimation: View {
    let cards: [Card]
    let isFaceUp: Bool
    
    init(cards: [Card], isFaceUp: Bool) {
        self.cards = cards
        self.isFaceUp = isFaceUp
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                AnimatedCardFlip(card: card, isFaceUp: isFaceUp, delay: Double(index) * 0.15)
            }
        }
    }
}

struct AnimatedCardFlip: View {
    let card: Card
    let isFaceUp: Bool
    let delay: Double
    
    @State private var rotation: Double = 0
    @State private var isFlipped: Bool = false
    
    var body: some View {
        ZStack {
            PlayingCardBack()
                .rotation3DEffect(
                    .degrees(rotation),
                    axis: (x: 0, y: 1, z: 0)
                )
                .opacity(isFlipped ? 0 : 1)
            
            PlayingCardFront(card: card)
                .rotation3DEffect(
                    .degrees(rotation + 180),
                    axis: (x: 0, y: 1, z: 0)
                )
                .opacity(isFlipped ? 1 : 0)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    rotation = 180
                    isFlipped = true
                }
            }
        }
    }
}

struct PlayingCardBack: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 40, height: 56)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
            )
    }
}

struct PlayingCardFront: View {
    let card: Card
    
    private var cardColor: Color {
        card.suit == .hearts || card.suit == .diamonds ? .red : .black
    }
    
    private var suitSymbol: String {
        switch card.suit {
        case .hearts: return "♥"
        case .diamonds: return "♦"
        case .spades: return "♠"
        case .clubs: return "♣"
        }
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
                .frame(width: 40, height: 56)
            
            VStack(spacing: 2) {
                Text("\(card.rank.rawValue)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(cardColor)
                
                Text(suitSymbol)
                    .font(.system(size: 16))
                    .foregroundColor(cardColor)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct PotAnimationView: View {
    let amount: Int
    let isWinning: Bool
    
    @State private var scale: CGFloat = 0.5
    @State private var offset: CGFloat = -20
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack(spacing: 4) {
            Text(isWinning ? "赢得" : "投入")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("$\(amount)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(isWinning ? .green : .white)
        }
        .scaleEffect(scale)
        .offset(y: offset)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
                offset = 0
                opacity = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    opacity = 0
                    scale = 0.8
                }
            }
        }
    }
}

struct HandStrengthIndicator: View {
    let strength: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("牌力")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(strength * 100))%")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(strengthColor)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(strengthColor)
                        .frame(width: geometry.size.width * strength, height: 4)
                }
            }
            .frame(height: 4)
        }
    }
    
    private var strengthColor: Color {
        if strength > 0.7 { return .green }
        if strength > 0.4 { return .yellow }
        return .red
    }
}

struct PlayerStatusBadge: View {
    let status: PlayerStatus
    let animationManager: PlayerAnimationManager
    let playerId: String
    
    var body: some View {
        Group {
            switch status {
            case .thinking:
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("思考中")
                        .font(.caption2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(10)
                
            case .acting:
                Text("行动中")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                
            case .won:
                Text("胜!")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                
            case .lost:
                Text("负")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                
            case .allIn:
                Text("All-In!")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shakeEffect()
                
            case .none:
                EmptyView()
            }
        }
    }
    
    enum PlayerStatus {
        case thinking
        case acting
        case won
        case lost
        case allIn
        case none
    }
}

struct ShakeEffect: ViewModifier {
    @State private var shake = false
    
    func body(content: Content) -> some View {
        content
            .offset(x: shake ? -5 : 5)
            .animation(
                Animation.easeInOut(duration: 0.1)
                    .repeatForever(autoreverses: true),
                value: shake
            )
            .onAppear {
                shake = true
            }
    }
}

extension View {
    func shakeEffect() -> some View {
        modifier(ShakeEffect())
    }
}

struct GlowEffect: ViewModifier {
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.6), radius: 10)
    }
}

extension View {
    func glowEffect(color: Color) -> some View {
        modifier(GlowEffect(color: color))
    }
}
