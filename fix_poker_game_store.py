#!/usr/bin/env python3
import re

# Read the file
with open('TexasPoker/Core/Engine/FSM/PokerGameStore.swift', 'r') as f:
    content = f.read()

# Add logger declaration after the class opening
content = content.replace(
    'class PokerGameStore: ObservableObject {\n    @Published',
    'class PokerGameStore: ObservableObject {\n    private let logger = AppLogger.shared\n\n    @Published'
)

# Define replacements - map from print to logger
# Format: (print_pattern, replacement)
replacements = [
    # Inside #if DEBUG blocks - replace with logger.debug
    (r'print\("⚠️ Engine isHandOver is already true at subscription time!"\)', 'logger.warning("Engine isHandOver is already true at subscription time!", category: .game)'),
    (r'print\("⚠️ HandOver Watchdog: engine\.isHandOver is true but state is \$\(self\.state\)\. Forcing transition to showdown\."\)', 'logger.warning("HandOver Watchdog: engine.isHandOver is true but state is \\(self.state). Forcing transition to showdown.", category: .game)'),
    (r'print\("⚠️ HandOver Watchdog: No active players and engine\.isHandOver is true\. Forcing transition to showdown\."\)', 'logger.warning("HandOver Watchdog: No active players and engine.isHandOver is true. Forcing transition to showdown.", category: .game)'),
    (r'print\("🔍 Poll: state=\$\(self\.state\), activeIdx=\$\(self\.engine\.activePlayerIndex\), isHumanTurn=\$\(isHuman\)"\)', 'logger.debug("Poll: state=\\(self.state), activeIdx=\\(self.engine.activePlayerIndex), isHumanTurn=\\(isHuman)", category: .game)'),
    (r'print\("   ActivePlayer: \$\(player\.name\), status=\$\(player\.status\), isHuman=\$\(player\.isHuman\)"\)', 'logger.debug("ActivePlayer: \\(player.name), status=\\(player.status), isHuman=\\(player.isHuman)", category: .game)'),
    (r'print\("✅ Poll detected human turn, switching to waitingForAction"\)', 'logger.debug("Poll detected human turn, switching to waitingForAction", category: .game)'),
    (r'print\("⚠️ AI Watchdog: Kicking engine to check bot turn\. ActiveIdx=\$\(self\.engine\.activePlayerIndex\)"\)', 'logger.warning("AI Watchdog: Kicking engine to check bot turn. ActiveIdx=\\(self.engine.activePlayerIndex)", category: .game)'),
    (r'print\("⚠️ AI Watchdog: It IS human turn but state is \.betting\. Forcing switch\."\)', 'logger.warning("AI Watchdog: It IS human turn but state is .betting. Forcing switch.", category: .game)'),
    (r'print\("FSM: Event=\$\(event\), State=\$\(state\)"\)', 'logger.debug("FSM: Event=\\(event), State=\\(state)", category: .game)'),
    (r'print\("📊 \.idle -> \.start: 调用 recordHeroChipsAtHandStart, handNumber=\$\(engine\.handNumber\)"\)', 'logger.debug(".idle -> .start: 调用 recordHeroChipsAtHandStart, handNumber=\\(engine.handNumber)", category: .game)'),
    (r'print\("📊 \.betting -> \.handOver: 调用 recordHandProfit, handNumber=\$\(engine\.handNumber\)"\)', 'logger.debug(".betting -> .handOver: 调用 recordHandProfit, handNumber=\\(engine.handNumber)", category: .game)'),
    (r'print\("📊 \.waitingForAction -> \.handOver: 调用 recordHandProfit, handNumber=\$\(engine\.handNumber\)"\)', 'logger.debug(".waitingForAction -> .handOver: 调用 recordHandProfit, handNumber=\\(engine.handNumber)", category: .game)'),
    (r'print\("⏸️ 现金局：hero需要rebuy，暂停游戏"\)', 'logger.info("现金局：hero需要rebuy，暂停游戏", category: .game)'),
    (r'print\("📊 \.showdown -> \.nextHand: 调用 recordHeroChipsAtHandStart, handNumber before startHand=\$\(engine\.handNumber\)"\)', 'logger.debug(".showdown -> .nextHand: 调用 recordHeroChipsAtHandStart, handNumber before startHand=\\(engine.handNumber)", category: .game)'),
    (r'print\("FSM: Invalid transition \$\(state\) \+ \$\(event\) — recovering to safe state"\)', 'logger.error("FSM: Invalid transition \\(state) + \\(event) — recovering to safe state", category: .game)'),
    (r'print\("🚀 开始 AI 后台模拟\.\.\."\)', 'logger.info("开始 AI 后台模拟...", category: .game)'),
    (r'print\("✅ AI 后台模拟完成！"\)', 'logger.info("AI 后台模拟完成！", category: .game)'),
    (r'print\("📊 Batch \$\(batch\)/\$\(totalBatches\) 完成，已模拟 \$\(backgroundHandsPerBatch\) 手牌"\)', 'logger.info("Batch \\(batch)/\\(totalBatches) 完成，已模拟 \\(backgroundHandsPerBatch) 手牌", category: .game)'),
    (r'print\("📊 recordHeroChipsAtHandStart: hero\.chips=\$\(hero\.chips\), handNumber=\$\(engine\.handNumber\)"\)', 'logger.debug("recordHeroChipsAtHandStart: hero.chips=\\(hero.chips), handNumber=\\(engine.handNumber)", category: .game)'),
    (r'print\("📊 resetHeroChipsAtHandStart: hero\.chips=\$\(hero\.chips\) \(after rebuy\)"\)', 'logger.debug("resetHeroChipsAtHandStart: hero.chips=\\(hero.chips) (after rebuy)", category: .game)'),
    (r'print\("📊 recordHandProfit: 开始, gameMode=\$\(engine\.gameMode\)"\)', 'logger.debug("recordHandProfit: 开始, gameMode=\\(engine.gameMode)", category: .game)'),
    (r'print\("📊 recordHandProfit: guard failed - not cashGame"\)', 'logger.debug("recordHandProfit: guard failed - not cashGame", category: .game)'),
    (r'print\("📊 recordHandProfit: guard failed - no hero"\)', 'logger.debug("recordHandProfit: guard failed - no hero", category: .game)'),
    (r'print\("📊 recordHandProfit: 所有玩家 = \$\(engine\.players\.map \{ "\$\(\\\.name\)\(\\\.isHuman\)" \}\)"\)', 'logger.debug("recordHandProfit: 所有玩家 = \\(engine.players.map { "\\($0.name)(\($0.isHuman))" })", category: .game)'),
    (r'print\("📊 recordHandProfit: guard failed - no session"\)', 'logger.debug("recordHandProfit: guard failed - no session", category: .game)'),
    (r'print\("📊 recordHandProfit: hero\.chips=\$\(hero\.chips\), heroChipsAtHandStart=\$\(heroChipsAtHandStart\), profit=\$\(profit\), handNumber=\$\(engine\.handNumber\)"\)', 'logger.debug("recordHandProfit: hero.chips=\\(hero.chips), heroChipsAtHandStart=\\(heroChipsAtHandStart), profit=\\(profit), handNumber=\\(engine.handNumber)", category: .game)'),
    (r'print\("💰 Hero被淘汰，检查是否可以rebuy"\)', 'logger.info("Hero被淘汰，检查是否可以rebuy", category: .game)'),
    (r'print\("🎯 达到总买入限制 \$\(session\.maxBuyIns\)，无法rebuy，结束游戏"\)', 'logger.info("达到总买入限制 \\(session.maxBuyIns)，无法rebuy，结束游戏", category: .game)'),
    (r'print\("💰 Hero被淘汰，显示rebuy界面"\)', 'logger.info("Hero被淘汰，显示rebuy界面", category: .game)'),
    (r'print\("🎯 达到总买入限制 \$\(session\.maxBuyIns\)，游戏将继续直到所有玩家离开"\)', 'logger.info("达到总买入限制 \\(session.maxBuyIns)，游戏将继续直到所有玩家离开", category: .game)'),
]

for pattern, replacement in replacements:
    content = re.sub(pattern, replacement, content)

# Write the file
with open('TexasPoker/Core/Engine/FSM/PokerGameStore.swift', 'w') as f:
    f.write(content)

print("Done!")
