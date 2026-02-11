import XCTest
@testable import TexasPoker

class PotCalculationTests: XCTestCase {
    
    // MARK: - 测试 1: 无 All-in，所有人投注相同 → 只有主池
    
    func testNormalPot_NoAllIn() {
        var pot = Pot()
        
        // 3 人各投注 100
        let players = [
            makePlayer(name: "A", chips: 900, totalBet: 100, status: .active),
            makePlayer(name: "B", chips: 900, totalBet: 100, status: .active),
            makePlayer(name: "C", chips: 900, totalBet: 100, status: .active)
        ]
        
        pot.add(300) // runningTotal = 300
        pot.calculatePots(players: players)
        
        XCTAssertEqual(pot.portions.count, 1, "应该只有一个主池")
        XCTAssertEqual(pot.portions[0].amount, 300, "主池应为 300")
        XCTAssertEqual(pot.portions[0].eligiblePlayerIDs.count, 3, "所有 3 位玩家都有资格")
        XCTAssertFalse(pot.hasSidePots, "不应有边池")
        XCTAssertEqual(pot.total, 300)
    }
    
    // MARK: - 测试 2: 1 人 All-in 少于 bet → 主池 + 1 个边池
    
    func testSingleAllIn_CreatesSidePot() {
        var pot = Pot()
        
        // A: All-in 50, B: Call 100, C: Call 100
        let playerA = makePlayer(name: "A", chips: 0, totalBet: 50, status: .allIn)
        let playerB = makePlayer(name: "B", chips: 900, totalBet: 100, status: .active)
        let playerC = makePlayer(name: "C", chips: 900, totalBet: 100, status: .active)
        let players = [playerA, playerB, playerC]
        
        pot.add(250) // 50 + 100 + 100
        pot.calculatePots(players: players)
        
        XCTAssertEqual(pot.portions.count, 2, "应有主池 + 1 个边池")
        
        // 主池: 50×3 = 150 (A, B, C 参与)
        XCTAssertEqual(pot.portions[0].amount, 150, "主池应为 150")
        XCTAssertEqual(pot.portions[0].eligiblePlayerIDs.count, 3)
        XCTAssertTrue(pot.portions[0].eligiblePlayerIDs.contains(playerA.id))
        XCTAssertTrue(pot.portions[0].eligiblePlayerIDs.contains(playerB.id))
        XCTAssertTrue(pot.portions[0].eligiblePlayerIDs.contains(playerC.id))
        
        // 边池: 50×2 = 100 (仅 B, C 参与)
        XCTAssertEqual(pot.portions[1].amount, 100, "边池应为 100")
        XCTAssertEqual(pot.portions[1].eligiblePlayerIDs.count, 2)
        XCTAssertFalse(pot.portions[1].eligiblePlayerIDs.contains(playerA.id), "A 不应参与边池")
        XCTAssertTrue(pot.portions[1].eligiblePlayerIDs.contains(playerB.id))
        XCTAssertTrue(pot.portions[1].eligiblePlayerIDs.contains(playerC.id))
        
        XCTAssertTrue(pot.hasSidePots)
        XCTAssertEqual(pot.sidePots.count, 1)
    }
    
    // MARK: - 测试 3: 多人不同金额 All-in → 多个边池
    
    func testMultipleAllIn_MultipleSidePots() {
        var pot = Pot()
        
        // A: All-in 30, B: All-in 50, C: Call 100, D: Call 100
        let playerA = makePlayer(name: "A", chips: 0, totalBet: 30, status: .allIn)
        let playerB = makePlayer(name: "B", chips: 0, totalBet: 50, status: .allIn)
        let playerC = makePlayer(name: "C", chips: 900, totalBet: 100, status: .active)
        let playerD = makePlayer(name: "D", chips: 900, totalBet: 100, status: .active)
        let players = [playerA, playerB, playerC, playerD]
        
        pot.add(280) // 30 + 50 + 100 + 100
        pot.calculatePots(players: players)
        
        XCTAssertEqual(pot.portions.count, 3, "应有 3 个池")
        
        // 第 1 层 (level=30): A(30) + B(30) + C(30) + D(30) = 120, A/B/C/D 参与
        XCTAssertEqual(pot.portions[0].amount, 120, "第 1 层池应为 120")
        XCTAssertEqual(pot.portions[0].eligiblePlayerIDs.count, 4)
        
        // 第 2 层 (level=50): B(20) + C(20) + D(20) = 60, B/C/D 参与
        XCTAssertEqual(pot.portions[1].amount, 60, "第 2 层池应为 60")
        XCTAssertEqual(pot.portions[1].eligiblePlayerIDs.count, 3)
        XCTAssertFalse(pot.portions[1].eligiblePlayerIDs.contains(playerA.id))
        
        // 第 3 层 (level=100): C(50) + D(50) = 100, C/D 参与
        XCTAssertEqual(pot.portions[2].amount, 100, "第 3 层池应为 100")
        XCTAssertEqual(pot.portions[2].eligiblePlayerIDs.count, 2)
        XCTAssertFalse(pot.portions[2].eligiblePlayerIDs.contains(playerA.id))
        XCTAssertFalse(pot.portions[2].eligiblePlayerIDs.contains(playerB.id))
        
        // 总额校验
        let totalFromPortions = pot.portions.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(totalFromPortions, 280, "所有池总额应等于 runningTotal")
    }
    
