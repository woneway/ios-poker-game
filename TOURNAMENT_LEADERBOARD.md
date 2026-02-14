# 锦标赛实时排名统计

## 📊 功能概述

实时追踪锦标赛中的玩家排名、筹码变化和关键事件。

---

## 🎯 主要功能

### 1. 实时排行榜
- **排名变化指示** - 显示与上一手牌相比的排名变化（上升/下降）
- **筹码趋势** - 显示相对于起始筹码的盈亏百分比
- **状态标识** - 实时显示玩家状态（活跃/All-in/已淘汰）
- **前三名特殊标识** - 金/银/铜奖牌样式

### 2. 三种排序方式
- **按筹码排序** - 默认，实时筹码量排名
- **按排名排序** - 最终排名（考虑淘汰顺序）
- **按淘汰顺序** - 查看淘汰时间线

### 3. 锦标赛进度追踪
- **进度条** - 可视化显示比赛进度
- **泡沫指示** - 标记奖金圈边界位置
- **剩余人数** - 实时显示存活玩家数量
- **奖池金额** - 显示总奖池

### 4. 统计数据
- **平均筹码** - 计算存活玩家的平均筹码
- **最大/最小筹码** - 筹码分布 extremes
- **排名变动** - 显示最近变化最大的玩家

### 5. 关键时刻记录
- **进入决赛桌** - 9人剩余时触发
- **进入单挑** - 2人剩余时触发
- **泡沫破裂** - 奖金圈形成时触发
- **冠军产生** - 比赛结束时触发

### 6. 淘汰历史
- **淘汰顺序** - 完整记录淘汰时间线
- **淘汰时筹码** - 记录淘汰时的剩余筹码
- **存活玩家** - 实时更新存活名单

---

## 📱 界面组件

### TournamentLeaderboardView
主要排行榜视图，包含：
- 排名列表（实时更新）
- 筹码统计摘要
- 排序选项
- 淘汰/存活筛选

### TournamentProgressView
进度追踪视图，包含：
- 可视化进度条
- 泡沫指示器
- 剩余人数统计
- 奖池信息

### TournamentLeaderboardOverlay
全屏覆盖层，包含三个标签页：
1. **排行榜** - 实时排名列表
2. **进度** - 关键时刻、排名变动、筹码分布
3. **历史** - 淘汰记录、排名历史

---

## 🔧 使用方法

### 在游戏界面中显示
排行榜按钮已集成到 GameTopBar：
- 仅在锦标赛模式显示
- 点击后弹出 TournamentLeaderboardOverlay

### 数据更新
每手牌结束时自动更新：
```swift
.onChangeCompat(of: store.engine.isHandOver) { isOver in
    if isOver {
        if store.engine.gameMode == .tournament {
            TournamentStatsManager.shared.updateAfterHand(
                handNumber: store.engine.handNumber,
                players: store.engine.players,
                engine: store.engine
            )
        }
    }
}
```

### 获取统计数据
```swift
// 获取当前排名
let rankings = TournamentStatsManager.shared.currentRankings

// 获取排名变动
let change = TournamentStatsManager.shared.rankChange(for: playerId, overHands: 5)

// 获取筹码趋势
let trend = TournamentStatsManager.shared.chipTrendData(for: playerId)

// 获取锦标赛摘要
let summary = TournamentStatsManager.shared.tournamentSummary()
```

---

## 📁 新增文件

```
TexasPoker/
├── UI/Views/
│   ├── TournamentLeaderboardView.swift       # 主排行榜视图
│   ├── TournamentLeaderboardOverlay.swift    # 全屏覆盖层
│   └── GameSubviews/GameTopBar.swift         # 更新：添加排行榜按钮
├── Core/Data/
│   └── TournamentStatsManager.swift          # 统计管理器
└── TOURNAMENT_LEADERBOARD.md                 # 本文档
```

---

## 🎮 下一步集成

1. **图表可视化** - 在"历史"标签页添加排名变化折线图
2. **导出功能** - 导出锦标赛报告
3. **分享功能** - 分享排名截图
4. **详细统计** - 添加 VPIP、PFR 等详细数据到排行榜

---

## 📊 数据结构

### PlayerRanking
```swift
struct PlayerRanking {
    let playerId: UUID
    let name: String
    let avatar: String
    let chips: Int
    let rank: Int
    let change: Int      // 排名变化（正数=上升）
    let isHero: Bool
    let isEliminated: Bool
    let eliminationHand: Int?
}
```

### TournamentMoment
```swift
struct TournamentMoment {
    enum MomentType {
        case doubleUp
        case badBeat
        case bubbleBurst
        case finalTable
        case headsUp
        case champion
    }
    
    let type: MomentType
    let handNumber: Int
    let description: String
    let playerName: String
    let chips: Int?
}
```