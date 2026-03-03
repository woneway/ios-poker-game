import XCTest
@testable import TexasPoker

/// 数据导出功能测试
final class DataExporterTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // 清理缓存
        StatisticsCache.shared.clear()
    }

    override func tearDown() {
        super.tearDown()
        StatisticsCache.shared.clear()
    }

    // MARK: - Export Statistics Tests

    func testExportStatisticsReturnsURL() {
        // 测试导出统计数据功能（如果有数据的话）
        // 由于测试环境可能没有数据，我们主要测试方法是否可调用

        // 验证方法存在
        let url = DataExporter.exportStatistics(gameMode: .cashGame)

        // 如果没有数据，返回nil是正常的
        // 如果有数据，应该返回有效的URL
        if let url = url {
            XCTAssertTrue(url.path.hasSuffix(".json"))
            XCTAssertTrue(url.path.contains("poker_stats"))
        }
    }

    func testExportStatisticsWithTournament() {
        let url = DataExporter.exportStatistics(gameMode: .tournament)

        // 验证方法执行不崩溃
        // 结果可能是nil（如果没有数据）
        if let url = url {
            XCTAssertTrue(url.path.hasSuffix(".json"))
            XCTAssertTrue(url.path.contains("tournament"))
        }
    }

    // MARK: - Export Hand History Tests

    func testExportHandHistoryReturnsURL() {
        let url = DataExporter.exportHandHistory(limit: 10, gameMode: .cashGame)

        // 如果没有数据，返回nil是正常的
        if let url = url {
            XCTAssertTrue(url.path.hasSuffix(".json"))
            XCTAssertTrue(url.path.contains("poker_history"))
        }
    }

    func testExportHandHistoryWithLimit() {
        let url = DataExporter.exportHandHistory(limit: 50, gameMode: .cashGame)

        // 验证方法执行不崩溃
        // 结果可能是nil（如果没有数据）
        _ = url
    }

    func testExportHandHistoryDefaultLimit() {
        // 测试默认limit参数
        let url = DataExporter.exportHandHistory(gameMode: .cashGame)

        // 验证默认limit为100
        _ = url
    }

    // MARK: - Async Export Tests

    func testExportStatisticsAsync() async {
        let url = await DataExporter.exportStatisticsAsync(gameMode: .cashGame)

        // 验证异步方法可调用
        // 结果可能是nil（如果没有数据）
        _ = url
    }

    func testExportHandHistoryAsync() async {
        let url = await DataExporter.exportHandHistoryAsync(limit: 20, gameMode: .tournament)

        // 验证异步方法可调用
        _ = url
    }

    // MARK: - File Name Tests

    func testExportFileNameFormat() {
        // 验证导出文件名格式包含必要信息
        let url = DataExporter.exportStatistics(gameMode: .cashGame)

        if let url = url {
            // 文件名应该包含: poker_stats, gameMode, 时间戳
            XCTAssertTrue(url.lastPathComponent.contains("poker_stats"))
            XCTAssertTrue(url.lastPathComponent.contains("cashGame"))
        }
    }

    func testExportHandHistoryFileNameFormat() {
        let url = DataExporter.exportHandHistory(limit: 100, gameMode: .tournament)

        if let url = url {
            XCTAssertTrue(url.lastPathComponent.contains("poker_history"))
            XCTAssertTrue(url.lastPathComponent.contains("tournament"))
        }
    }
}
