import XCTest

class AIVerificationUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testRunVerificationAndCaptureResults() {
        // 等待应用启动
        sleep(2)

        // 截图首页
        let homeScreenshot = XCUIApplication().windows.firstMatch.screenshot()
        saveScreenshot(screenshot: homeScreenshot, name: "01_home")

        // 点击设置按钮 (右下角齿轮图标)
        // 尝试点击右下角区域
        let settingsButton = app.buttons["SettingsButton"]
        if settingsButton.exists {
            settingsButton.tap()
        } else {
            // 点击右下角区域
            let window = app.windows.element
            let bottomRight = window.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.85))
            bottomRight.tap()
        }

        sleep(1)

        // 截图设置页面
        let settingsScreenshot = app.windows.firstMatch.screenshot()
        saveScreenshot(screenshot: settingsScreenshot, name: "02_settings")

        // 查找AI验证标签 (第3个tab)
        // 通过滑动查找
        let tabBars = app.tabBars
        if tabBars.exists {
            let buttons = tabBars.buttons
            // 第3个按钮是AI验证
            if buttons.count >= 3 {
                buttons.element(boundBy: 2).tap()
            }
        }

        sleep(1)

        // 截图AI验证页面
        let verifyScreenshot = app.windows.firstMatch.screenshot()
        saveScreenshot(screenshot: verifyScreenshot, name: "03_verification")

        // 点击全选按钮
        let selectAllButton = app.buttons.matching(identifier: "SelectAllButton").firstMatch
        if selectAllButton.exists {
            selectAllButton.tap()
        }

        sleep(1)

        // 点击开始验证按钮
        let startButton = app.buttons.matching(identifier: "StartVerificationButton").firstMatch
        if startButton.exists {
            startButton.tap()

            // 等待验证完成
            sleep(30)

            // 截图结果页面
            let resultScreenshot = app.windows.firstMatch.screenshot()
            saveScreenshot(screenshot: resultScreenshot, name: "04_results")
        }
    }

    func saveScreenshot(screenshot: XCUIScreenshot, name: String) {
        let path = "/tmp/\(name).png"
        do {
            try screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
            print("Screenshot saved: \(path)")
        } catch {
            print("Failed to save screenshot: \(error)")
        }
    }
}
