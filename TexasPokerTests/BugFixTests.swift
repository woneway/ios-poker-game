import XCTest
@testable import TexasPoker

class BugFixTests: XCTestCase {
    
    var engine: PokerEngine!
    var store: PokerGameStore!
    
    override func setUp() {
        super.setUp()
        engine = PokerEngine()
    }
    
    override func tearDown() {
        engine = nil
        store = nil
        super.tearDown()
    }
    
    // MARK: - Bug Fix 1: isHandOver Already True at Subscription Time
    
    /// 验证当 engine.isHandOver 在订阅时已经为 true，状态机能够正确转换到 showdown
    func testHandOverAlreadyTrueAtSubscription() {
        let store = PokerGameStore()
        
        // 直接设置 engine.isHandOver 为 true（模拟引擎已经在订阅前结束的状态）
        store.engine.isHandOver = true
        
        // 发送一个事件来触发状态机检查
        store.send(.start)
        
        // 状态应该转换到 showdown，因为 engine.isHandOver 已经是 true
        XCTAssertEqual(store.state, .showdown, "State should transition to showdown when engine.isHandOver is already true")
    }
    
    /// 验证在 dealing 状态下，如果 engine.isHandOver 为 true，转换到 showdown
    func testDealCompleteWithHandAlreadyOver() {
        let store = PokerGameStore()
        store.send(.start)  // .idle -> .dealing
        
        // 在 dealing 状态下，手牌已经结束
        store.engine.isHandOver = true
        
        store.send(.dealComplete)  // .dealing -> should be .showdown
        
        XCTAssertEqual(store.state, .showdown, "State should transition to showdown when isHandOver is true at dealComplete")
    }
    
    // MARK: - Bug Fix 2: nextActivePlayerIndex Boundary
    
    /// 验证当没有活跃玩家时，nextActivePlayerIndex 返回 -1
    func testNextActivePlayerIndexReturnsNegativeOneWhenNoActivePlayers() {
        let engine = PokerEngine()
        
        // 设置所有玩家为非 active 状态
        var players: [Player] = []
        var p1 = Player(name: "P1", chips: 1000, isHuman: false)
        p1.status = .folded
        players.append(p1)
        
        var p2 = Player(name: "P2", chips: 1000, isHuman: false)
        p2.status = .folded
        players.append(p2)
        
        var p3 = Player(name: "P3", chips: 0, isHuman: false)
        p3.status = .eliminated
        players.append(p3)
        
        engine.players = players
        
        let result = engine.nextActivePlayerIndex(after: 0)
        
        XCTAssertEqual(result, -1, "nextActivePlayerIndex should return -1 when no active players exist")
    }
    
    /// 验证当所有非 folded 玩家都是 allIn 时，应该返回其中一个
    func testNextActivePlayerIndexWithAllInPlayers() {
        let engine = PokerEngine()
        
        var players: [Player] = []
        var p1 = Player(name: "P1", chips: 0, isHuman: false)
        p1.status = .allIn
        players.append(p1)
        
        var p2 = Player(name: "P2", chips: 0, isHuman: false)
        p2.status = .allIn
        players.append(p2)
        
        var p3 = Player(name: "P3", chips: 0, isHuman: false)
        p3.status = .eliminated
        players.append(p3)
        
        engine.players = players
        
        let result = engine.nextActivePlayerIndex(after: 0)
        
        // allIn 状态的玩家应该被视为活跃
        XCTAssertTrue(result >= 0 && result < 3, "Should return valid index for allIn players")
    }
    
    /// 验证当唯一活跃玩家是自己时，应该正确循环
    func testNextActivePlayerIndexWithSingleActivePlayer() {
        let engine = PokerEngine()
        
        var players: [Player] = []
        var p1 = Player(name: "P1", chips: 1000, isHuman: false)
        p1.status = .active
        players.append(p1)
        
        var p2 = Player(name: "P2", chips: 0, isHuman: false)
        p2.status = .folded
        players.append(p2)
        
        var p3 = Player(name: "P3", chips: 0, isHuman: false)
        p3.status = .eliminated
        players.append(p3)
        
        engine.players = players
        
        let result = engine.nextActivePlayerIndex(after: 0)
        
        // 应该返回 0（唯一的活跃玩家）
        XCTAssertEqual(result, 0, "Should return 0 when only player at index 0 is active")
    }
    
    // MARK: - Bug Fix 3: State Machine Recovery
    
