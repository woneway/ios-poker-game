# iOS德州扑克单机游戏 - 完整开发计划书

## 1. 技术架构

### 1.1 技术栈选择
- **开发语言**: Swift 5.9+
- **UI框架**: SwiftUI (iOS 15+)
- **状态管理**: Combine + ObservableObject
- **数据持久化**: Core Data / UserDefaults
- **游戏逻辑**: 纯Swift实现，无第三方依赖
- **音效**: AVFoundation
- **动画**: SwiftUI Animation + Core Animation

### 1.2 项目结构
```
TexasPoker/
├── App/
│   ├── TexasPokerApp.swift
│   └── AppDelegate.swift
├── Core/
│   ├── Models/
│   │   ├── Card.swift              # 扑克牌模型
│   │   ├── Hand.swift              # 手牌
│   │   ├── Deck.swift              # 牌组
│   │   ├── Player.swift            # 玩家基础模型
│   │   ├── AIPlayer.swift          # AI玩家
│   │   ├── HumanPlayer.swift       # 人类玩家
│   │   ├── Pot.swift               # 底池
│   │   └── GameState.swift         # 游戏状态
│   ├── Engine/
│   │   ├── HandEvaluator.swift     # 牌力评估
│   │   ├── PokerEngine.swift       # 游戏引擎
│   │   ├── BettingRound.swift      # 下注轮
│   │   └── GameCoordinator.swift   # 游戏协调器
│   ├── AI/
│   │   ├── AIProfile.swift         # AI画像
│   │   ├── DecisionEngine.swift    # 决策引擎
│   │   ├── PositionStrategy.swift  # 位置策略
│   │   └── Personality/
│   │       ├── TAGProfile.swift    # 紧凶型
│   │       ├── LAGProfile.swift    # 松凶型
│   │       ├── TightPassive.swift  # 紧弱型
│   │       ├── LoosePassive.swift  # 松弱型
│   │       ├── Maniac.swift        # 疯鱼型
│   │       ├── Rock.swift          # 石头型
│   │       └── CallingStation.swift # 跟注站
│   └── Utils/
│       ├── CardUtils.swift
│       ├── Probability.swift
│       └── Constants.swift
├── UI/
│   ├── Views/
│   │   ├── GameTableView.swift     # 牌桌主视图
│   │   ├── CardView.swift          # 扑克牌视图
│   │   ├── PlayerView.swift        # 玩家视图
│   │   ├── ControlPanel.swift      # 控制面板
│   │   ├── ChipStackView.swift     # 筹码堆
│   │   └── ActionButtons.swift     # 操作按钮
│   └── ViewModels/
│       └── GameViewModel.swift
└── Resources/
    ├── Assets.xcassets
    ├── Sounds/
    └── Data/
```

---

## 2. 游戏核心模块

### 2.1 扑克牌系统
```swift
enum Suit: String, CaseIterable {
    case spades = "♠️"
    case hearts = "♥️"
    case diamonds = "♦️"
    case clubs = "♣️"
}

enum Rank: Int, CaseIterable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack, queen, king, ace
    
    var display: String {
        switch self {
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        default: return "\(rawValue)"
        }
    }
}

struct Card: Identifiable, Equatable {
    let id = UUID()
    let suit: Suit
    let rank: Rank
    
    var isRed: Bool { suit == .hearts || suit == .diamonds }
}
```

### 2.2 牌力评估引擎
```swift
enum HandRank: Int, Comparable {
    case highCard = 1
    case onePair
    case twoPair
    case threeOfAKind
    case straight
    case flush
    case fullHouse
    case fourOfAKind
    case straightFlush
    case royalFlush
    
    static func < (lhs: HandRank, rhs: HandRank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

class HandEvaluator {
    // 评估7张牌（2张手牌 + 5张公共牌）的最佳5张
    static func evaluateBestHand(holeCards: [Card], communityCards: [Card]) -> (handRank: HandRank, kickers: [Rank]) {
        let allCards = holeCards + communityCards
        // 实现C(7,5)=21种组合的评估，返回最强牌型
    }
    
    // 计算胜率（蒙特卡洛模拟）
    static func calculateWinRate(holeCards: [Card], communityCards: [Card], numOpponents: Int) -> Double {
        // 运行10000次模拟，计算胜率
    }
}
```