    // MARK: - 测试 4: 弃牌玩家的投注也计入池中
    
    func testFoldedPlayerBetIncluded() {
        var pot = Pot()
        
        // A: All-in 50, B: Call 100, D: Folded (投了 30 后弃牌)
        let playerA = makePlayer(name: "A", chips: 0, totalBet: 50, status: .allIn)
        let playerB = makePlayer(name: "B", chips: 900, totalBet: 100, status: .active)
        let playerD = makePlayer(name: "D", chips: 970, totalBet: 30, status: .folded)
        let players = [playerA, playerB, playerD]
        
        pot.add(180) // 50 + 100 + 30
        pot.calculatePots(players: players)
        
        XCTAssertEqual(pot.portions.count, 2, "应有 2 个池")
        
        // 主池 (level=50): A(50) + B(50) + D(30) = 130, A/B 参与 (D 弃牌不参与分配)
        XCTAssertEqual(pot.portions[0].amount, 130, "主池应包含弃牌者的投注")
        XCTAssertEqual(pot.portions[0].eligiblePlayerIDs.count, 2, "弃牌者不参与分配")
        XCTAssertFalse(pot.portions[0].eligiblePlayerIDs.contains(playerD.id))
        
        // 边池 (level=100): B(50) = 50, 仅 B 参与
        XCTAssertEqual(pot.portions[1].amount, 50, "边池应为 50")
        XCTAssertEqual(pot.portions[1].eligiblePlayerIDs.count, 1)
        XCTAssertTrue(pot.portions[1].eligiblePlayerIDs.contains(playerB.id))
    }
    
    // MARK: - 测试 5: Heads-up All-in (两人对决)
    
    func testHeadsUpAllIn() {
        var pot = Pot()
        
        // A: All-in 500, B: All-in 300 (B 筹码不足)
        let playerA = makePlayer(name: "A", chips: 0, totalBet: 500, status: .allIn)
        let playerB = makePlayer(name: "B", chips: 0, totalBet: 300, status: .allIn)
        let players = [playerA, playerB]
        
        pot.add(800) // 500 + 300
        pot.calculatePots(players: players)
        
        XCTAssertEqual(pot.portions.count, 2, "应有 2 个池")
        
        // 主池 (level=300): A(300) + B(300) = 600, A/B 都参与
        XCTAssertEqual(pot.portions[0].amount, 600, "主池应为 600")
        XCTAssertEqual(pot.portions[0].eligiblePlayerIDs.count, 2)
        
        // 边池 (level=500): A(200) = 200, 仅 A 参与
        XCTAssertEqual(pot.portions[1].amount, 200, "边池应为 200（A 的多余部分）")
        XCTAssertEqual(pot.portions[1].eligiblePlayerIDs.count, 1)
        XCTAssertTrue(pot.portions[1].eligiblePlayerIDs.contains(playerA.id))
    }
    
    // MARK: - 测试 6: Pot.total 向后兼容
    
    func testPotTotalBackwardCompatible() {
        var pot = Pot()
        
        pot.add(50)
        XCTAssertEqual(pot.total, 50)
        
        pot.add(100)
        XCTAssertEqual(pot.total, 150)
        
        pot.reset()
        XCTAssertEqual(pot.total, 0)
        XCTAssertTrue(pot.portions.isEmpty)
    }
    
    // MARK: - 测试 7: 所有人投注一样，All-in (Heads-up 等筹码)
    
    func testEqualAllIn_NoBothAllIn() {
        var pot = Pot()
        
        // A 和 B 都 All-in 500
        let playerA = makePlayer(name: "A", chips: 0, totalBet: 500, status: .allIn)
        let playerB = makePlayer(name: "B", chips: 0, totalBet: 500, status: .allIn)
        let players = [playerA, playerB]
        
        pot.add(1000)
        pot.calculatePots(players: players)
        
        XCTAssertEqual(pot.portions.count, 1, "等额 All-in 只有主池")
        XCTAssertEqual(pot.portions[0].amount, 1000)
        XCTAssertEqual(pot.portions[0].eligiblePlayerIDs.count, 2)
        XCTAssertFalse(pot.hasSidePots)
    }
    
