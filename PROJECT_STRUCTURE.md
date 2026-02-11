# iOS Poker Game - 项目结构说明

## 📁 目录结构

```
ios-poker-game/
├── README.md                    # 项目完整开发计划书
├── PROJECT_STRUCTURE.md         # 本文档
├── .gitignore                   # Git 忽略配置
│
├── TexasPoker/                  # ✅ 主源代码目录（唯一的代码来源）
│   ├── App/                     # 应用入口
│   │   └── TexasPokerApp.swift
│   │
│   ├── Core/                    # 核心逻辑
│   │   ├── AI/                  # AI 系统
│   │   │   ├── AIProfile.swift           # AI 画像
│   │   │   ├── DecisionEngine.swift      # 决策引擎
│   │   │   ├── MonteCarloSimulator.swift # 蒙特卡洛模拟
│   │   │   ├── DifficultyManager.swift   # 难度管理（动态调整）
│   │   │   ├── OpponentModeler.swift     # 对手建模
│   │   │   ├── OpponentModel.swift       # 对手模型
│   │   │   ├── RangeAnalyzer.swift       # 范围分析
│   │   │   ├── BluffDetector.swift       # 诈唬检测
│   │   │   └── ICMCalculator.swift       # ICM 计算器
│   │   │
│   │   ├── Data/                # 数据持久化
│   │   │   ├── PersistenceController.swift      # Core Data 控制器
│   │   │   ├── ActionRecorder.swift             # 行动记录器
│   │   │   ├── StatisticsCalculator.swift       # 统计计算器
│   │   │   ├── DataExporter.swift               # 数据导出
│   │   │   └── DataMigrationManager.swift       # 数据迁移
│   │   │
│   │   ├── Engine/              # 游戏引擎
│   │   │   ├── PokerEngine.swift         # 主引擎
│   │   │   ├── BettingManager.swift      # 下注管理
│   │   │   ├── DealingManager.swift      # 发牌管理
│   │   │   ├── ShowdownManager.swift     # 摊牌管理
│   │   │   ├── Evaluator/
│   │   │   │   └── HandEvaluator.swift   # 牌力评估
│   │   │   └── FSM/
│   │   │       ├── GameState.swift       # 游戏状态
│   │   │       ├── GameEvent.swift       # 游戏事件
│   │   │       └── PokerGameStore.swift  # 游戏状态存储
│   │   │
│   │   ├── Models/              # 数据模型
│   │   │   ├── Card.swift
│   │   │   ├── Deck.swift
│   │   │   ├── Player.swift
│   │   │   ├── PlayerAction.swift
│   │   │   ├── Pot.swift
│   │   │   ├── Street.swift
│   │   │   ├── GameRecord.swift
│   │   │   ├── GameMode.swift
│   │   │   ├── BlindLevel.swift
│   │   │   └── TournamentConfig.swift
│   │   │
│   │   └── Utils/               # 工具类
│   │       ├── PokerUtils.swift
│   │       └── SoundManager.swift
│   │
│   ├── UI/                      # 用户界面
│   │   ├── Views/
│   │   │   ├── GameView.swift
│   │   │   ├── CardView.swift
│   │   │   ├── PlayerView.swift
│   │   │   ├── ChipView.swift
│   │   │   ├── HistoryView.swift
│   │   │   ├── RankingsView.swift
│   │   │   ├── SettingsView.swift
│   │   │   └── StatisticsView.swift
│   │   ├── GameTable/
│   │   │   ├── PokerTableScene.swift
│   │   │   └── CardNode.swift
│   │   └── Components/
│   │       └── PlayerHUD.swift
│   │
│   ├── Assets.xcassets/         # 资源文件
│   └── TexasPokerApp.xcdatamodeld/  # Core Data 模型
│
├── TexasPokerTests/             # 单元测试
│   ├── PokerEngineTests.swift
│   ├── HandEvaluatorTests.swift
│   ├── BettingLogicTests.swift
│   ├── ShowdownLogicTests.swift
│   ├── PotCalculationTests.swift
│   ├── GameStoreTests.swift
│   ├── PokerUtilsTests.swift
│   ├── DecisionEngineTests.swift
│   ├── StatisticsTests.swift
│   ├── TournamentTests.swift
│   ├── DifficultyManagerTests.swift    # 难度管理测试
│   ├── OpponentModelerTests.swift      # 对手建模测试
│   ├── RangeAnalyzerTests.swift        # 范围分析测试
│   ├── BluffDetectorTests.swift        # 诈唬检测测试
│   └── ICMCalculatorTests.swift        # ICM 计算器测试
│
├── docs/                        # 文档目录
│   ├── TASK2_IMPLEMENTATION_REPORT.md  # Task2 实现报告
│   ├── TASK4_IMPLEMENTATION_REPORT.md  # Task4 实现报告
│   ├── TASK5_IMPLEMENTATION_REPORT.md  # Task5 实现报告
│   └── TASK7_IMPLEMENTATION_REPORT.md  # Task7 实现报告
│
└── archive/                     # 归档的临时文件
    ├── poker_sim                # 模拟测试脚本
    ├── poker_tests              # 测试脚本
    ├── main.swift               # 临时主文件
    ├── test_logic.swift         # 测试逻辑
    ├── verify_icm.swift         # ICM 验证脚本
    ├── verify_task4.swift       # Task4 验证脚本
    └── verify_task5.swift       # Task5 验证脚本
```