### 2.3 游戏引擎
```swift
class PokerEngine: ObservableObject {
    @Published var players: [Player] = []
    @Published var communityCards: [Card] = []
    @Published var pot: Pot = Pot()
    @Published var currentPosition: Position = .dealer
    @Published var gamePhase: GamePhase = .preFlop
    
    func startNewHand() {
        // 1. 重置牌桌
        // 2. 移动按钮位
        // 3. 收取盲注
        // 4. 发手牌
    }
    
    func processAction(_ action: PlayerAction, from player: Player) {
        // 处理玩家动作，更新状态
    }
}
```

---

## 3. AI系统设计

### 3.1 AI画像系统
```swift
struct AIProfile {
    let name: String
    let avatar: String
    let description: String
    
    // 核心参数（0-100）
    var tightness: Double       // 紧松度：高=只打好牌
    var aggression: Double      // 凶粘度：高=倾向加注而非跟注
    var bluffFrequency: Double  // 诈唬频率
    var foldTo3Bet: Double      // 面对3-bet弃牌率
    var cbetFrequency: Double   // 持续下注频率
    
    // 位置调整
    var positionAdjustment: [Position: PositionModifier]
}

struct PositionModifier {
    var vpipAdjustment: Double      // 入池率调整
    var aggressionAdjustment: Double // 攻击性调整
}
```

### 3.2 决策引擎
```swift
class DecisionEngine {
    func makeDecision(for ai: AIPlayer, context: GameContext) -> PlayerAction {
        // 1. 计算基础概率
        let handStrength = calculateHandStrength(ai.holeCards, context.communityCards)
        let potOdds = calculatePotOdds(context)
        let winRate = HandEvaluator.calculateWinRate(
            holeCards: ai.holeCards,
            communityCards: context.communityCards,
            numOpponents: context.activePlayers - 1
        )
        
        // 2. 应用AI个性调整
        let adjustedWinRate = applyPersonalityAdjustment(
            winRate, 
            profile: ai.profile,
            position: ai.position,
            context: context
        )
        
        // 3. 基于概率选择动作
        return selectActionBasedOnProbability(
            winRate: adjustedWinRate,
            potOdds: potOdds,
            profile: ai.profile,
            context: context
        )
    }
    
    private func selectActionBasedOnProbability(...) -> PlayerAction {
        // 使用加权随机选择，而非确定性决策
        // 让AI更像真人，有合理波动
    }
}
```

### 3.3 位置策略
```swift
enum Position: Int, CaseIterable {
    case smallBlind = 0
    case bigBlind
    case underTheGun    // UTG
    case utgPlus1
    case middlePosition
    case hijack
    case cutoff
    case dealer         // Button
    
    var isEarly: Bool { self == .underTheGun || self == .utgPlus1 }
    var isMiddle: Bool { self == .middlePosition }
    var isLate: Bool { self == .hijack || self == .cutoff || self == .dealer }
    var isBlind: Bool { self == .smallBlind || self == .bigBlind }
}

class PositionStrategy {
    // 不同位置的入池率基准
    static let vpipBaseline: [Position: Double] = [
        .dealer: 0.45,      // BTN最宽
        .cutoff: 0.35,
        .hijack: 0.28,
        .middlePosition: 0.22,
        .utgPlus1: 0.18,
        .underTheGun: 0.15, // UTG最紧
        .bigBlind: 0.40,    // 已投钱，范围宽
        .smallBlind: 0.35
    ]
    
    // 根据位置调整手牌范围
    static func getStartingHandRange(for position: Position, tightness: Double) -> [StartingHand: Double] {
        // 返回各手牌的入池概率
    }
}
```

---

## 4. 7个AI角色详细设定

### 角色1: "石头" (The Rock)
```swift
let rockProfile = AIProfile(
    name: "石头",
    avatar: "avatar_rock",
    description: "只玩顶级牌，从不诈唬",
    tightness: 95,          // 极紧
    aggression: 60,         // 中等偏凶
    bluffFrequency: 5,      // 几乎不诈唬
    foldTo3Bet: 90,         // 遇到反击就弃
    cbetFrequency: 70,
    positionAdjustment: [
        .dealer: PositionModifier(vpipAdjustment: 0.10, aggressionAdjustment: 0.15),
        .underTheGun: PositionModifier(vpipAdjustment: -0.05, aggressionAdjustment: 0.0)
    ]
)
// 风格：TAG（紧凶）
// 手牌范围：只玩TT+, AQ+
// 策略：强牌加注，弱牌弃牌，从不诈唬
// 弱点：容易被连续下注逼弃
```