    // MARK: - 测试 8: 弃牌玩家投注超过最高存活玩家（旧 Bug 复现）
    
    func testFoldedPlayerBetExceedsMaxActive() {
        var pot = Pot()
        
        // A: All-in 100, B: Active 200, C: Folded 300 (C 投了最多但弃牌了)
        let playerA = makePlayer(name: "A", chips: 0, totalBet: 100, status: .allIn)
        let playerB = makePlayer(name: "B", chips: 800, totalBet: 200, status: .active)
        let playerC = makePlayer(name: "C", chips: 700, totalBet: 300, status: .folded)
        let players = [playerA, playerB, playerC]
        
        pot.add(600) // 100 + 200 + 300
        pot.calculatePots(players: players)
        
        // 所有 portions 总和必须等于 runningTotal
        let portionSum = pot.portions.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(portionSum, 600, "边池总和必须等于底池总额 $600")
        
        // 主池 (level=100): A(100) + B(100) + C(100) = 300
        XCTAssertEqual(pot.portions[0].amount, 300, "主池应为 300")
        
        // 边池: B(100) + C(100) + C的超额(100) = 应为 300
        // C 的 level 300 超过 B 的 200, 超额 100 归入 B 能赢的池
        let sidePotTotal = pot.portions.dropFirst().reduce(0) { $0 + $1.amount }
        XCTAssertEqual(sidePotTotal, 300, "边池总和应为 300")
    }
    
    // MARK: - 测试 9: 多人弃牌 + All-in 复杂场景的总额校验
    
    func testComplexScenario_TotalAmountConsistency() {
        var pot = Pot()
        
        // 模拟 8 人桌，多人弃牌不同金额
        let pA = makePlayer(name: "A", chips: 0, totalBet: 160, status: .allIn)   // SB all-in
        let pB = makePlayer(name: "B", chips: 0, totalBet: 320, status: .allIn)   // BB all-in  
        let pC = makePlayer(name: "C", chips: 500, totalBet: 80, status: .folded)  // 弃牌
        let pD = makePlayer(name: "D", chips: 0, totalBet: 500, status: .folded)   // 弃牌，投了最多
        let pE = makePlayer(name: "E", chips: 2000, totalBet: 320, status: .active) // 存活
        let pF = makePlayer(name: "F", chips: 0, totalBet: 50, status: .folded)    // 弃牌小额
        let players = [pA, pB, pC, pD, pE, pF]
        
        let totalBets = 160 + 320 + 80 + 500 + 320 + 50
        pot.add(totalBets)
        pot.calculatePots(players: players)
        
        // 核心断言：portions 总和必须等于 runningTotal
        let portionSum = pot.portions.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(portionSum, totalBets, "边池总和(\(portionSum))必须等于底池总额(\(totalBets))")
        
        // 不应该有空的 eligible
        for portion in pot.portions {
            XCTAssertFalse(portion.eligiblePlayerIDs.isEmpty, "每个池必须有至少一个有资格的玩家")
        }
    }
    
    // MARK: - 测试 10: 相同 eligible 的池应被合并
    
    func testSameEligiblePortionsMerged() {
        var pot = Pot()
        
        // A: 100 allIn, B: 100 allIn, C: 200 active
        // A 和 B 投注相同，应只产生 2 个池（不是 3 个）
        let playerA = makePlayer(name: "A", chips: 0, totalBet: 100, status: .allIn)
        let playerB = makePlayer(name: "B", chips: 0, totalBet: 100, status: .allIn)
        let playerC = makePlayer(name: "C", chips: 800, totalBet: 200, status: .active)
        let players = [playerA, playerB, playerC]
        
        pot.add(400)
        pot.calculatePots(players: players)
        
        XCTAssertEqual(pot.portions.count, 2, "应只有 2 个池（主池 + 1 边池）")
        XCTAssertEqual(pot.portions[0].amount, 300, "主池: 100*3=300")
        XCTAssertEqual(pot.portions[1].amount, 100, "边池: 100*1=100")
    }
    
    // MARK: - Helpers
    
    private func makePlayer(name: String, chips: Int, totalBet: Int, status: PlayerStatus) -> Player {
        var player = Player(name: name, chips: chips)
        player.totalBetThisHand = totalBet
        player.status = status
        return player
    }
}
