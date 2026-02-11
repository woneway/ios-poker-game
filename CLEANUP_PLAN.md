# iOS Poker Game 目录整理方案

## 当前状态分析

### ✅ 保留目录
- **TexasPoker/** - 主要源代码目录（git 追踪）
  - 包含所有最新功能实现
  - AI 系统完整
  - 数据持久化完整
  - 游戏引擎完整

- **TexasPokerTests/** - 测试目录
  - 部分测试文件已追踪
  - 新增测试文件待添加

### ❌ 删除目录
- **TexasPokerApp/** - 不完整的项目副本
- **TexasPokerApp_backup_r2/** - 旧备份
- **backup/** - 另一个旧备份

### 📦 归档文件
移动到 `archive/` 目录：
- poker_sim - 临时模拟脚本
- poker_tests - 临时测试脚本
- main.swift - 临时主文件
- test_logic.swift - 测试逻辑
- verify_icm.swift - ICM 验证脚本
- verify_task4.swift - Task4 验证脚本
- verify_task5.swift - Task5 验证脚本

### 📄 文档整理
移动到 `docs/` 目录：
- TASK2_IMPLEMENTATION_REPORT.md
- TASK4_IMPLEMENTATION_REPORT.md
- TASK5_IMPLEMENTATION_REPORT.md
- TASK7_IMPLEMENTATION_REPORT.md

## 执行步骤

1. 创建归档目录
2. 移动临时脚本到归档
3. 移动文档到 docs
4. 删除无用的备份目录
5. 提交新增的测试文件到 git
6. 更新 .gitignore

## 最终目录结构

```
ios-poker-game/
├── README.md
├── TexasPoker/              # 主源代码
│   ├── App/
│   ├── Core/
│   ├── UI/
│   └── ...
├── TexasPokerTests/         # 测试代码
├── docs/                    # 文档
│   ├── TASK2_IMPLEMENTATION_REPORT.md
│   ├── TASK4_IMPLEMENTATION_REPORT.md
│   ├── TASK5_IMPLEMENTATION_REPORT.md
│   └── TASK7_IMPLEMENTATION_REPORT.md
└── archive/                 # 归档的临时文件
    ├── poker_sim
    ├── poker_tests
    ├── verify_*.swift
    └── ...
```