### 角色2: "疯子麦克" (Maniac Mike)
```swift
let maniacProfile = AIProfile(
    name: "疯子麦克",
    avatar: "avatar_maniac",
    description: "疯狂加注，从不弃牌",
    tightness: 20,          // 极松
    aggression: 95,         // 极凶
    bluffFrequency: 40,     // 高频诈唬
    foldTo3Bet: 20,         // 很少弃牌
    cbetFrequency: 95,
    positionAdjustment: [
        .dealer: PositionModifier(vpipAdjustment: 0.25, aggressionAdjustment: 0.20),
        .all: PositionModifier(vpipAdjustment: 0.15, aggressionAdjustment: 0.15)
    ]
)
// 风格：超LAG（超松凶）
// 手牌范围：任意两张牌都可能玩
// 策略：无限加注，压力拉满
// 弱点：波动极大，容易被坚果套住
```

### 角色3: "跟注站安娜" (Calling Station Anna)
```swift
let callingStationProfile = AIProfile(
    name: "安娜",
    avatar: "avatar_anna",
    description: "喜欢跟注，从不加注",
    tightness: 40,
    aggression: 15,         // 极被动
    bluffFrequency: 5,
    foldTo3Bet: 10,         // 几乎不弃牌
    cbetFrequency: 20,
    positionAdjustment: [:]
)
// 风格：LP（松弱）
// 手牌范围：中宽，但从不主动加注
// 策略：看翻牌，有牌跟注，没牌也舍不得弃
// 弱点：价值下注的对象，从不保护底池
```

### 角色4: "狡猾狐狸" (The Fox)
```swift
let foxProfile = AIProfile(
    name: "老狐狸",
    avatar: "avatar_fox",
    description: "平衡型玩家，难以捉摸",
    tightness: 55,
    aggression: 65,
    bluffFrequency: 25,     // 合理诈唬
    foldTo3Bet: 55,
    cbetFrequency: 65,
    positionAdjustment: [
        .dealer: PositionModifier(vpipAdjustment: 0.15, aggressionAdjustment: 0.20),
        .cutoff: PositionModifier(vpipAdjustment: 0.10, aggressionAdjustment: 0.15),
        .underTheGun: PositionModifier(vpipAdjustment: -0.10, aggressionAdjustment: -0.05)
    ]
)
// 风格：TAG（标准紧凶）
// 手牌范围：位置决定，15-45%入池率
// 策略：平衡攻防，会读位置，会诈唬
// 弱点：无明显弱点，最难对付
```

### 角色5: "鲨鱼汤姆" (Shark Tom)
```swift
let sharkProfile = AIProfile(
    name: "鲨鱼汤姆",
    avatar: "avatar_shark",
    description: "位置意识极强，收割松鱼",
    tightness: 45,
    aggression: 75,
    bluffFrequency: 30,
    foldTo3Bet: 60,
    cbetFrequency: 75,
    positionAdjustment: [
        .dealer: PositionModifier(vpipAdjustment: 0.20, aggressionAdjustment: 0.25),
        .cutoff: PositionModifier(vpipAdjustment: 0.15, aggressionAdjustment: 0.20),
        .smallBlind: PositionModifier(vpipAdjustment: -0.05, aggressionAdjustment: 0.0)
    ]
)
// 风格：LAG（松凶）但位置敏感
// 手牌范围：后位极宽，前位收紧
// 策略：位置优势时疯狂偷池，劣势时果断弃牌
// 弱点：被反击时如果手牌弱会弃
```

### 角色6: "学院派艾米" (Academic Amy)
```swift
let academicProfile = AIProfile(
    name: "艾米",
    avatar: "avatar_amy",
    description: "严格按GTO，数学驱动",
    tightness: 50,
    aggression: 55,
    bluffFrequency: 20,
    foldTo3Bet: 50,
    cbetFrequency: 60,
    positionAdjustment: PositionStrategy.standardGTO
)
// 风格：GTO（博弈论最优）
// 手牌范围：严格按概率分布
// 策略：平衡策略，难以被剥削
// 弱点：缺乏针对调整，面对极端风格不优化
```