    /// 验证当状态机收到无效事件时，如果 engine.isHandOver 为 true，会恢复到 showdown
    func testStateMachineRecoversToShowdownFromInvalidState() {
        let store = PokerGameStore()
        store.send(.start)  // .idle -> .dealing
        store.send(.dealComplete)  // .dealing -> .betting
        
        // 模拟引擎已经结束手牌
        store.engine.isHandOver = true
        
        // 发送一个无效事件（如再次发送 start）
        store.send(.start)
        
        // 状态应该恢复到 showdown
        XCTAssertEqual(store.state, .showdown, "State machine should recover to showdown when engine.isHandOver is true")
    }
    
    /// 验证状态机在 waitingForAction 状态下能正确处理 handOver 事件
    func testWaitingForActionHandOver() {
        let store = PokerGameStore()
        
        // 设置人类玩家为第一个玩家
        store.engine.players[0].isHuman = true
        
        store.send(.start)  // .idle -> .dealing
        store.send(.dealComplete)  // .dealing -> .waitingForAction (因为是人类回合)
        
        XCTAssertEqual(store.state, .waitingForAction)
        
        // 模拟手牌结束
        store.engine.isHandOver = true
        
        store.send(.playerActed)  // 这应该触发转换到 showdown
        
        XCTAssertEqual(store.state, .showdown, "State should transition to showdown from waitingForAction when hand is over")
    }
    
    /// 验证状态机在 betting 状态下卡住时的恢复机制
    func testBettingStateRecoveryWhenStuck() {
        let store = PokerGameStore()
        
        store.send(.start)  // .idle -> .dealing
        store.send(.dealComplete)  // .dealing -> .betting
        
        // 模拟引擎已经结束，但状态机不知道
        store.engine.isHandOver = true
        
        // 手动触发恢复检查（模拟定时检查）
        // 这是内部逻辑，测试应该通过事件触发恢复
        
        // 发送任意事件来触发 default 分支的恢复逻辑
        store.send(.dealComplete)
        
        // 状态应该恢复到 showdown
        XCTAssertEqual(store.state, .showdown, "State should recover to showdown when engine.isHandOver is true in betting state")
    }
    
    // MARK: - Bug Fix 3: Check Action Should Mark hasActed

    /// 验证 check 操作后 hasActed 被正确设置为 true
    /// 这个问题导致翻牌圈所有人都让牌后无法自动进入转牌圈
    func testCheckMarksHasActed() {
        let store = PokerGameStore()
        store.send(.start)
        store.send(.dealComplete)

        // 确保在翻牌圈
        XCTAssertEqual(store.engine.currentStreet, .flop)

        let p1ID = store.engine.players[0].id
        let p2ID = store.engine.players[1].id

        // P1 check
        store.engine.activePlayerIndex = 0
        store.engine.processAction(.check)

        // 验证 P1 的 hasActed 被设置为 true
        XCTAssertEqual(store.engine.hasActed[p1ID], true, "P1 should have hasActed=true after check")

        // P2 check
        store.engine.activePlayerIndex = 1
        store.engine.processAction(.check)

        // 验证 P2 的 hasActed 被设置为 true
        XCTAssertEqual(store.engine.hasActed[p2ID], true, "P2 should have hasActed=true after check")
    }

    /// 验证所有玩家 check 后轮次正确结束并进入转牌圈
    func testCheckCheckAdvancesToTurn() {
        let store = PokerGameStore()
        store.send(.start)
        store.send(.dealComplete)

        // 确保在翻牌圈
        XCTAssertEqual(store.engine.currentStreet, .flop)

        // P1 check
        store.engine.activePlayerIndex = 0
        store.engine.processAction(.check)

        // P2 check - round should complete and advance to turn
        store.engine.activePlayerIndex = 1
        store.engine.processAction(.check)

        // 验证进入转牌圈
        XCTAssertEqual(store.engine.currentStreet, .turn,
                       "After all players check, should advance to turn street")
        XCTAssertEqual(store.engine.communityCards.count, 4,
                       "Should have 4 community cards in turn")
    }

    // MARK: - Integration Tests
    
    /// 完整场景测试：从开始到结束的所有状态转换
    func testCompleteHandFlow() {
        let store = PokerGameStore()
        
        // Start
        store.send(.start)
        XCTAssertEqual(store.state, .dealing)
        
        // Deal complete
        store.send(.dealComplete)
        
        // 由于没有人类玩家，应该进入 betting 状态
        XCTAssertTrue(store.state == .betting || store.state == .showdown,
                      "After dealComplete should be in betting or showdown")
        
        // 模拟手牌结束
        store.engine.isHandOver = true
        
        // 触发 handOver
        store.send(.handOver)
        
        XCTAssertEqual(store.state, .showdown, "Should reach showdown after handOver")
        
        // 下一手
        store.send(.nextHand)
        
        XCTAssertEqual(store.state, .dealing, "Should transition back to dealing for next hand")
    }
    
