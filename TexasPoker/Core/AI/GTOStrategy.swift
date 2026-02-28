import Foundation

// MARK: - GTO Strategy Extensions
/// 扩展GTO策略功能

extension DecisionEngine {

    // MARK: - GTO核心概念计算

    /// 计算最小防守频率 (Minimum Defense Frequency)
    /// MDF = pot / (pot + bet_size)
    /// 防守频率必须 >= MDF 才能防止对手盈利性诈雏
    static func calculateMDF(betSize: Int, potSize: Int) -> Double {
        guard betSize > 0 && potSize > 0 else { return 1.0 }
        return Double(potSize) / Double(potSize + betSize)
    }

    /// 计算价值下注与诈雏的最优比例 (基于GTO)
    /// 价值:诈雏 = bet_size : pot
    static func calculateValueToBluffRatio(betSize: Int, potSize: Int) -> Double {
        guard potSize > 0 else { return 1.0 }
        return Double(betSize) / Double(potSize)
    }

    /// 根据赔率计算跟注EV
    static func calculateCallEV(equity: Double, potSize: Int, callAmount: Int) -> Double {
        guard callAmount > 0 else { return equity * Double(potSize) }
        let totalPot = Double(potSize + callAmount)
        return equity * totalPot - Double(callAmount) * (1.0 - equity)
    }

    /// 计算加注的EV
    static func calculateRaiseEV(
        equity: Double,
        currentPot: Int,
        raiseSize: Int,
        opponentCallProb: Double
    ) -> Double {
        // 如果对手跟注，我们赢得 pot + raise
        let winAmount = Double(currentPot + raiseSize)
        // 如果对手弃牌，我们赢得 currentPot
        let foldAmount = Double(currentPot)

        let expectedWin = equity * (opponentCallProb * winAmount + (1.0 - opponentCallProb) * foldAmount)
        let expectedLose = (1.0 - equity) * opponentCallProb * Double(raiseSize)

        return expectedWin - expectedLose
    }

    // MARK: - GTO下注尺度

    /// GTO推荐下注尺度
    enum GTOBetSize {
        case small      // 1/3 pot
        case medium     // 1/2 pot
        case large      // 2/3 pot
        case overbet    // > pot
        case allIn

        func calculate(potSize: Int, bb: Int) -> Int {
            switch self {
            case .small:
                return max(bb, potSize / 3)
            case .medium:
                return max(bb, potSize / 2)
            case .large:
                return max(bb, potSize * 2 / 3)
            case .overbet:
                return max(bb, potSize)
            case .allIn:
                return Int.max
            }
        }
    }

    /// 根据牌面和位置选择最佳下注尺度
    static func gtoOptimalBetSize(
        handStrength: Double,
        boardTexture: BoardTexture,
        isIP: Bool,  // In Position
        potSize: Int,
        bb: Int
    ) -> GTOBetSize {
        // 干燥牌面 + 好位置 + 强牌 = 大尺度
        // 湿润牌面 + 差位置 = 小尺度

        let isMonster = handStrength > 0.80
        let isStrong = handStrength > 0.60
        let isBluff = handStrength < 0.35

        // 怪物牌：尽量获取价值
        if isMonster {
            return isIP ? .overbet : .large
        }

        // 强牌：中等尺度
        if isStrong {
            return boardTexture.wetness < 0.4 ? .large : .medium
        }

        // 诈雏：根据牌面调整
        if isBluff {
            return boardTexture.wetness < 0.3 ? .medium : .small
        }

        // 中等强度：过牌
        return .small
    }

    // MARK: - GTO 4-bet底池范围

    /// 4-bet底池 (4-bet pot) 策略
    static func gto4BetPotStrategy(
        holeCards: [Card],
        communityCards: [Card],
        equity: Double,
        potSize: Int,
        stackSize: Int,
        bb: Int
    ) -> PlayerAction {
        let spr = Double(stackSize) / Double(max(1, potSize))

        // 翻前4-bet底池：SPR通常很低
        if communityCards.isEmpty {
            // 翻前4-bet
            if equity > 0.60 {
                return .allIn
            }
            if equity > 0.45 && spr < 2 {
                return .allIn
            }
            return .fold
        }

        // 翻后4-bet底池
        if spr < 2 {
            // 核心套池：任何好牌都要全下
            if equity > 0.50 {
                return .allIn
            }
            // 听牌在低SPR下很危险
            let draws = analyzeDraws(holeCards: holeCards, communityCards: communityCards)
            if draws.totalOuts >= 8 && equity > 0.30 {
                return .allIn
            }
            return .fold
        }

        // 中SPR：更谨慎
        if equity > 0.65 {
            return .allIn
        }

        if equity > 0.50 {
            let raiseSize = max(bb, potSize)
            return .raise(potSize + raiseSize)
        }

        return .fold
    }

    // MARK: - GTO 单一加注底池 (Single Raised Pot)

