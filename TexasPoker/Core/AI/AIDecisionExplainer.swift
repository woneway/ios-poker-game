import Foundation

enum TiltLevel: CaseIterable {
    case calm
    case minor
    case moderate
    case severe
    case onTilt

    var description: String {
        switch self {
        case .calm: return "冷静"
        case .minor: return "轻微波动"
        case .moderate: return "中度波动"
        case .severe: return "严重上头"
        case .onTilt: return "失控"
        }
    }

    static func from(tiltValue: Double) -> TiltLevel {
        switch tiltValue {
        case 0..<0.2: return .calm
        case 0.2..<0.4: return .minor
        case 0.4..<0.6: return .moderate
        case 0.6..<0.8: return .severe
        default: return .onTilt
        }
    }
}

struct TablePosition {
    let name: String
    let positionalAdvantage: Double
    let stealability: Double

    static let utg = TablePosition(name: "UTG", positionalAdvantage: 0.3, stealability: 0.2)
    static let utg1 = TablePosition(name: "UTG+1", positionalAdvantage: 0.35, stealability: 0.25)
    static let lojack = TablePosition(name: "Lojack", positionalAdvantage: 0.4, stealability: 0.3)
    static let hijack = TablePosition(name: "Hijack", positionalAdvantage: 0.5, stealability: 0.4)
    static let cutoff = TablePosition(name: "Cutoff", positionalAdvantage: 0.65, stealability: 0.6)
    static let button = TablePosition(name: "Button", positionalAdvantage: 0.8, stealability: 0.7)
    static let smallBlind = TablePosition(name: "小盲", positionalAdvantage: 0.2, stealability: 0.1)
    static let bigBlind = TablePosition(name: "大盲", positionalAdvantage: 0.25, stealability: 0.05)
}

struct DecisionFactor {
    let name: String
    let value: Double
    let weight: Double
    let description: String
}

struct AIDecisionExplanation {
    let playerId: String
    let action: PlayerAction
    let equity: Double
    let potOdds: Double
    let expectedValue: Double
    let factors: [DecisionFactor]
    let reasoning: String
    let confidence: Double
    
    var summary: String {
        return "选择了 \(action.description)，EV = \(String(format: "%.1f", expectedValue))"
    }
}

class AIDecisionExplainer {
    static let shared = AIDecisionExplainer()
    
    private init() {}
    
    func explainPreflopDecision(
        profile: AIProfile,
        holeCards: [Card],
        position: TablePosition,
        action: PlayerAction,
        callAmount: Int,
        bigBlind: Int
    ) -> AIDecisionExplanation {
        let chenScore = DecisionEngine.chenFormula(holeCards)
        let normalizedStrength = DecisionEngine.chenToNormalized(chenScore)
        
        var factors: [DecisionFactor] = []
        
        factors.append(DecisionFactor(
            name: "手牌强度",
            value: normalizedStrength,
            weight: 0.4,
            description: "Chen分数: \(String(format: "%.1f", chenScore))"
        ))
        
        factors.append(DecisionFactor(
            name: "位置优势",
            value: position.positionalAdvantage,
            weight: 0.25,
            description: "位置: \(position.name)"
        ))
        
        let vpipAdjusted = profile.tightness < 0.5
        factors.append(DecisionFactor(
            name: "游戏风格",
            value: vpipAdjusted ? 0.7 : 0.3,
            weight: 0.2,
            description: "风格: \(profile.name)"
        ))
        
        if callAmount > 0 {
            let odds = Double(callAmount) / Double(bigBlind * 3)
            factors.append(DecisionFactor(
                name: "跟注赔率",
                value: odds,
                weight: 0.15,
                description: "需要跟注 \(callAmount) 筹码"
            ))
        }
        
        let reasoning = generatePreflopReasoning(
            action: action,
            chenScore: chenScore,
            position: position,
            callAmount: callAmount
        )
        
        return AIDecisionExplanation(
            playerId: profile.id,
            action: action,
            equity: normalizedStrength,
            potOdds: Double(callAmount) / Double(bigBlind * 3),
            expectedValue: normalizedStrength - Double(callAmount) / Double(bigBlind * 10),
            factors: factors,
            reasoning: reasoning,
            confidence: 0.7
        )
    }
    
    func explainPostflopDecision(
        profile: AIProfile,
        holeCards: [Card],
        communityCards: [Card],
        street: Street,
        action: PlayerAction,
        potSize: Int,
        callAmount: Int,
        equity: Double,
        boardTexture: GameBoardTexture
    ) -> AIDecisionExplanation {
        var factors: [DecisionFactor] = []
        
        factors.append(DecisionFactor(
            name: "胜率",
            value: equity,
            weight: 0.35,
            description: "胜率: \(String(format: "%.1f%%", equity * 100))"
        ))
        
        let potOdds = callAmount > 0 ? Double(callAmount) / Double(potSize + callAmount) : 0
        factors.append(DecisionFactor(
            name: "底池赔率",
            value: potOdds,
            weight: 0.25,
            description: "赔率: \(String(format: "%.1f%%", potOdds * 100))"
        ))
        
        let boardText = boardTexture == .dry ? "干燥" : (boardTexture == .wet ? "湿润" : "中性")
        factors.append(DecisionFactor(
            name: "牌面结构",
            value: boardTexture == .wet ? 0.7 : 0.3,
            weight: 0.15,
            description: "牌面: \(boardText)"
        ))
        
        factors.append(DecisionFactor(
            name: "玩家风格",
            value: profile.aggression,
            weight: 0.15,
            description: "风格: \(profile.name)"
        ))
        
        let isValueBet = equity > 0.6
        factors.append(DecisionFactor(
            name: "价值/诈笼",
            value: isValueBet ? 0.8 : 0.3,
            weight: 0.1,
            description: isValueBet ? "价值下注" : "诈笼/半诈笼"
        ))
        
        let reasoning = generatePostflopReasoning(
            action: action,
            equity: equity,
            potOdds: potOdds,
            boardTexture: boardTexture
        )
        
        let ev = calculateEV(equity: equity, potOdds: potOdds, action: action)
        
        return AIDecisionExplanation(
            playerId: profile.id,
            action: action,
            equity: equity,
            potOdds: potOdds,
            expectedValue: ev,
            factors: factors,
            reasoning: reasoning,
            confidence: 0.75
        )
    }
    