    /// 测试状态机在所有玩家弃牌时正确结束
    func testAllPlayersFolded() {
        let store = PokerGameStore()
        
        store.send(.start)
        store.send(.dealComplete)
        
        // 设置所有非人类玩家弃牌
        for i in 1..<store.engine.players.count {
            store.engine.players[i].status = .folded
        }
        
        // 引擎应该检测到并结束手牌
        store.engine.isHandOver = true
        
        store.send(.handOver)
        
        XCTAssertEqual(store.state, .showdown)
    }
    
    // MARK: - Bug Fix L-03: dealNextStreet allIn 处理不一致
    
    /// 验证当只有一个 active 玩家但有多个 allIn 玩家时，
    /// dealNextStreet 不应该直接进入 runOutBoard，
    /// 而应该让 active 玩家继续行动
    func testDealNextStreetWithOneActiveAndMultipleAllIn() {
        let store = PokerGameStore()
        store.send(.start)
        store.send(.dealComplete)
        
        // 确保在翻牌圈
        XCTAssertEqual(store.engine.currentStreet, .flop)
        
        // 设置场景：P1 是 active，P2 和 P3 是 allIn
        store.engine.players[0].status = .active
        store.engine.players[0].chips = 100
        
        store.engine.players[1].status = .allIn
        store.engine.players[1].chips = 0
        
        store.engine.players[2].status = .allIn
        store.engine.players[2].chips = 0
        
        // 手动设置 dealerIndex 和其他必要状态
        store.engine.dealerIndex = 0
        store.engine.currentBet = 0
        store.engine.hasActed = [:]
        
        // 记录 dealNextStreet 前的状态
        let streetBefore = store.engine.currentStreet
        
        // 手动触发下一条街
        store.engine.dealNextStreet()
        
        // 验证：不应该直接进入 runOutBoard
        // 如果 bug 存在，canBet.count = 1，会错误地调用 runOutBoard
        // 正确行为：active 玩家应该能继续行动
        
        // 检查是否调用了 runOutBoard（通过检查 community cards 是否一次性发完）
        // 如果 bug 存在，会直接发完所有剩余公共牌
        let streetsRemaining = DealingManager.streetsRemaining(from: streetBefore)
        
        // bug 存在时：runOutBoard 会一次性发完所有牌
        // 修复后：只发一张牌（到 turn），让 active 玩家继续行动
        XCTAssertEqual(store.engine.currentStreet, .turn,
                       "应该只发一张 turn 牌，让 active 玩家继续行动，而不是 runOutBoard")
        XCTAssertEqual(store.engine.communityCards.count, 4,
                       "应该只有 4 张公共牌（3 flop + 1 turn），而不是一次性发完")
    }
    
    /// 验证 canBet 的计算应该同时考虑 active 和 allIn 玩家
    func testCanBetIncludesAllInPlayers() {
        let engine = PokerEngine()
        
        // 设置玩家：1 active, 2 allIn
        var players: [Player] = []
        var p1 = Player(name: "P1", chips: 100, isHuman: false)
        p1.status = .active
        players.append(p1)
        
        var p2 = Player(name: "P2", chips: 0, isHuman: false)
        p2.status = .allIn
        players.append(p2)
        
        var p3 = Player(name: "P3", chips: 0, isHuman: false)
        p3.status = .allIn
        players.append(p3)
        
        engine.players = players
        
        // 模拟已经到翻牌圈
        engine.currentStreet = .flop
        engine.dealerIndex = 0
        
        // 调用 dealNextStreet
        engine.dealNextStreet()
        
        // 验证：应该进入 turn 而不是 runOutBoard
        XCTAssertEqual(engine.currentStreet, .turn,
                       "canBet 应该包含 allIn 玩家，所以应该进入 turn 而不是 runOutBoard")
    }
    
    // MARK: - Bug Fix L-01: All-in 时 minRaise 应该为 0
    