## 🎯 重要说明

### ✅ 唯一的源代码目录
**`TexasPoker/`** 是项目的唯一源代码目录，所有开发和修改都应该在这个目录下进行。

### ❌ 已删除的目录
以下目录已被删除，不再使用：
- `TexasPokerApp/` - 不完整的项目副本
- `TexasPokerApp_backup_r2/` - 旧备份
- `backup/` - 另一个旧备份

### 📦 归档目录
`archive/` 目录包含临时测试脚本和验证文件，这些文件已完成使命，但保留以供参考。

### 📄 文档目录
`docs/` 目录包含各个任务的实现报告，记录了开发过程和技术细节。

## 🚀 已实现的功能

### Task 2: 统计系统
- ✅ Core Data 持久化
- ✅ 行动记录器
- ✅ 统计计算器
- ✅ 数据导出功能
- ✅ 统计页面 UI

### Task 4: 对手建模系统
- ✅ 对手风格分类（TAG/LAG/TP/LP）
- ✅ 行动模式跟踪
- ✅ 策略自适应调整
- ✅ 翻牌后范围收窄

### Task 5: 诈唬检测系统
- ✅ 多维度信号分析
- ✅ 诈唬概率计算
- ✅ 决策引擎集成

### Task 7: 难度系统
- ✅ 动态难度调整
- ✅ 基于玩家胜率的 AI 强度调整
- ✅ 平滑过渡机制

### 锦标赛模式增强
- ✅ ICM 计算器
- ✅ 泡沫期策略调整
- ✅ 筹码压力感知

## 📝 开发指南

### 修改代码时
1. 所有代码修改都在 `TexasPoker/` 目录下进行
2. 不要在其他目录创建新的源代码文件
3. 添加新功能时，遵循现有的目录结构

### 添加测试时
1. 测试文件放在 `TexasPokerTests/` 目录
2. 测试文件命名规范：`<功能名>Tests.swift`
3. 使用 XCTest 框架

### 编写文档时
1. 实现报告放在 `docs/` 目录
2. 使用 Markdown 格式
3. 包含功能说明、技术细节和测试结果

## 🔧 项目配置

### Xcode 项目文件
- 项目文件位置：需要创建或更新
- 目标平台：iOS 15+
- 开发语言：Swift 5.9+
- UI 框架：SwiftUI

### 依赖管理
- 无第三方依赖
- 使用系统框架：SwiftUI, Combine, Core Data, AVFoundation

## 📊 代码统计

- 核心 AI 模块：9 个文件
- 数据持久化：5 个文件
- 游戏引擎：7 个文件
- 数据模型：10 个文件
- UI 组件：11 个文件
- 单元测试：15 个文件

总计：**57+ 个 Swift 文件**