    /// 单一加注底池策略
    static func gtoSingleRaisedPotStrategy(
        holeCards: [Card],
        communityCards: [Card],
        equity: Double,
        potSize: Int,
        betToFace: Int,
        isPFR: Bool,
        boardTexture: BoardTexture,
        street: Street,
        bb: Int
    ) -> PlayerAction {
        let potOdds = betToFace > 0 ? Double(betToFace) / Double(potSize + betToFace) : 0.0

        // 无人下注
        if betToFace == 0 {
            return gtoCheckOrBet(
                holeCards: holeCards,
                equity: equity,
                isPFR: isPFR,
                boardTexture: boardTexture,
                potSize: potSize,
                bb: bb
            )
        }

        // 面对下注：使用MDF
        let mdf = calculateMDF(betSize: betToFace, potSize: potSize)

        // 价值牌：加注
        if equity > 0.75 {
            let raiseSize = betToFace + max(potSize / 3, bb)
            return .raise(betToFace + raiseSize)
        }

        // 边缘牌：根据MDF防守
        if equity > mdf {
            // 有足够 equity 跟注
            return .call
        }

        // 边缘以下：检查是否有隐含赔率
        if street != .river {
            let draws = analyzeDraws(holeCards: holeCards, communityCards: communityCards)
            let impliedOdds = calculateImpliedOdds(
                spr: Double(max(1, 100)) / Double(potSize), // 估算
                street: street
            )

            if Double(draws.totalOuts) * (street == .flop ? 0.04 : 0.02) + impliedOdds > potOdds {
                return .call
            }
        }

        return .fold
    }

    /// GTO过牌或下注决策
    private static func gtoCheckOrBet(
        holeCards: [Card],
        equity: Double,
        isPFR: Bool,
        boardTexture: BoardTexture,
        potSize: Int,
        bb: Int
    ) -> PlayerAction {
        let handHash = abs(holeCards.hashValue)

        // PFR有范围优势，在干燥牌面可以高频下注
        if isPFR {
            let cbetFreq: Double
            if boardTexture.wetness < 0.3 {
                cbetFreq = 0.70  // 干燥牌面高频c-bet
            } else if boardTexture.wetness < 0.6 {
                cbetFreq = 0.50  // 中等
            } else {
                cbetFreq = 0.30  // 湿润牌面低频
            }

            // 价值下注
            if equity > 0.65 {
                if handHash % 100 < Int(cbetFreq * 100) {
                    let size = boardTexture.wetness < 0.4 ? potSize / 3 : potSize / 2
                    return .raise(max(bb, size))
                }
            }

            // 诈雏下注
            if equity < 0.35 && handHash % 100 < Int(cbetFreq * 30) {
                let size = potSize / 3
                return .raise(max(bb, size))
            }
        }

        return .check
    }

    // MARK: - GTO 3-bet底池 (3-bet Pot)

    /// 3-bet底池策略
    static func gto3BetPotStrategy(
        holeCards: [Card],
        communityCards: [Card],
        equity: Double,
        potSize: Int,
        betToFace: Int,
        street: Street,
        boardTexture: BoardTexture,
        bb: Int
    ) -> PlayerAction {
        let potOdds = betToFace > 0 ? Double(betToFace) / Double(potSize + betToFace) : 0.0
        let handEval = HandEvaluator.evaluate(holeCards: holeCards, communityCards: communityCards)
        let category = handEval.0

        // 3-bet底池通常SPR很低，更激进

        if betToFace == 0 {
            // 无人下注：高频下注拿价值
            if equity > 0.55 {
                let size = potSize / 2
                return .raise(max(bb, size))
            }
            return .check
        }

        // 面对下注：紧跟注，因为已经投入很多
        if equity > 0.50 {
            return .call
        }

        // 怪物牌：加注
        if category >= 4 || equity > 0.70 {
            let raiseSize = betToFace + potSize / 2
            return .raise(betToFace + raiseSize)
        }

        // 听牌：有足够赔率就call
        if street != .river {
            let draws = analyzeDraws(holeCards: holeCards, communityCards: communityCards)
            if draws.totalOuts >= 8 && equity > potOdds * 0.8 {
                return .call
            }
        }

        return .fold
    }

    // MARK: - GTO 锦标赛策略

    /// GTO锦标赛ICM决策
    static func gtoTournamentICMStrategy(
        holeCards: [Card],
        equity: Double,
        situation: ICMSituation,
        potSize: Int,
        betToFace: Int,
        bb: Int
    ) -> PlayerAction {
        // 泡沫期：收紧范围
        if situation.isBubble {
            if equity < 0.60 {
                return betToFace == 0 ? .check : .fold
            }
        }

        // 决赛桌（剩余6人）：考虑排名
        if situation.playersRemaining <= 6 {
            // 短码可以更激进
            if situation.stackRatio < 0.15 {
                if equity > 0.40 {
                    return .allIn
                }
            }
            // 大筹码可以剥削
            if situation.stackRatio > 0.30 {
                if equity > 0.55 {
                    let raiseSize = betToFace > 0 ? betToFace * 3 : bb * 3
                    return .raise(raiseSize)
                }
            }
        }

        // 常规ICM调整
        let icmMultiplier = situation.pressure

        // 调整后的 equity threshold
        let adjustedThreshold = 0.5 * icmMultiplier

        if equity > adjustedThreshold {
            return betToFace == 0 ? .raise(bb * 3) : .call
        }

        return betToFace == 0 ? .check : .fold
    }

