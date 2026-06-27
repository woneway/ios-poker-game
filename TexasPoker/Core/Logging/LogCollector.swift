import Foundation
import os.log

/// 日志收集器 - 收集并导出日志到文件（批量写入优化）
final class LogCollector {
    static let shared = LogCollector()

    private let maxLogCount = 10000  // 最多保存10000条日志
    private let batchWriteThreshold = 50  // 累积50条日志后再写入磁盘
    private var logs: [LogEntry] = []
    private let queue = DispatchQueue(label: "com.texaspoker.logcollector")
    private let logger = OSLog(subsystem: "smartegg.TexasPoker", category: "LogCollector")
    private var pendingWrites = 0  // 待写入计数

    struct LogEntry: Codable {
        let timestamp: Date
        let level: String
        let category: String
        let message: String
        let thread: String

        var formatted: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return "[\(formatter.string(from: timestamp))] [\(level)] [\(category)] \(message)"
        }
    }

    private init() {
        loadLogsFromDisk()
    }

    // MARK: - Public Methods

    /// 记录日志（批量写入优化）
    func log(level: String, category: String, message: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let entry = LogEntry(
                timestamp: Date(),
                level: level,
                category: category,
                message: message,
                thread: Thread.isMainThread ? "main" : "background"
            )

            self.logs.append(entry)
            self.pendingWrites += 1

            // 超过上限时删除最旧的
            if self.logs.count > self.maxLogCount {
                self.logs.removeFirst(self.logs.count - self.maxLogCount)
            }

            // 批量写入：达到阈值或内存中日志过多时写入
            if self.pendingWrites >= self.batchWriteThreshold || self.logs.count > self.maxLogCount / 2 {
                self.saveLogsToDisk()
                self.pendingWrites = 0
            }
        }
    }

    /// 强制刷新日志到磁盘（供外部调用，如应用进入后台）
    func flush() {
        queue.async { [weak self] in
            self?.saveLogsToDisk()
            self?.pendingWrites = 0
        }
    }

    /// 导出日志到文件
    func exportToFile() -> URL? {
        var result: URL?
        queue.sync {
            guard !logs.isEmpty else { return }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let filename = "TexasPoker_Log_\(formatter.string(from: Date())).txt"

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent(filename)

            let content = logs.map { $0.formatted }.joined(separator: "\n")

            do {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
                result = fileURL
            } catch {
                os_log("Failed to export logs: %{public}@", log: logger, type: .error, error.localizedDescription)
            }
        }
        return result
    }

    /// 导出JSON格式（便于程序解析）
    func exportToJSON() -> URL? {
        var result: URL?
        queue.sync {
            guard !logs.isEmpty else { return }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let filename = "TexasPoker_Log_\(formatter.string(from: Date())).json"

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent(filename)

            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(logs)
                try data.write(to: fileURL)
                result = fileURL
            } catch {
                os_log("Failed to export JSON logs: %{public}@", log: logger, type: .error, error.localizedDescription)
            }
        }
        return result
    }

    /// 获取日志数量
    func logCount() -> Int {
        var count = 0
        queue.sync {
            count = logs.count
        }
        return count
    }

    /// 清空日志
    func clearLogs() {
        queue.async { [weak self] in
            self?.logs.removeAll()
            self?.saveLogsToDisk()
        }
    }

    /// 获取最近N条日志
    func recentLogs(_ count: Int = 100) -> [LogEntry] {
        var result: [LogEntry] = []
        queue.sync {
            let startIndex = max(0, logs.count - count)
            result = Array(logs[startIndex...])
        }
        return result
    }

    // MARK: - Private Methods

    private var logFileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("cached_logs.json")
    }

    private func saveLogsToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(logs)
            try data.write(to: logFileURL)
        } catch {
            os_log("Failed to save logs to disk: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }

    private func loadLogsFromDisk() {
        guard FileManager.default.fileExists(atPath: logFileURL.path) else { return }

        do {
            let data = try Data(contentsOf: logFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            logs = try decoder.decode([LogEntry].self, from: data)
        } catch {
            os_log("Failed to load logs from disk: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }
}
