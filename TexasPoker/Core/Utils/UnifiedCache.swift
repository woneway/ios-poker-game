import Foundation

// MARK: - Unified Cache Protocol

/// 统一缓存协议，提供通用的缓存操作接口
/// 所有应用缓存应遵循此协议以保持一致性
protocol UnifiedCacheProtocol {
    associatedtype Value

    /// 获取缓存值
    func get(for key: String) -> Value?

    /// 设置缓存值
    func set(_ value: Value, for key: String)

    /// 移除缓存值
    func remove(for key: String)

    /// 清空所有缓存
    func clear()

    /// 获取缓存数量
    var count: Int { get }
}

// MARK: - Cache Configuration

/// 缓存配置 - 独立于泛型类以支持静态属性
struct CacheConfiguration: Sendable {
    let maxAge: TimeInterval      // 缓存过期时间（秒）
    let maxSize: Int?             // 最大缓存数量，nil 表示无限制

    static let defaultConfig = CacheConfiguration(maxAge: 60, maxSize: 100)
    static let short = CacheConfiguration(maxAge: 30, maxSize: 50)
    static let medium = CacheConfiguration(maxAge: 60, maxSize: 100)
    static let long = CacheConfiguration(maxAge: 300, maxSize: 200)
}

// MARK: - Generic Unified Cache

/// 通用统一缓存实现
/// 使用并发队列保证线程安全，支持过期时间和最大缓存大小
final class UnifiedCache<T>: @unchecked Sendable {
    private var storage: [String: CacheEntry<T>] = [:]
    private let queue = DispatchQueue(label: "com.poker.unified.cache", attributes: .concurrent)

    /// 缓存条目
    struct CacheEntry<T>: Sendable {
        let value: T
        let timestamp: Date
    }

    private let configuration: CacheConfiguration

    init(configuration: CacheConfiguration = .defaultConfig) {
        self.configuration = configuration
    }

    /// 获取缓存值
    func get(for key: String) -> T? {
        queue.sync {
            guard let entry = storage[key] else { return nil }

            let age = Date().timeIntervalSince(entry.timestamp)
            if age > configuration.maxAge {
                storage.removeValue(forKey: key)
                return nil
            }

            return entry.value
        }
    }

    /// 设置缓存值
    func set(_ value: T, for key: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            // 如果达到最大缓存大小，清理最老的条目
            if let maxSize = self.configuration.maxSize,
               self.storage.count >= maxSize {
                let sortedKeys = self.storage.sorted { $0.value.timestamp < $1.value.timestamp }
                    .prefix(maxSize / 5)
                    .map { $0.key }
                for key in sortedKeys {
                    self.storage.removeValue(forKey: key)
                }
            }

            self.storage[key] = CacheEntry(value: value, timestamp: Date())
        }
    }

    /// 移除缓存值
    func remove(for key: String) {
        queue.async(flags: .barrier) {
            self.storage.removeValue(forKey: key)
        }
    }

    /// 清空所有缓存
    func clear() {
        queue.async(flags: .barrier) {
            self.storage.removeAll()
        }
    }

    /// 获取缓存数量
    var count: Int {
        queue.sync { storage.count }
    }
}
