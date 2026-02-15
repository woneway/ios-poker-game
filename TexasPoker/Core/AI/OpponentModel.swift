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
    
    // 置信度计算
    // 基于样本量：至少需要100手才有统计意义
    // PokerStove等工具建议100+手
    private let minHandsForConfidence = 100
    
    var confidence: Double {
        guard totalHands > 0 else { return 0.0 }
        // 置信度从0到1，100手达到1.0
        return min(1.0, Double(totalHands) / Double(minHandsForConfidence))
    }
    
    /// 是否可信（置信度高于阈值）
    var isReliable: Bool {
        return confidence > 0.5  // 至少50手才认为可信
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
        
        guard let results = try? context.fetch(request),
              let stats = results.first else {
            return
        }
        
        self.vpip = stats.value(forKey: "vpip") as? Double ?? 0.0
        self.pfr = stats.value(forKey: "pfr") as? Double ?? 0.0
        self.af = stats.value(forKey: "af") as? Double ?? 0.0
        self.wtsd = stats.value(forKey: "wtsd") as? Double ?? 0.0
        self.wsd = stats.value(forKey: "wsd") as? Double ?? 0.0
        self.threeBet = stats.value(forKey: "threeBet") as? Double ?? 0.0
        self.totalHands = Int(stats.value(forKey: "totalHands") as? Int32 ?? 0)
        
        updateStyle()
    }
    
    /// 更新风格分类
    func updateStyle() {
        guard totalHands >= 20 else {
            style = .unknown
            return
        }
        
        style = OpponentModeler.classifyStyle(vpip: vpip, pfr: pfr, af: af)
    }
}
