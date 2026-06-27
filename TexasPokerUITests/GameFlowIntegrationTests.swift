import XCTest

/// 集成测试 - 验证主要 UI 流程
class GameFlowIntegrationTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Lobby Flow Tests

    /// 测试应用启动并进入大厅
    func testAppLaunchesToLobby() {
        app.launch()

        // 等待应用加载完成
        sleep(2)

        // 验证大厅存在
        let lobbyView = app.staticTexts["LobbyView"]
        XCTAssertTrue(lobbyView.waitForExistence(timeout: 5), "应该显示大厅界面")
    }

    /// 测试现金桌模式入口
    func testCashGameEntry() {
        app.launch()
        sleep(2)

        // 点击现金桌按钮
        let cashGameButton = app.buttons["CashGameButton"]
        if cashGameButton.exists {
            cashGameButton.tap()
            sleep(1)

            // 验证进入了现金桌游戏
            let gameView = app.staticTexts["GameView"]
            XCTAssertTrue(gameView.waitForExistence(timeout: 5), "应该显示游戏界面")
        }
    }

    /// 测试锦标赛模式入口
    func testTournamentEntry() {
        app.launch()
        sleep(2)

        // 点击锦标赛按钮
        let tournamentButton = app.buttons["TournamentButton"]
        if tournamentButton.exists {
            tournamentButton.tap()
            sleep(1)

            // 验证进入了锦标赛
            let tournamentView = app.staticTexts["TournamentView"]
            XCTAssertTrue(tournamentView.waitForExistence(timeout: 5), "应该显示锦标赛界面")
        }
    }

    // MARK: - Settings Flow Tests

    /// 测试设置页面导航
    func testSettingsNavigation() {
        app.launch()
        sleep(2)

        // 点击设置按钮
        let settingsButton = app.buttons["SettingsButton"]
        if settingsButton.exists {
            settingsButton.tap()
            sleep(1)

            // 验证显示设置页面
            let settingsView = app.staticTexts["SettingsView"]
            XCTAssertTrue(settingsView.waitForExistence(timeout: 5), "应该显示设置界面")
        }
    }

    /// 测试设置页面返回
    func testSettingsBackNavigation() {
        app.launch()
        sleep(2)

        // 进入设置
        let settingsButton = app.buttons["SettingsButton"]
        if settingsButton.exists {
            settingsButton.tap()
            sleep(1)

            // 点击返回按钮
            let backButton = app.buttons["BackButton"]
            if backButton.exists {
                backButton.tap()
                sleep(1)

                // 验证返回大厅
                let lobbyView = app.staticTexts["LobbyView"]
                XCTAssertTrue(lobbyView.waitForExistence(timeout: 5), "应该返回大厅界面")
            }
        }
    }

    // MARK: - Statistics Flow Tests

    /// 测试统计页面导航
    func testStatisticsNavigation() {
        app.launch()
        sleep(2)

        // 点击统计按钮
        let statsButton = app.buttons["StatisticsButton"]
        if statsButton.exists {
            statsButton.tap()
            sleep(1)

            // 验证显示统计页面
            let statsView = app.staticTexts["StatisticsView"]
            XCTAssertTrue(statsView.waitForExistence(timeout: 5), "应该显示统计界面")
        }
    }

    // MARK: - Game Controls Tests

    /// 测试游戏控制按钮存在性
    func testGameControlButtonsExist() {
        app.launch()
        sleep(2)

        // 进入游戏
        let cashGameButton = app.buttons["CashGameButton"]
        if cashGameButton.exists {
            cashGameButton.tap()
            sleep(3)

            // 验证游戏控制按钮存在
            let checkButton = app.buttons["CheckButton"]
            let foldButton = app.buttons["FoldButton"]
            let callButton = app.buttons["CallButton"]
            let raiseButton = app.buttons["RaiseButton"]

            // 至少应该存在一些控制按钮
            let hasAnyControl = checkButton.exists || foldButton.exists || callButton.exists || raiseButton.exists
            XCTAssertTrue(hasAnyControl, "应该显示游戏控制按钮")
        }
    }
}
