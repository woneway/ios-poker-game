# Proposal: 修复AI玩家重复问题

## 问题描述

现金游戏中，牌桌上出现了两个相同的AI玩家（如两个"疯子麦克"同时在桌）。

## 根本原因

`CashGameManager.generateRandomAIPlayer` 函数会随机生成一个新的AI玩家profile，这违反了业务规则：
- AIProfile 和 AI玩家是一一对应的
- 游戏过程中不产生"新玩家"，只有"已有玩家重新买入进场"

## 目标

- 删除 `generateRandomAIPlayer` 随机生成逻辑
- 仅使用 `findRejoinableAIPlayer` 让已有AI玩家重新加入
- 确保牌桌上不会出现重复的AI玩家

## 价值

- 符合游戏业务逻辑
- 避免UI显示混乱
- 确保统计数据正确归到对应玩家