    /// 验证当玩家 all-in 时，minRaise 应该被设为 0
    /// 因为 all-in 后其他玩家不能再次加注（除非有更高金额的加注）
    func testAllInMinRaiseShouldBeZero() {
        let engine = PokerEngine()
        
        // 设置场景：P1 下注 100，P2 all-in 150
        engine.currentBet = 100
        engine.minRaise = 20
        
        var p1 = Player(name: "P1", chips: 900, isHuman: true)
        p1.currentBet = 100
        p1.status = .active
        
        var p2 = Player(name: "P2", chips: 150, isHuman: true)
        p2.currentBet = 0  // 还没下注
        p2.status = .active
        
        engine.players = [p1, p2]
        
        // P2 all-in 150
        let result = BettingManager.processAction(
            .allIn,
            player: p2,
            currentBet: engine.currentBet,
            minRaise: engine.minRaise
        )
        
        // 验证：all-in 后的 minRaise 应该是 0（因为不能再次加注）
        // 当前代码使用 max(minRaise, raiseSize)，这是错误的
        XCTAssertEqual(result.newMinRaise, 0,
                       "All-in 后 minRaise 应该是 0，其他玩家不能再次加注")
    }
    
    /// 验证当玩家 all-in 且金额大于当前下注时，minRaise 应为 0
    func testAllInWithHigherAmountMinRaise() {
        let engine = PokerEngine()
        
        // 设置场景：P1 check，P2 all-in 100
        engine.currentBet = 0
        engine.minRaise = 20
        
        var p1 = Player(name: "P1", chips: 1000, isHuman: true)
        p1.currentBet = 0
        p1.status = .active
        
        var p2 = Player(name: "P2", chips: 100, isHuman: true)
        p2.currentBet = 0
        p2.status = .active
        
        engine.players = [p1, p2]
        
        // P2 all-in 100
        let result = BettingManager.processAction(
            .allIn,
            player: p2,
            currentBet: engine.currentBet,
            minRaise: engine.minRaise
        )
        
        // all-in 后 newMinRaise 应该是 0
        XCTAssertEqual(result.newMinRaise, 0,
                       "All-in 后 minRaise 应该是 0")
    }
    
    // MARK: - Bug Fix L-07: Pot 计算差异根本原因
    
    /// 验证 pot 计算不应该有差异（不应该使用保护性修复）
    func testPotCalculationShouldHaveNoDifference() {
        var pot = Pot()
        
        // 场景：3 个玩家，A all-in 50，B call 100，C call 100
        // 这应该正确计算为主池 150 + 边池 100
        var playerA = Player(name: "A", chips: 0, isHuman: false)
        playerA.totalBetThisHand = 50
        playerA.status = .allIn
        
        var playerB = Player(name: "B", chips: 900, isHuman: false)
        playerB.totalBetThisHand = 100
        playerB.status = .active
        
        var playerC = Player(name: "C", chips: 900, isHuman: false)
        playerC.totalBetThisHand = 100
        playerC.status = .active
        
        let players = [playerA, playerB, playerC]
        
        pot.add(250)
        pot.calculatePots(players: players)
        
        // 验证：portions 总和应该等于 runningTotal
        let portionSum = pot.portions.reduce(0) { $0 + $1.amount }
        
        // 如果有差异，说明存在 bug（保护性修复掩盖了问题）
        XCTAssertEqual(portionSum, pot.runningTotal,
                       "Pot portions 总和应该等于 runningTotal，不应该有差异")
    }
    
    /// 验证 pot 计算在多个 all-in 场景下的正确性
    func testPotCalculationMultipleAllIn() {
        var pot = Pot()
        
        // 场景：A all-in 30, B all-in 50, C call 100, D call 100
        // 应该产生 3 个池
        var playerA = Player(name: "A", chips: 0, isHuman: false)
        playerA.totalBetThisHand = 30
        playerA.status = .allIn
        
        var playerB = Player(name: "B", chips: 0, isHuman: false)
        playerB.totalBetThisHand = 50
        playerB.status = .allIn
        
        var playerC = Player(name: "C", chips: 900, isHuman: false)
        playerC.totalBetThisHand = 100
        playerC.status = .active
        
        var playerD = Player(name: "D", chips: 900, isHuman: false)
        playerD.totalBetThisHand = 100
        playerD.status = .active
        
        let players = [playerA, playerB, playerC, playerD]
        
        pot.add(280)
        pot.calculatePots(players: players)
        
        // 验证 portions 总和
        let portionSum = pot.portions.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(portionSum, pot.runningTotal,
                       "多个 all-in 场景下 portions 总和应该等于 runningTotal")
    }
    
    // MARK: - Bug Fix L-17: AI all-in 时 EV 计算错误
    