### 角色7: "情绪玩家大卫" (Tilt David)
```swift
let tiltProfile = AIProfile(
    name: "大卫",
    avatar: "avatar_david",
    description: "输钱后会情绪化，上头发疯",
    tightness: 50,          // 正常时
    aggression: 50,
    bluffFrequency: 20,
    foldTo3Bet: 50,
    cbetFrequency: 60,
    tiltFactor: 0.0,        // 上头晕度 0-1
    positionAdjustment: [:]
)
// 风格：动态变化
// 正常时：标准TAG
// 上头晕度>0.3时：变松凶
// 上头晕度>0.7时：变疯鱼
// 策略：输大底池后tilt上升，决策偏移
// 弱点：情绪不稳定，连续输后送钱
```

---

## 5. 位置策略矩阵

| 位置 | VPIP基准 | 攻击性 | 3-bet范围 | 诈唬倾向 |
|------|---------|--------|----------|----------|
| BTN | 45% | 高 | 宽 | 高 |
| CO | 35% | 中高 | 中宽 | 中高 |
| HJ | 28% | 中 | 标准 | 中 |
| MP | 22% | 中 | 紧 | 低 |
| UTG+1 | 18% | 低 | 极紧 | 极低 |
| UTG | 15% | 低 | 只强牌 | 从不 |
| BB | 40% | 中 | 防御宽 | 中 |
| SB | 35% | 中低 | 紧 | 低 |

---

## 6. 开发里程碑

### Phase 1: 核心框架 (Week 1-2)
- [ ] 项目搭建，SwiftUI基础架构
- [ ] Card/Deck/Hand模型
- [ ] HandEvaluator牌力评估
- [ ] 基础UI（牌桌、扑克牌视图）

### Phase 2: 游戏引擎 (Week 3-4)
- [ ] PokerEngine游戏逻辑
- [ ] 下注系统（跟注、加注、弃牌）
- [ ] 游戏流程（发牌、翻牌、转牌、河牌）
- [ ] 底池计算与分配

### Phase 3: AI系统 (Week 5-6)
- [ ] AIProfile系统
- [ ] DecisionEngine决策引擎
- [ ] 7个AI角色实现
- [ ] 蒙特卡洛胜率计算

### Phase 4: 完整游戏 (Week 7-8)
- [ ] 8人桌完整流程
- [ ] 玩家交互界面
- [ ] 筹码系统
- [ ] 游戏记录与统计

### Phase 5: 优化打磨 (Week 9-10)
- [ ] 动画与音效
- [ ] AI平衡性调优
- [ ] UI美化
- [ ] 测试与修复

---

## 7. 美术资源需求

### 7.1 UI资源
- 牌桌背景（绿色绒布质感）
- 扑克牌（正面52张 + 背面1张）
- 筹码（多种面值，不同颜色）
- 玩家头像（7个AI + 1玩家 = 8个）
- 按钮（跟注、加注、弃牌、过牌）
- 位置标记（D、SB、BB）
- 底池显示框

### 7.2 动画需求
- 发牌动画
- 筹码移动动画
- 牌翻开动画
- 下注动作反馈
- 胜利特效

### 7.3 音效需求
- 发牌音效
- 筹码碰撞声
- 按钮点击声
- 胜利/失败音效
- 背景音乐（可选）

---

## 8. 测试方案

### 8.1 单元测试
```swift
class PokerEngineTests: XCTestCase {
    func testHandEvaluation() {
        // 测试牌力评估正确性
    }
    
    func testPotCalculation() {
        // 测试底池计算
    }
    
    func testAIDecision() {
        // 测试AI决策合理性
    }
}
```

### 8.2 AI平衡性测试
- 运行10000手牌，统计各AI胜率
- 验证无主导策略（TAG/LAG/弱鱼应有不同胜负）
- 调整参数使胜率分布合理

### 8.3 用户体验测试
- 操作流畅度
- 动画自然度
- AI行为真实感
- 游戏节奏把控

---

## 9. 关键技术点

### 9.1 手牌强度计算
使用7选5算法，评估所有C(7,5)=21种组合，返回最强牌型。

### 9.2 胜率计算
蒙特卡洛模拟：随机发剩余牌10000次，统计获胜比例。

### 9.3 AI决策
非确定性决策：使用加权随机，而非固定阈值，使AI更像真人。

### 9.4 性能优化
- 胜率计算缓存
- 异步AI思考
- 动画预加载

---

## 10. 扩展功能（可选）

- 游戏存档/读档
- 成就系统
- 统计面板（VPIP、PFR、胜率等）
- 难度等级（AI强度调整）
- 多人联机（GameKit）
- 不同游戏模式（SNG、锦标赛）

---

**预估总开发时间**: 10周（单人全职）
**最小可行版本**: 6周（核心功能）
