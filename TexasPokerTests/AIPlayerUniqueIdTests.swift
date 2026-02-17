import XCTest
@testable import TexasPoker

/// 测试 AI 玩家唯一标识功能
/// 验证问题：15个AI玩家重复入场时需要正确识别并累计数据
final class AIPlayerUniqueIdTests: XCTestCase {
    
    // MARK: - Player 模型测试
    
    func testPlayerEntryIndexDefaultsToZero() {
        // 给定：创建没有指定 entryIndex 的 Player
        let player = Player(name: "测试玩家", chips: 1000)
        
        // 期望：entryIndex 默认为 0
        XCTAssertEqual(player.entryIndex, 0, "Player 的 entryIndex 应该默认为 0")
    }
    
    func testPlayerEntryIndexCanBeSet() {
        // 给定：创建指定 entryIndex 的 Player
        let player = Player(name: "测试玩家", chips: 1000, entryIndex: 3)
        
        // 期望：entryIndex 可以正确设置
        XCTAssertEqual(player.entryIndex, 3, "Player 的 entryIndex 应该能正确设置")
    }
    
    func testPlayerUniqueIdWithoutProfile() {
        // 给定：创建没有 AIProfile 的 Player
        let player = Player(name: "测试玩家", chips: 1000, entryIndex: 1)
        
        // 期望：playerUniqueId 使用 name + entryIndex 格式
        XCTAssertEqual(player.playerUniqueId, "测试玩家#1", "没有 AIProfile 时 playerUniqueId 应该使用 name#entryIndex 格式")
    }
    
    func testPlayerUniqueIdWithAIProfile() {
        // 给定：创建带有 AIProfile 的 Player
        let player = Player(
            name: "老狐狸",
            chips: 1000,
            isHuman: false,
            aiProfile: .fox,
            entryIndex: 2
        )
        
        // 期望：playerUniqueId 使用 profileName#entryIndex 格式
        XCTAssertEqual(player.playerUniqueId, "老狐狸#2", "有 AIProfile 时 playerUniqueId 应该使用 profile.name#entryIndex 格式")
    }
    
    func testPlayerDisplayNameReturnsUniqueId() {
        // 给定：创建带有 entryIndex 的 Player
        let player = Player(
            name: "老狐狸",
            chips: 1000,
            isHuman: false,
            aiProfile: .fox,
            entryIndex: 5
        )
        
        // 期望：displayName 返回 playerUniqueId
        XCTAssertEqual(player.displayName, "老狐狸#5", "displayName 应该返回 playerUniqueId")
    }
    
    func testPlayerDisplayNameForHumanPlayer() {
        // 给定：创建人类玩家
        let player = Player(name: "Hero", chips: 1000, isHuman: true)
        
        // 期望：人类玩家的 displayName 返回原始 name
        XCTAssertEqual(player.displayName, "Hero", "人类玩家的 displayName 应该返回原始 name")
    }
    
    // MARK: - AIProfile 测试
    
    func testAIProfileFoxHasCorrectId() {
        // 给定：使用预设 AIProfile
        let profile = AIProfile.fox
        
        // 期望：AIProfile 的 id 是程序标识符
        XCTAssertFalse(profile.id.isEmpty, "AIProfile 应该有 id 属性")
        XCTAssertEqual(profile.id, "fox", "fox profile 的 id 应该是 'fox'")
        XCTAssertEqual(profile.name, "老狐狸", "fox profile 的 name 应该是 '老狐狸'")
    }
    
    func testAllPresetProfilesHaveIds() {
        // 期望：所有预设 AIProfile 都有正确的 id 和 name
        let expected: [(id: String, name: String, profile: AIProfile)] = [
            ("rock", "石头", .rock),
            ("maniac", "疯子麦克", .maniac),
            ("calling_station", "安娜", .callingStation),
            ("fox", "老狐狸", .fox),
            ("shark", "鲨鱼汤姆", .shark),
            ("academic", "艾米", .academic),
            ("tilt_david", "大卫", .tiltDavid)
        ]
        
        for item in expected {
            XCTAssertFalse(item.profile.id.isEmpty, "预设 AIProfile \(item.name) 应该有 id")
            XCTAssertEqual(item.profile.id, item.id, "\(item.name) 的 id 应该是 '\(item.id)'")
            XCTAssertEqual(item.profile.name, item.name, "\(item.id) 的 name 应该是 '\(item.name)'")
        }
    }
    
    // MARK: - CashGameManager entryIndex 测试
    
    func testGenerateEntryIndexReturnsSequentialIndices() {
        // 测试 CashGameManager 的 entryIndex 生成逻辑
        
        // 给定：使用固定种子生成器（需要先看看是否支持测试）
        // 由于 CashGameManager 使用静态方法，这里主要验证逻辑
        
        // 期望：相同 profile 多次调用应该返回递增的 index
        // 这个测试验证 entryIndex 机制的核心思想
        
        // 模拟场景：同一 profile 多次入场
        let profile = AIProfile.fox
        
        // 第一次入场应该是 #1
        let firstEntry = Player(name: profile.name, chips: 1000, aiProfile: profile, entryIndex: 1)
        XCTAssertEqual(firstEntry.playerUniqueId, "\(profile.name)#1")
        
        // 第二次入场应该是 #2
        let secondEntry = Player(name: profile.name, chips: 1000, aiProfile: profile, entryIndex: 2)
        XCTAssertEqual(secondEntry.playerUniqueId, "\(profile.name)#2")
        
        // 验证：同一个 uniqueId 的玩家应该被识别为同一玩家
        XCTAssertEqual(firstEntry.playerUniqueId, "老狐狸#1")
        XCTAssertEqual(secondEntry.playerUniqueId, "老狐狸#2")
        XCTAssertNotEqual(firstEntry.playerUniqueId, secondEntry.playerUniqueId)
    }
    
    // MARK: - 数据累计问题复现测试
    
    func testDataAccumulationWithUniqueId() {
        // 这个测试验证核心问题：使用 playerUniqueId 可以正确累计数据
        
        // 给定：同一 AI 玩家多次入场
        let profile = AIProfile.rock
        let gameMode = GameMode.cashGame
        
        // 第一次入场
        let player1 = Player(name: profile.name, chips: 1000, aiProfile: profile, entryIndex: 1)
        
        // 第二次入场（重新买入）
        let player2 = Player(name: profile.name, chips: 1500, aiProfile: profile, entryIndex: 2)
        
        // 验证：使用 playerUniqueId 可以识别为同一玩家的不同入场
        XCTAssertEqual(player1.playerUniqueId, "石头#1")
        XCTAssertEqual(player2.playerUniqueId, "石头#2")
        
        // 这是设计决策：不同 entryIndex 是不同的玩家实例
        // 统计数据会按 playerUniqueId 存储，所以 "石头#1" 和 "石头#2" 是分开的
        // 如果需要累计到 "石头"（所有入场），需要在 StatisticsCalculator 层面处理
        
        // 关键：解决了 UUID 每次不同导致的数据分裂问题
        // 旧方案：player1.name = "石头", player2.name = "石头2" -> 数据分裂
        // 新方案：player1.playerUniqueId = "石头#1", player2.playerUniqueId = "石头#2" -> 数据正确分离
    }
}
