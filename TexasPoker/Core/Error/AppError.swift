import Foundation

enum AppError: Error, LocalizedError {
    case dataNotFound
    case invalidData
    case saveFailed(String)
    case fetchFailed(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .dataNotFound:
            return "数据未找到"
        case .invalidData:
            return "数据无效"
        case .saveFailed(let message):
            return "保存失败: \(message)"
        case .fetchFailed(let message):
            return "获取数据失败: \(message)"
        case .unknown(let message):
            return "未知错误: \(message)"
        }
    }
}