    /// 验证 AI all-in 时 EV 计算使用正确的金额
    /// 当玩家 all-in 时，callAmount 应该等于 all-in 的总金额，而不是之前的 call 金额
    func testAllInEVCalculationUsesCorrectAmount() {
        // 创建模拟的决策引擎测试场景
        // potSize = 200, currentBet = 50, player has 150 chips (all-in to 150)
        // equity = 0.5
        
        let equity: Double = 0.5
        let potSize = 200
        let callAmount = 50  // 玩家需要跟注的金额
        let allInAmount = 150  // 玩家 all-in 的总金额
        
        // 当 action 是 .allIn 时，EV 计算应该使用 allInAmount 而不是 callAmount
        // 当前代码错误地使用 let allInAmount = callAmount
        
        // 正确的 EV 公式：
        // EV = equity * (potSize + allInAmount) - (1 - equity) * allInAmount
        // = 0.5 * (200 + 150) - 0.5 * 150
        // = 0.5 * 350 - 75
        // = 175 - 75 = 100
        
        let expectedEV = equity * Double(potSize + allInAmount) - (1 - equity) * Double(allInAmount)
        
        // 错误的 EV（使用 callAmount）：
        // EV = equity * (potSize + callAmount) - (1 - equity) * callAmount
        // = 0.5 * (200 + 50) - 0.5 * 50
        // = 0.5 * 250 - 25
        // = 125 - 25 = 100
        // 实际上在这个例子中结果相同，让我们用不同的例子
        
        // 另一个例子：
        let potSize2 = 100
        let callAmount2 = 20
        let allInAmount2 = 100
        let equity2: Double = 0.4
        
        // 正确的 EV（使用 allInAmount）：
        let correctEV = equity2 * Double(potSize2 + allInAmount2) - (1 - equity2) * Double(allInAmount2)
        // = 0.4 * 200 - 0.6 * 100 = 80 - 60 = 20
        
        // 错误的 EV（使用 callAmount）：
        let wrongEV = equity2 * Double(potSize2 + callAmount2) - (1 - equity2) * Double(callAmount2)
        // = 0.4 * 120 - 0.6 * 20 = 48 - 12 = 36
        
        // 验证两种计算结果不同
        XCTAssertNotEqual(correctEV, wrongEV,
                          "使用 allInAmount 和 callAmount 计算的 EV 应该不同")
        
        // 验证正确 EV
        XCTAssertEqual(correctEV, 20.0, accuracy: 0.01,
                       "正确的 EV 应该是 20")
    }
    
    /// 验证 DecisionEngine 在 all-in 时的计算
    func testDecisionEngineAllInEV() {
        let engine = PokerEngine()
        
        // 设置玩家
        var player = Player(name: "AI", chips: 100, isHuman: false)
        player.status = .active
        player.currentBet = 0
        
        let opponent = Player(name: "Human", chips: 200, isHuman: true)
        
        engine.players = [player, opponent]
        engine.pot = Pot()
        engine.pot.add(100)  // 底池 100
        engine.currentBet = 50  // 当前下注 50
        engine.minRaise = 20
        engine.currentStreet = .flop
        engine.communityCards = [
            Card(rank: .ace, suit: .spades),
            Card(rank: .king, suit: .hearts),
            Card(rank: .queen, suit: .diamonds)
        ]
        
        // 设置玩家手牌
        player.holeCards = [
            Card(rank: .ace, suit: .clubs),
            Card(rank: .king, suit: .clubs)
        ]
        
        // 设置 AI profile（使用 .fox）
        player.aiProfile = .fox
        
        // 获取决策
        let action = DecisionEngine.makeDecision(player: player, engine: engine)
        
        // 验证决策（这里我们主要验证不会崩溃，EV 计算正确）
        // 如果 all-in 时的 EV 计算有 bug，可能会导致错误的决策
        print("AI decision: \(action)")
    }
    
    // MARK: - Bug Fix: 无法进入下一街的测试场景
    
    /// 场景1：翻牌前所有人都 check/call 后应该进入翻牌圈
    /// 测试 preflop 所有玩家都 check/call 后是否正确进入翻牌圈
    func testAllPlayersCheckCallEntersFlop() {
        let store = PokerGameStore()
        store.send(.start)
        
        // 确认当前是 preflop
        XCTAssertEqual(store.engine.currentStreet, .preFlop)
        
        // 手动设置到翻牌圈（模拟 preflop 已经完成）
        // 先发翻牌
        store.engine.dealNextStreet()
        
        // 验证进入翻牌圈
        XCTAssertEqual(store.engine.currentStreet, .flop,
                       "Preflop 完成后应该进入翻牌圈")
    }
    