    // MARK: - GTO 河牌圈决策

    /// GTO河牌圈最优策略
    static func gtoRiverStrategy(
        holeCards: [Card],
        communityCards: [Card],
        equity: Double,
        potSize: Int,
        betToFace: Int,
        opponentRange: [Card]?,
        bb: Int
    ) -> PlayerAction {
        let handEval = HandEvaluator.evaluate(holeCards: holeCards, communityCards: communityCards)
        let category = handEval.0

        // 无人下注
        if betToFace == 0 {
            // 价值：中等尺度
            if category >= 4 || equity > 0.75 {
                let size = potSize / 2
                return .raise(max(bb, size))
            }

            // 抓诈雏：过牌
            if category >= 2 && equity > 0.40 {
                return .check
            }

            // 垃圾牌：过牌
            return .check
        }

        // 面对下注：使用精确的MDF
        let mdf = calculateMDF(betSize: betToFace, potSize: potSize)

        // 价值牌：加注
        if category >= 5 || equity > 0.80 {
            let raiseSize = betToFace + potSize / 2
            return .raise(betToFace + raiseSize)
        }

        // 边缘牌：根据MDF
        if equity > mdf {
            return .call
        }

        // 抓诈雏：考虑对手范围
        if opponentRange != nil {
            // 如果对手范围里有足够多诈雏，可以放宽跟注范围
            if equity > mdf - 0.05 {
                return .call
            }
        }

        return .fold
    }
}

// MARK: - GTO范围分析扩展

extension RangeAnalyzer {

    /// 获取GTO开池范围
    static func gtoOpeningRange(position: Position, tableSize: Int = 8) -> HandRange {
        switch position {
        case .utg:
            return HandRange(position: position, action: .raise, street: .preFlop, rangeWidth: 0.14, description: "88+,ATs+,KQs,AJo+")
        case .utgPlus1:
            return HandRange(position: position, action: .raise, street: .preFlop, rangeWidth: 0.17, description: "77+,A9s+,KQs,QJs,JTs,ATo,KJo+")
        case .mp:
            return HandRange(position: position, action: .raise, street: .preFlop, rangeWidth: 0.20, description: "66+,A8s+,K9s+,Q9s+,J9s+,T9s,ATo,KTo+")
        case .hj:
            return HandRange(position: position, action: .raise, street: .preFlop, rangeWidth: 0.25, description: "55+,A7s+,K8s+,Q8s+,J8s+,T8s+,97s+,ATo,KTo+,QJo")
        case .co:
            return HandRange(position: position, action: .raise, street: .preFlop, rangeWidth: 0.30, description: "44+,A5s+,K7s+,Q7s+,J7s+,T7s+,87s,ATo,KTo+,QJo,JTo")
        case .btn:
            return HandRange(position: position, action: .raise, street: .preFlop, rangeWidth: 0.42, description: "22+,A2s+,K2s+,Q2s+,J2s+,T2s+,82s+,72s+,A2o+,K2o+,Q2o+,J2o+,T2o+")
        case .sb:
            return HandRange(position: position, action: .raise, street: .preFlop, rangeWidth: 0.30, description: "55+,A2s+,K6s+,Q6s+,J7s+,T7s+,87s,ATo,KTo+,QJo")
        case .bb:
            return HandRange(position: position, action: .raise, street: .preFlop, rangeWidth: 0.45, description: "BB防守范围")
        }
    }

    /// 获取GTO 3-bet范围
    static func gto3BetRange(position: Position, isIP: Bool) -> HandRange {
        if isIP {
            return HandRange(position: position, action: .threebet, street: .preFlop, rangeWidth: 0.12, description: "88+,A9s+,KQs,QJs,JTs,T9s,ATo,KJo+,QJo")
        }
        return HandRange(position: position, action: .threebet, street: .preFlop, rangeWidth: 0.08, description: "TT+,AQs+,KQs,QJs,ATo,KJo+")
    }

    /// 获取GTO跟注3-bet范围
    static func gtoCall3BetRange(position: Position, isIP: Bool) -> HandRange {
        if isIP {
            return HandRange(position: position, action: .call, street: .preFlop, rangeWidth: 0.15, description: "77+,A9s+,K9s+,Q9s+,J9s+,T9s,ATo,KJo+")
        }
        return HandRange(position: position, action: .call, street: .preFlop, rangeWidth: 0.10, description: "88+,A9s+,KQs,ATo,KJo+")
    }
}
