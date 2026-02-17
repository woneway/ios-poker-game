import Foundation

/// 单个奖池（主池或边池）
struct PotPortion: Equatable {
    var amount: Int = 0
    var eligiblePlayerIDs: Set<UUID>
}

struct Pot: Equatable {
    /// 实时累计总额（用于 betting 阶段 UI 显示）
    private(set) var runningTotal: Int = 0
    
    /// 计算后的池列表（index 0 = 主池，1+ = 边池）
    private(set) var portions: [PotPortion] = []
    
    /// 总金额（向后兼容）
    var total: Int { runningTotal }
    
    /// 主池金额（边池计算前返回 runningTotal）
    var mainPot: Int { portions.first?.amount ?? runningTotal }
    
    /// 边池列表（不含主池）
    var sidePots: [PotPortion] { portions.count > 1 ? Array(portions.dropFirst()) : [] }
    
    /// 是否已有边池
    var hasSidePots: Bool { portions.count > 1 }
    
    /// betting 阶段实时累加
    mutating func add(_ amount: Int) {
        runningTotal += amount
    }
    
    /// 退还筹码（用于退还未被跟注的金额）
    mutating func refund(_ amount: Int) {
        runningTotal -= amount
        if runningTotal < 0 { runningTotal = 0 }
    }
    
    mutating func reset() {
        runningTotal = 0
        portions.removeAll()
    }
    
    /// 根据玩家投注计算主池和边池
    ///
    /// 算法：按所有玩家的投注金额从小到大逐层切分
    /// - 使用 ALL 玩家的投注级别（包括弃牌的），确保所有筹码都被分配
    /// - 弃牌玩家的超额投注归入最近的有效池
    /// - 相同 eligible 集合的相邻池自动合并，减少碎片化
    ///
    /// - Parameter players: 所有玩家（包括已弃牌的）
    mutating func calculatePots(players: [Player]) {
        portions.removeAll()
        
        struct BetInfo {
            let id: UUID
            let totalBet: Int
            let isFolded: Bool
        }
        
        let betInfos = players
            .filter { $0.totalBetThisHand > 0 }
            .map { BetInfo(id: $0.id, totalBet: $0.totalBetThisHand, isFolded: $0.status == .folded) }
        
        guard !betInfos.isEmpty else { return }
        
        // 使用所有玩家（包括弃牌的）的投注级别，确保所有筹码都被捕获
        let allBets = betInfos.map { $0.totalBet }
        let uniqueLevels = Array(Set(allBets)).sorted()
        
        guard !uniqueLevels.isEmpty else { return }
        
        var previousLevel = 0
        var rawPortions: [PotPortion] = []
        
        for level in uniqueLevels {
            var potAmount = 0
            var eligible = Set<UUID>()
            
            for info in betInfos {
                // 每位玩家在这一层贡献的金额
                let contribution = min(info.totalBet, level) - min(info.totalBet, previousLevel)
                potAmount += max(0, contribution)
                
                // 未弃牌且投注 ≥ 该层级的玩家有资格赢取
                if !info.isFolded && info.totalBet >= level {
                    eligible.insert(info.id)
                }
            }
            
            if potAmount > 0 {
                if !eligible.isEmpty {
                    rawPortions.append(PotPortion(amount: potAmount, eligiblePlayerIDs: eligible))
                } else {
                    // 此层级无 eligible 玩家（全是弃牌玩家的超额投注）
                    // 将金额合并到上一个有 eligible 的池
                    if !rawPortions.isEmpty {
                        rawPortions[rawPortions.count - 1].amount += potAmount
                    }
                }
            }
            
            previousLevel = level
        }
        
        // 合并相同 eligible 集合的相邻池（减少碎片化）
        for portion in rawPortions {
            if let lastIdx = portions.indices.last,
               portions[lastIdx].eligiblePlayerIDs == portion.eligiblePlayerIDs {
                // 相同参与者，合并
                portions[lastIdx].amount += portion.amount
            } else {
                portions.append(portion)
            }
        }
        
        // 移除保护性修复，添加详细调试信息
        let portionSum = portions.reduce(0) { $0 + $1.amount }
        if portionSum != runningTotal && !portions.isEmpty {
            let diff = runningTotal - portionSum

            #if DEBUG
            print("⚠️ Pot 计算差异: portionsSum=\(portionSum), runningTotal=\(runningTotal), diff=\(diff)")
            #endif
            // 尝试恢复：将差异加到主池
            if !portions.isEmpty {
                portions[0].amount += diff
            }
        }
    }
}