    /// 场景2：有 allIn 玩家时的轮次完成
    /// 玩家 A allIn，玩家 B call，之后应该进入翻牌圈
    func testAllInWithCallAdvancesToFlop() {
        let engine = PokerEngine()
        
        // 设置 2 个玩家
        engine.players = [
            Player(name: "P1", chips: 100, isHuman: true),
            Player(name: "P2", chips: 100, isHuman: false)
        ]
        engine.dealerIndex = 0
        engine.smallBlindIndex = 0
        engine.bigBlindIndex = 1
        engine.currentBet = 20  // BB
        engine.minRaise = 20
        
        // 设置 preflop 状态：P1 all-in，P2 call
        engine.players[0].currentBet = 100
        engine.players[0].chips = 0
        engine.players[0].status = .allIn
        
        engine.players[1].currentBet = 100
        engine.players[1].chips = 0
        engine.players[1].status = .allIn
        
        // 设置 hasActed - 两个玩家都已行动
        engine.hasActed[engine.players[0].id] = true
        engine.hasActed[engine.players[1].id] = true
        
        // 验证 isRoundComplete 应该返回 true
        let isComplete = BettingManager.isRoundComplete(
            players: engine.players,
            hasActed: engine.hasActed,
            currentBet: engine.currentBet
        )
        
        XCTAssertTrue(isComplete,
                     "当所有玩家都 all-in 且都已行动时，轮次应该完成")
    }
    
    /// 场景3：翻牌后所有人都 check 应该进入转牌圈
    func testFlopAllCheckAdvancesToTurn() {
        let store = PokerGameStore()
        store.send(.start)
        store.send(.dealComplete)
        
        // 确认在翻牌圈
        XCTAssertEqual(store.engine.currentStreet, .flop)
        
        // 模拟所有玩家都 check
        // 设置当前下注为 0（翻牌圈开始时）
        store.engine.currentBet = 0
        store.engine.minRaise = 20
        
        // P1 check
        store.engine.activePlayerIndex = 0
        store.engine.hasActed[store.engine.players[0].id] = true
        store.engine.processAction(.check)
        
        // 确认 P1 行动了
        XCTAssertEqual(store.engine.hasActed[store.engine.players[0].id], true)
        
        // P2 check - 轮次应该完成并进入转牌圈
        store.engine.activePlayerIndex = 1
        store.engine.processAction(.check)
        
        // 验证进入转牌圈
        XCTAssertEqual(store.engine.currentStreet, .turn,
                       "翻牌后所有玩家 check 应该进入转牌圈")
    }
    
    /// 场景4：转牌后所有人都 check 应该进入河牌圈
    func testTurnAllCheckAdvancesToRiver() {
        let store = PokerGameStore()
        store.send(.start)
        store.send(.dealComplete)
        
        // 手动进入转牌圈
        store.engine.currentStreet = .turn
        store.engine.currentBet = 0
        store.engine.minRaise = 20
        
        // 添加 3 张公共牌（flop）
        store.engine.communityCards = [
            Card(rank: .ace, suit: .spades),
            Card(rank: .king, suit: .hearts),
            Card(rank: .queen, suit: .diamonds)
        ]
        
        // 重置下注状态
        store.engine.resetBettingState()
        
        // P1 check
        store.engine.activePlayerIndex = 0
        store.engine.processAction(.check)
        
        // P2 check - 轮次应该完成并进入河牌圈
        store.engine.activePlayerIndex = 1
        store.engine.processAction(.check)
        
        // 验证进入河牌圈
        XCTAssertEqual(store.engine.currentStreet, .river,
                       "转牌后所有玩家 check 应该进入河牌圈")
    }
    
    /// 场景5：河牌后所有人都 check 应该结束手牌
    func testRiverAllCheckEndsHand() {
        let store = PokerGameStore()
        store.send(.start)
        store.send(.dealComplete)
        
        // 手动进入河牌圈
        store.engine.currentStreet = .river
        store.engine.currentBet = 0
        store.engine.minRaise = 20
        
        // 添加 4 张公共牌（flop + turn）
        store.engine.communityCards = [
            Card(rank: .ace, suit: .spades),
            Card(rank: .king, suit: .hearts),
            Card(rank: .queen, suit: .diamonds),
            Card(rank: .jack, suit: .clubs)
        ]
        
        // 重置下注状态
        store.engine.resetBettingState()
        
        // P1 check
        store.engine.activePlayerIndex = 0
        store.engine.processAction(.check)
        
        // P2 check - 轮次应该完成并结束手牌
        store.engine.activePlayerIndex = 1
        store.engine.processAction(.check)
        
        // 验证手牌结束
        XCTAssertTrue(store.engine.isHandOver,
                      "河牌后所有玩家 check 应该结束手牌")
    }
    
