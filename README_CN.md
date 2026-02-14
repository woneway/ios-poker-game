# 🃏 iOS 德州扑克游戏

<div align="center">

![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![iOS](https://img.shields.io/badge/iOS-15+-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Status-Active-success)

**基于 SwiftUI 构建的专业德州扑克游戏**

[English](./README.md) | 中文

</div>

---

## ✨ 功能特性

### 🎮 游戏模式
- **锦标赛模式** — 与 AI 对手竞争，盲注逐步提升
- **现金桌模式** — 灵活买入/补充筹码系统

### 🎯 核心游戏引擎
- 完整的德州扑克规则实现
- 多玩家支持（2-8人）
- 高级下注系统（过牌、跟注、加注、弃牌、全下）
- 买入和补充筹码支持
- 会话追踪和盈亏分析

### 🤖 AI 对手（7种独特个性）

| 角色 | 风格 | 入池率 | 攻击性 | 描述 |
|------|------|--------|--------|------|
| 🪨 **石头** | 紧凶型 | 15% | 高 | 只玩优质手牌，从不诈唬 |
| 😈 **疯子** | 松凶型 | 55% | 极高 | 持续加注，从不弃牌 |
| 👩 **安娜** | 松弱型 | 40% | 极低 | 喜欢跟注，从不加注 |
| 🦊 **狐狸** | 平衡型 | 45% | 中等 | 难以捉摸，策略性强 |
| 🦈 **鲨鱼** | 位置型 | 45% | 高 | 利用位置，收割松鱼 |
| 👩‍🏫 **艾米** | GTO型 | 50% | 中等 | 数学驱动，最优策略 |
| 😤 **大卫** | 情绪型 | 动态 | 动态 | 情绪化玩家，可能上头 |

### 🧠 高级 AI 系统
- 蒙特卡洛模拟计算胜率
- ICM（独立筹码模型）锦标赛策略
- 基于位置的战略调整
- 对手建模和画像
- 诈唬频率和时机优化

### 📊 数据统计
- 手牌数统计
- 位置胜率
- VPIP/PFR 追踪
- 对局历史
- 表现图表
- 现金桌盈亏追踪
- 会话时长和统计数据

---

## 🛠 技术栈

| 层级 | 技术 |
|------|------|
| **语言** | Swift 5.9+ |
| **UI 框架** | SwiftUI (iOS 15+) |
| **状态管理** | Combine + ObservableObject |
| **架构** | MVVM + 有限状态机 |
| **持久化** | Core Data + UserDefaults |
| **测试** | XCTest |

---

## 📁 项目结构

```
TexasPoker/
├── App/
│   └── TexasPokerApp.swift          # 应用入口
│
├── Core/
│   ├── AI/
│   │   ├── AIProfile.swift          # AI 个性定义
│   │   ├── DecisionEngine.swift      # AI 决策引擎
│   │   ├── BluffDetector.swift      # 诈唬概率
│   │   ├── ICMCalculator.swift      # 锦标赛 equity
│   │   ├── MonteCarloSimulator.swift # 胜率计算
│   │   ├── OpponentModeler.swift    # 对手画像
│   │   ├── RangeAnalyzer.swift      # 手牌范围分析
│   │   └── DifficultyManager.swift   # AI 难度等级
│   │
│   ├── Data/
│   │   ├── PersistenceController.swift # Core Data 栈
│   │   ├── StatisticsCalculator.swift  # 统计计算
│   │   ├── ProfileManager.swift        # 玩家档案管理
│   │   ├── DataMigrationManager.swift  # 架构迁移
│   │   ├── ActionRecorder.swift       # 对局记录
│   │   └── DataExporter.swift         # 导出功能
│   │
│   ├── Engine/
│   │   ├── PokerEngine.swift            # 主游戏循环
│   │   ├── HandEvaluator.swift          # 牌力评估
│   │   ├── BettingManager.swift         # 下注逻辑
│   │   ├── DealingManager.swift         # 发牌管理
│   │   ├── ShowdownManager.swift        # 胜负判定
│   │   ├── TournamentManager.swift      # 锦标赛逻辑
│   │   ├── CashGameManager.swift        # 现金桌逻辑
│   │   ├── GameResultsManager.swift     # 结果计算
│   │   └── TiltManager.swift            # 情绪追踪
│   │
│   ├── FSM/
│   │   ├── GameState.swift           # 状态定义
│   │   ├── GameEvent.swift           # 游戏事件
│   │   └── PokerGameStore.swift      # 状态机
│   │
│   ├── Models/
│   │   ├── Card.swift                # 扑克牌模型
│   │   ├── Deck.swift               # 牌组管理
│   │   ├── Player.swift             # 玩家基类
│   │   ├── HumanPlayer.swift        # 人类玩家
│   │   ├── AIPlayer.swift           # AI 玩家
│   │   ├── Pot.swift                # 底池模型
│   │   ├── ActionLogEntry.swift     # 动作记录
│   │   ├── BlindLevel.swift         # 盲注结构
│   │   ├── GameRecord.swift         # 对局记录
│   │   ├── GameSettings.swift       # 游戏设置
│   │   ├── GameMode.swift           # 游戏模式枚举
│   │   ├── TournamentConfig.swift   # 锦标赛配置
│   │   ├── CashGameConfig.swift     # 现金桌配置
│   │   ├── CashGameSession.swift    # 现金桌会话
│   │   └── 更多模型...
│   │
│   └── Utils/
│       ├── ColorTheme.swift          # UI 主题
│       ├── DeviceHelper.swift        # 设备适配
│       └── Constants.swift           # 常量定义
│
├── UI/
│   ├── Components/
│   │   ├── CardView.swift          # 扑克牌视图
│   │   ├── ChipStackView.swift     # 筹码堆显示
│   │   , FlippingCard.swift      # 翻牌动画
│   │   └── ActionButtons.swift     # 操作按钮
│   │
│   └── Views/
│       ├── GameTableView.swift      # 主牌桌视图
│       ├── PlayerView.swift         # 玩家信息
│       , ControlPanel.swift       # 控制面板
│       ├── SettingsView.swift       # 设置页面
│       ├── StatisticsView.swift     # 统计面板
│       , EnhancedStatisticsView.swift # 增强统计面板
│       ├── RankingsView.swift      # 排行榜
│       └── GameSubviews/          # 子组件
│           ├── GameTopBar.swift
│           ├── GamePotDisplay.swift
│           ├── GameHeroControls.swift
│           ├── GameActionLogPanel.swift
│           ├── GameTournamentInfo.swift
│           ├── BuyInView.swift
│           ├── TopUpView.swift
│           ├── LeaveTableButton.swift
│           └── CashSessionSummaryView.swift
│
├── Resources/
│   ├── Assets.xcassets
│   ├── Sounds/
│   └── Data/
│
└── TexasPokerTests/
    ├── Core/
    │   └── Engine/
    │       ├── HandEvaluatorTests.swift
    │       └── PokerEngineTests.swift
    ├── UI/
    │   ├── ColorThemeTests.swift
    │   └── GameViewLayoutTests.swift
    ├── CashGameConfigTests.swift
    ├── CashGameManagerTests.swift
    ├── CashGameSessionTests.swift
    └── UncalledBetTests.swift
```

---

## 🚀 快速开始

### 环境要求
- macOS 14+ 或 macOS 15+（推荐 Apple Silicon）
- Xcode 15+
- iOS 15.0+ 模拟器或真机

### 安装运行

```bash
# 克隆项目
git clone https://github.com/woneway/ios-poker-game.git
cd ios-poker-game

# 用 Xcode 打开
open TexasPoker.xcodeproj

# 选择模拟器，按 Cmd+R 运行
```

### 命令行构建

```bash
xcodebuild -project TexasPoker.xcodeproj \
           -scheme TexasPoker \
           -destination 'platform=iOS Simulator,name=iPhone 15' \
           -configuration Debug \
           build
```

---

## 📖 使用说明

### 开始游戏
1. 启动应用
2. 选择游戏模式（现金桌 / 锦标赛）
3. 选择对手（1-7 个 AI）
4. 设置买入金额
5. 点击"发牌"开始

### 游戏操作
- **过牌 (Check)**: 无下注时可用
- **跟注 (Call)**: 匹配当前下注
- **加注 (Raise)**: 增加下注金额
- **弃牌 (Fold)**: 放弃当前手牌
- **全下 (All-IN)**: 投入全部筹码

### AI 自定义
每个 AI 对手都可以自定义：
- 个性画像
- 初始筹码
- 难度等级
- 头像选择

---

## 🧪 测试

```bash
# 运行所有测试
xcodebuild test -project TexasPoker.xcodeproj \
                -scheme TexasPoker \
                -destination 'platform=iOS Simulator,name=iPhone 15'

# 运行特定测试类
xcodebuild test -project TexasPoker.xcodeproj \
                -scheme TexasPoker \
                -destination 'platform=iOS Simulator,name=iPhone 15' \
                -only-testing:TexasPokerTests/Core/Engine/HandEvaluatorTests
```

---

## 📈 架构设计

### 状态机
```
┌─────────────────────────────────────────────────────────┐
│                    游戏状态                              │
├─────────────────────────────────────────────────────────┤
│  idle → preFlop → flop → turn → river → showdown      │
│    ↑                                                     │
│    └───循环 (新的一手牌)                                 │
└─────────────────────────────────────────────────────────┘
```

### 决策流程
```
玩家操作
    ↓
游戏上下文（底池、位置、手牌强度）
    ↓
AI 决策引擎
    ├── 计算手牌强度（蒙特卡洛）
    ├── 计算底池赔率
    ├── 应用个性调整
    └── 选择动作（加权随机）
    ↓
执行动作
```

---

## 📱 截图

<div align="center">

| 游戏界面 | 玩家视图 | 统计数据 |
|:--------:|:--------:|:--------:|
| 🃏 牌桌 | 👤 玩家 | 📊 统计 |

</div>

---

## 🤝 贡献

欢迎贡献！请提交 Pull Request。

1. Fork 本项目
2. 创建分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m '添加新功能'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

---

## 📄 许可证

本项目基于 MIT 许可证开源 - 查看 [LICENSE](LICENSE) 文件了解详情。

---

## 🙏 致谢

- [SwiftUI](https://developer.apple.com/swiftui/) - Apple 现代 UI 框架
- [Combine](https://developer.apple.com/documentation/combine/) - 响应式编程框架
- [XCTest](https://developer.apple.com/documentation/xctest/) - 测试框架

---

<div align="center">

**用 ❤️ 制作 by Poker AI 团队**

</div>