    private func generatePreflopReasoning(
        action: PlayerAction,
        chenScore: Double,
        position: TablePosition,
        callAmount: Int
    ) -> String {
        switch action {
        case .fold:
            if chenScore < 5 {
                return "手牌强度不足，选择弃牌"
            }
            return "位置不佳且手牌较弱，弃牌"
            
        case .check:
            return "过牌"
            
        case .call:
            if callAmount > 0 {
                return "手牌有潜力，跟注等待发展"
            }
            return "平跟进池"
            
        case .raise:
            if chenScore >= 10 {
                return "优质手牌，加注获取价值"
            } else if chenScore >= 7 {
                return "强手牌，加注或跟注"
            } else if position.stealability > 0.7 {
                return "后位有机会偷盲"
            }
            return "加注入池"
            
        case .allIn:
            return "强牌全下，追求最大价值"
        }
    }
    
    private func generatePostflopReasoning(
        action: PlayerAction,
        equity: Double,
        potOdds: Double,
        boardTexture: GameBoardTexture
    ) -> String {
        switch action {
        case .fold:
            if equity < potOdds {
                return "胜率不足，弃牌"
            }
            return "牌力不足，选择弃牌"
            
        case .check:
            return "控制底池，等待机会"
            
        case .call:
            if equity > potOdds {
                return "赔率合适，跟注"
            }
            return "跟注看牌"
            
        case .raise:
            if equity > 0.7 {
                return "强牌价值下注"
            } else if equity > 0.4 && boardTexture == .wet {
                return "半诈笼下注"
            }
            return "加注入池"
            
        case .allIn:
            return "最强牌型，全下"
        }
    }
    
    private func calculateEV(equity: Double, potOdds: Double, action: PlayerAction) -> Double {
        switch action {
        case .fold:
            return 0
        case .check:
            return 0
        case .call:
            return equity - potOdds
        case .raise, .allIn:
            return equity * 1.5 - potOdds
        }
    }
    
    func generateExplanationText(_ explanation: AIDecisionExplanation) -> String {
        var text = "🤖 AI决策分析\n\n"
        text += "行动: \(explanation.action.description)\n"
        text += "胜率: \(String(format: "%.1f%%", explanation.equity * 100))\n"
        text += "底池赔率: \(String(format: "%.1f%%", explanation.potOdds * 100))\n"
        text += "期望价值: \(String(format: "%.1f", explanation.expectedValue))\n\n"
        
        text += "决策因素:\n"
        for factor in explanation.factors.sorted(by: { $0.weight > $1.weight }) {
            let percent = Int(factor.value * 100)
            text += "• \(factor.name): \(percent)% (\(factor.description))\n"
        }
        
        text += "\n推理: \(explanation.reasoning)\n"
        
        return text
    }
}

class StrategyExplanationGenerator {
    static let shared = StrategyExplanationGenerator()
    
    private init() {}
    
    func explainICMAdjustment(_ adjustment: ICMStrategyAdjustment, situation: ICMSituation) -> String {
        var text = "🎯 ICM策略调整\n\n"
        
        text += "当前情况:\n"
        text += "• 剩余玩家: \(situation.playersRemaining)\n"
        text += "• 筹码比率: \(String(format: "%.2f", situation.stackRatio))\n"
        text += "• 泡沫期: \(situation.isBubble ? "是" : "否")\n"
        text += "• ICM压力: \(String(format: "%.1f%%", situation.pressure * 100))\n\n"
        
        text += "策略调整:\n"
        text += "• VPIP调整: \(adjustment.vpipAdjust > 0 ? "+" : "")\(Int(adjustment.vpipAdjust * 100))%\n"
        text += "• 侵略性调整: \(adjustment.aggressionAdjust > 0 ? "+" : "")\(Int(adjustment.aggressionAdjust * 100))%\n"
        text += "• 偷盲奖励: \(Int(adjustment.stealBonus * 100))%\n\n"
        
        text += "结论: \(adjustment.description)\n"
        
        return text
    }
    
    func explainTiltState(_ level: TiltLevel, recentEvents: Int) -> String {
        var text = "😤 情绪状态\n\n"
        
        text += "当前状态: \(level.description)\n"
        text += "近期触发: \(recentEvents) 次\n\n"
        
        switch level {
        case .calm:
            text += "状态: 冷静，决策正常\n"
        case .minor:
            text += "状态: 轻微波动，可能稍微激进\n"
        case .moderate:
            text += "状态: 情绪波动，决策受影响\n"
        case .severe:
            text += "状态: 严重上头，容易犯错\n"
        case .onTilt:
            text += "状态: 完全失控，建议暂停\n"
        }
        
        return text
    }
}