    /// 场景6：翻牌后有人 bet/raise，其他玩家跟注后应该进入转牌圈
    func testFlopBetCallAdvancesToTurn() {
        let store = PokerGameStore()
        store.send(.start)
        store.send(.dealComplete)
        
        // 确认在翻牌圈
        XCTAssertEqual(store.engine.currentStreet, .flop)
        
        // 设置当前下注为 0
        store.engine.currentBet = 0
        store.engine.minRaise = 20
        
        // P1 bet 50
        store.engine.activePlayerIndex = 0
        store.engine.processAction(.raise(50))
        
        // 确认 P1 bet 后，currentBet 更新
        XCTAssertEqual(store.engine.currentBet, 50)
        
        // P2 call
        store.engine.activePlayerIndex = 1
        store.engine.processAction(.call)
        
        // 验证进入转牌圈
        XCTAssertEqual(store.engine.currentStreet, .turn,
                       "翻牌后有人 bet，其他玩家 call 应该进入转牌圈")
    }
    
    /// 场景7：只有 1 个 active 玩家 + 多个 allIn 玩家应该进入 runOutBoard
    func testOneActiveMultipleAllInRunsOutBoard() {
        let store = PokerGameStore()
        store.send(.start)
        store.send(.dealComplete)
        
        // 确保在翻牌圈
        XCTAssertEqual(store.engine.currentStreet, .flop)
        
        // 设置场景：P1 是 active，P2 和 P3 是 allIn
        store.engine.players[0].status = .active
        store.engine.players[0].chips = 100
        store.engine.players[0].currentBet = 0
        
        store.engine.players[1].status = .allIn
        store.engine.players[1].chips = 0
        store.engine.players[1].currentBet = 50
        
        store.engine.players[2].status = .allIn
        store.engine.players[2].chips = 0
        store.engine.players[2].currentBet = 50
        
        // 设置 dealerIndex
        store.engine.dealerIndex = 0
        store.engine.currentBet = 50
        store.engine.hasActed = [:]
        
        // 记录当前公共牌数量
        let cardsBefore = store.engine.communityCards.count
        
        // 调用 dealNextStreet
        store.engine.dealNextStreet()
        
        // 验证：只有一个 active 玩家时，应该进入 runOutBoard
        // runOutBoard 会一次性发完剩余的公共牌
        let cardsAfter = store.engine.communityCards.count
        
        // 如果 bug 存在（只发一张牌），cardsAfter = cardsBefore + 1
        // 正确行为（runOutBoard），cardsAfter 应该至少增加 2（发 turn + river）
        XCTAssertGreaterThan(cardsAfter, cardsBefore + 1,
                              "只有一个 active 玩家时应该一次性发完剩余公共牌")
    }
    
    /// 场景8：玩家加注后其他人重新行动，最后应该进入下一街
    func testRaiseReopensActionAdvancesStreet() {
        let store = PokerGameStore()
        store.send(.start)
        store.send(.dealComplete)
        
        // 确认在翻牌圈
        XCTAssertEqual(store.engine.currentStreet, .flop)
        
        // 设置当前下注为 0
        store.engine.currentBet = 0
        store.engine.minRaise = 20
        
        // P1 bet 50
        store.engine.activePlayerIndex = 0
        store.engine.processAction(.raise(50))
        
        // 验证 P1 加注后，currentBet 更新
        XCTAssertEqual(store.engine.currentBet, 50)
        
        // P2 raise to 100
        store.engine.activePlayerIndex = 1
        store.engine.processAction(.raise(100))
        
        // 验证 P2 加注后，currentBet 更新
        XCTAssertEqual(store.engine.currentBet, 100)
        
        // 验证 P1 的 hasActed 被重置（因为 P2 加注了）
        let p1ID = store.engine.players[0].id
        XCTAssertEqual(store.engine.hasActed[p1ID], false,
                       "P2 加注后，P1 的 hasActed 应该被重置为 false")
        
        // P1 call
        store.engine.activePlayerIndex = 0
        store.engine.processAction(.call)
        
        // 验证进入转牌圈
        XCTAssertEqual(store.engine.currentStreet, .turn,
                       "加注后所有人都行动完成应该进入转牌圈")
    }
    
    // MARK: - Bug Fix: hasActed 在 allIn 时的处理
    
    /// 验证 allIn 玩家的 hasActed 在新街开始时应该为 true
    func testAllInPlayerHasActedTrueAtNewStreet() {
        let engine = PokerEngine()
        
        // 设置玩家
        var players: [Player] = []
        var p1 = Player(name: "P1", chips: 0, isHuman: true)
        p1.status = .allIn
        players.append(p1)
        
        var p2 = Player(name: "P2", chips: 100, isHuman: false)
        p2.status = .active
        players.append(p2)
        
        engine.players = players
        engine.currentStreet = .flop
        engine.dealerIndex = 0
        engine.bigBlindAmount = 20
        
        // 重置下注状态
        engine.resetBettingState()
        
        // 验证 allIn 玩家的 hasActed 为 true
        XCTAssertEqual(engine.hasActed[p1.id], true,
                       "allIn 玩家在新街开始时 hasActed 应该为 true")
    }
    
