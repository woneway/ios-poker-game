import Foundation
import CoreData

/// 玩家风格分类
enum PlayerStyle: String, Codable {
    case rock       // 石头：VPIP<20%, PFR<15%, AF>2.5
    case tag        // 紧凶：VPIP 20-30%, PFR 15-25%, AF 2-3
    case lag        // 松凶：VPIP 30-45%, PFR 25-35%, AF 3-4
    case fish       // 鱼：VPIP>45%, PFR<15%, AF<1.5
    case unknown    // 未知：样本量不足
    
    var description: String {
        switch self {
        case .rock: return "石头 (超紧)"
        case .tag: return "紧凶 (平衡)"
        case .lag: return "松凶 (攻击)"
        case .fish: return "鱼 (跟注站)"
        case .unknown: return "未知"
        }
    }
}

/// 对手模型
class OpponentModel {
    let playerName: String
    let gameMode: GameMode

    // 统计数据（来自 S3）
    var vpip: Double = 0.0
    var pfr: Double = 0.0
    var af: Double = 0.0
    var wtsd: Double = 0.0
    var wsd: Double = 0.0
    var threeBet: Double = 0.0
    var totalHands: Int = 0

    // 风格分类
    var style: PlayerStyle = .unknown

    // MARK: - 置信度配置

    /// 置信度计算常量
    /// 达到此手数时置信度为 1.0 (使用 Constants.Statistics.minHandsForFullConfidence)
    private var minHandsForFullConfidence: Int {
        Constants.Statistics.minHandsForFullConfidence
    }

    /// 可信阈值（达到此比例的置信度则认为数据可用）
    private var reliabilityThreshold: Double { 0.5 }

    var confidence: Double {
        guard totalHands > 0 else { return 0.0 }
        // 置信度从0到1，达到 minHandsForFullConfidence 手时达到1.0
        return min(1.0, Double(totalHands) / Double(minHandsForFullConfidence))
    }

    /// 是否可信（置信度高于阈值）
    var isReliable: Bool {
        // 使用统一的阈值常量，与置信度计算保持一致
        return confidence >= reliabilityThreshold
    }

    /// 获取用于显示的置信度百分比
    var confidencePercentage: String {
        return String(format: "%.0f%%", confidence * 100)
    }
    
    init(playerName: String, gameMode: GameMode) {
        self.playerName = playerName
        self.gameMode = gameMode
    }
    
    /// 从 Core Data 加载统计数据
    func loadStats(from context: NSManagedObjectContext) {
        let profileId = ProfileManager.shared.currentProfileIdForData
        let request = NSFetchRequest<NSManagedObject>(entityName: "PlayerStatsEntity")
        if profileId == ProfileManager.defaultProfileId {
            request.predicate = NSPredicate(
                format: "playerName == %@ AND gameMode == %@ AND (profileId == %@ OR profileId == nil)",
                playerName, gameMode.rawValue, profileId
            )
        } else {
            request.predicate = NSPredicate(
                format: "playerName == %@ AND gameMode == %@ AND profileId == %@",
                playerName, gameMode.rawValue, profileId
            )
        }

        do {
            let results = try context.fetch(request)
            guard let stats = results.first else {
                #if DEBUG
                print("⚠️ OpponentModel: 未找到玩家 \(playerName) 的统计数据")
                #endif
                return
            }

            self.vpip = stats.value(forKey: "vpip") as? Double ?? 0.0
            self.pfr = stats.value(forKey: "pfr") as? Double ?? 0.0
            self.af = stats.value(forKey: "af") as? Double ?? 0.0
            self.wtsd = stats.value(forKey: "wtsd") as? Double ?? 0.0
            self.wsd = stats.value(forKey: "wsd") as? Double ?? 0.0
            self.threeBet = stats.value(forKey: "threeBet") as? Double ?? 0.0
            self.totalHands = Int(stats.value(forKey: "totalHands") as? Int32 ?? 0)

            #if DEBUG
            print("📊 OpponentModel: 加载 \(playerName) 统计数据，\(totalHands) 手")
            #endif

            updateStyle()
        } catch {
            #if DEBUG
            print("❌ OpponentModel: 加载 \(playerName) 统计数据失败: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// 更新风格分类
    func updateStyle() {
        guard totalHands >= Constants.Statistics.minHandsForStyleAnalysis else {
            style = .unknown
            return
        }

        style = OpponentModeler.classifyStyle(vpip: vpip, pfr: pfr, af: af)
    }
}
