# Design: 修复AI玩家重复问题

## 方案

### 修改 `checkAIEntries` 函数

当前逻辑：
1. 尝试 `findRejoinableAIPlayer` 重新加入已有玩家
2. 如果没有可重新加入的，调用 `generateRandomAIPlayer` 生成新玩家 ← **问题所在**

修改后的逻辑：
1. 尝试 `findRejoinableAIPlayer` 重新加入已有玩家
2. 如果没有可重新加入的玩家，**不生成新玩家**，直接返回空列表

### 删除 `generateRandomAIPlayer` 函数

完全移除此函数，因为业务上不需要"生成新玩家"。

### 保留 `findRejoinableAIPlayer` 函数

此函数逻辑正确，遍历所有预设AI玩家，检查是否有bankroll且不在当前游戏中。

## 改动文件

- `CashGameManager.swift`
  - 删除 `generateRandomAIPlayer` 函数
  - 修改 `checkAIEntries` 函数，移除对新玩家生成的调用

## 边界情况

- 如果所有AI玩家都已入桌且没有空位：不产生新玩家
- 如果所有AI玩家都没有足够bankroll：不产生新玩家
- 如果只有部分AI玩家在桌上：优先让离场玩家重新加入