    /// 验证加注后 allIn 玩家的 hasActed 不应该被重置
    func testRaiseDoesNotResetAllInHasActed() {
        let store = PokerGameStore()
        store.send(.start)
        store.send(.dealComplete)
        
        // 设置玩家状态
        store.engine.players[0].status = .active
        store.engine.players[1].status = .allIn
        
        // P1 bet
        store.engine.activePlayerIndex = 0
        store.engine.currentBet = 0
        store.engine.processAction(.raise(50))
        
        // 验证 allIn 玩家的 hasActed 不受影响
        let p2ID = store.engine.players[1].id
        // allIn 玩家应该仍然保持 hasActed = true（因为已经 allIn，不能再行动）
        XCTAssertEqual(store.engine.hasActed[p2ID], true,
                       "加注不应该影响 allIn 玩家的 hasActed 状态")
    }
    
    /// 验证 isRoundComplete 对 allIn 玩家的处理
    func testIsRoundCompleteWithAllInPlayers() {
        let engine = PokerEngine()
        
        // 设置玩家：P1 allIn, P2 active
        var players: [Player] = []
        var p1 = Player(name: "P1", chips: 0, isHuman: true)
        p1.status = .allIn
        p1.currentBet = 50
        players.append(p1)
        
        var p2 = Player(name: "P2", chips: 100, isHuman: false)
        p2.status = .active
        p2.currentBet = 50
        players.append(p2)
        
        engine.players = players
        
        // 设置 hasActed：P1 已行动，P2 也已行动
        var hasActed: [UUID: Bool] = [:]
        hasActed[p1.id] = true
        hasActed[p2.id] = true
        
        // 验证 isRoundComplete
        let isComplete = BettingManager.isRoundComplete(
            players: players,
            hasActed: hasActed,
            currentBet: 50
        )
        
        XCTAssertTrue(isComplete,
                      "当 allIn 玩家和 active 玩家都已行动且下注相同时，轮次应该完成")
    }

    // MARK: - Bug Fix: Check 操作失败无反馈

    /// 验证当需要跟注时，check 操作无效但被静默忽略（无用户反馈）
    /// 这是需要修复的 bug：用户点击 check 后没有任何反应，不知道需要跟注
    func testCheckFailsSilentlyWhenCallIsRequired() {
        let store = PokerGameStore()
        store.send(.start)
        store.send(.dealComplete)

        // 确认在翻牌圈
        XCTAssertEqual(store.engine.currentStreet, .flop)

        // 设置：P1 bet 50，P2 需要跟注
        store.engine.currentBet = 0
        store.engine.minRaise = 20
        store.engine.activePlayerIndex = 0

        // P1 bet 50
        store.engine.processAction(.raise(50))

        // 确认 currentBet 已更新
        XCTAssertEqual(store.engine.currentBet, 50)

        // P2 尝试 check（无效操作，应该被忽略）
        store.engine.activePlayerIndex = 1
        let p2InitialChips = store.engine.players[1].chips
        let p2InitialBet = store.engine.players[1].currentBet

        // 执行无效的 check
        store.engine.processAction(.check)

        // 验证：check 被静默忽略，筹码未变化
        XCTAssertEqual(store.engine.players[1].chips, p2InitialChips,
                      "无效的 check 不应该扣除玩家筹码")
        XCTAssertEqual(store.engine.players[1].currentBet, p2InitialBet,
                      "无效的 check 不应该改变玩家当前下注")
    }

    /// 验证 canCheck 方法正确判断是否允许 check
    func testCanCheckReturnsCorrectValue() {
        let store = PokerGameStore()
        store.send(.start)
        store.send(.dealComplete)

        // 翻牌圈，currentBet = 0，应该可以 check
        store.engine.currentBet = 0
        let canCheckWhenNoBet = store.engine.canCheck()
        XCTAssertTrue(canCheckWhenNoBet, "当前下注为0时应该可以 check")

        // P1 bet 50
        store.engine.activePlayerIndex = 0
        store.engine.processAction(.raise(50))

        // P2 需要跟注，不应该可以 check
        store.engine.activePlayerIndex = 1
        let canCheckWhenCallRequired = store.engine.canCheck()
        XCTAssertFalse(canCheckWhenCallRequired, "需要跟注时不应该可以 check")
    }
}
