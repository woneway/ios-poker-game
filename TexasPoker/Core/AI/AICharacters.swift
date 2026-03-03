import Foundation
import SwiftUI

// MARK: - AI Characters

extension AIProfile {

    // MARK: - Basic Characters (1-7)

    static let rock = AIProfile(
        id: "rock", name: "石头", avatar: .emoji("🗿"),
        description: "超紧玩家，只玩顶级牌",
        tightness: 0.95, aggression: 0.50, bluffFreq: 0.0, foldTo3Bet: 0.95,
        cbetFreq: 0.95, cbetTurnFreq: 0.80, positionAwareness: 0.10, tiltSensitivity: 0.02,
        callDownTendency: 0.02, riskTolerance: 0.05, bluffDetection: 0.10, deepStackThreshold: 300
    )

    static let maniac = AIProfile(
        id: "maniac", name: "疯子麦克", avatar: .emoji("🤪"),
        description: "松凶型玩家，什么都敢加注",
        tightness: 0.15, aggression: 0.98, bluffFreq: 0.75, foldTo3Bet: 0.08,
        cbetFreq: 0.98, cbetTurnFreq: 0.90, positionAwareness: 0.30, tiltSensitivity: 0.25,
        callDownTendency: 0.08, riskTolerance: 0.98, bluffDetection: 0.15, deepStackThreshold: 80
    )

    static let callingStation = AIProfile(
        id: "calling_station", name: "安娜", avatar: .emoji("🧘"),
        description: "跟注站，什么都跟注",
        tightness: 0.40, aggression: 0.10, bluffFreq: 0.02, foldTo3Bet: 0.05,
        cbetFreq: 0.15, cbetTurnFreq: 0.08, positionAwareness: 0.15, tiltSensitivity: 0.30,
        callDownTendency: 0.98, riskTolerance: 0.25, bluffDetection: 0.05, deepStackThreshold: 250
    )

    static let fox = AIProfile(
        id: "fox", name: "老狐狸", avatar: .emoji("🦊"),
        description: "平衡型高手，难以读牌",
        tightness: 0.50, aggression: 0.70, bluffFreq: 0.25, foldTo3Bet: 0.45,
        cbetFreq: 0.70, cbetTurnFreq: 0.50, positionAwareness: 0.85, tiltSensitivity: 0.10,
        callDownTendency: 0.25, riskTolerance: 0.65, bluffDetection: 0.75, deepStackThreshold: 180
    )

    static let shark = AIProfile(
        id: "shark", name: "鲨鱼汤姆", avatar: .emoji("🦈"),
        description: "位置意识极强，后位杀手",
        tightness: 0.45, aggression: 0.80, bluffFreq: 0.30, foldTo3Bet: 0.40,
        cbetFreq: 0.80, cbetTurnFreq: 0.60, positionAwareness: 0.98, tiltSensitivity: 0.08,
        callDownTendency: 0.20, riskTolerance: 0.75, bluffDetection: 0.90, deepStackThreshold: 140
    )

    static let academic = AIProfile(
        id: "academic", name: "艾米", avatar: .emoji("🎓"),
        description: "严格GTO，数学驱动，不可利用",
        tightness: 0.52, aggression: 0.62, bluffFreq: 0.25, foldTo3Bet: 0.48,
        cbetFreq: 0.60, cbetTurnFreq: 0.42, positionAwareness: 0.85, tiltSensitivity: 0.02,
        callDownTendency: 0.35, riskTolerance: 0.6, bluffDetection: 0.9, deepStackThreshold: 200,
        useGTOStrategy: true
    )

    static let tiltDavid = AIProfile(
        id: "tilt_david", name: "大卫", avatar: .emoji("😤"),
        description: "输钱后情绪化，容易上头",
        tightness: 0.60, aggression: 0.45, bluffFreq: 0.15, foldTo3Bet: 0.55,
        cbetFreq: 0.50, cbetTurnFreq: 0.35, positionAwareness: 0.45, tiltSensitivity: 0.95,
        callDownTendency: 0.35, riskTolerance: 0.40, bluffDetection: 0.35, deepStackThreshold: 200
    )

    // MARK: - Extended Characters (8-52)

    static let newbieBob = AIProfile(
        id: "newbie_bob", name: "新手鲍勃", avatar: .emoji("🐟"),
        description: "刚学打牌，什么牌都玩，从不弃牌",
        tightness: 0.25, aggression: 0.08, bluffFreq: 0.02, foldTo3Bet: 0.10,
        cbetFreq: 0.05, cbetTurnFreq: 0.03, positionAwareness: 0.05, tiltSensitivity: 0.4,
        callDownTendency: 0.90, riskTolerance: 0.2, bluffDetection: 0.1, deepStackThreshold: 250
    )

    static let tightMary = AIProfile(
        id: "tight_mary", name: "玛丽", avatar: .emoji("🐢"),
        description: "只打好牌，但太被动，从不主动加注",
        tightness: 0.88, aggression: 0.15, bluffFreq: 0.01, foldTo3Bet: 0.45,
        cbetFreq: 0.10, cbetTurnFreq: 0.05, positionAwareness: 0.25, tiltSensitivity: 0.15,
        callDownTendency: 0.40, riskTolerance: 0.3, bluffDetection: 0.25, deepStackThreshold: 250
    )

    static let nitSteve = AIProfile(
        id: "nit_steve", name: "史蒂夫", avatar: .emoji("🥶"),
        description: "超级紧凶，只玩顶级牌",
        tightness: 0.95, aggression: 0.95, bluffFreq: 0.01, foldTo3Bet: 0.05,
        cbetFreq: 0.85, cbetTurnFreq: 0.70, positionAwareness: 0.15, tiltSensitivity: 0.05,
        callDownTendency: 0.05, riskTolerance: 0.2, bluffDetection: 0.4, deepStackThreshold: 300
    )

    static let bluffJack = AIProfile(
        id: "bluff_jack", name: "杰克", avatar: .emoji("🎭"),
        description: "诈唬狂魔，容易被抓鸡",
        tightness: 0.40, aggression: 0.92, bluffFreq: 0.55, foldTo3Bet: 0.35,
        cbetFreq: 0.82, cbetTurnFreq: 0.68, positionAwareness: 0.70, tiltSensitivity: 0.25,
        callDownTendency: 0.20, riskTolerance: 0.85, bluffDetection: 0.35, deepStackThreshold: 150
    )

    static let shortStackSam = AIProfile(
        id: "short_stack_sam", name: "山姆", avatar: .emoji("📊"),
        description: "擅长push-fold策略",
        tightness: 0.60, aggression: 0.85, bluffFreq: 0.35, foldTo3Bet: 0.30,
        cbetFreq: 0.75, cbetTurnFreq: 0.55, positionAwareness: 0.65, tiltSensitivity: 0.20,
        callDownTendency: 0.15, riskTolerance: 0.80, bluffDetection: 0.45, deepStackThreshold: 50
    )

    static let trapperTony = AIProfile(
        id: "trapper_tony", name: "托尼", avatar: .emoji("🕸️"),
        description: "设置陷阱，诱敌深入",
        tightness: 0.58, aggression: 0.45, bluffFreq: 0.15, foldTo3Bet: 0.55,
        cbetFreq: 0.35, cbetTurnFreq: 0.30, positionAwareness: 0.75, tiltSensitivity: 0.12,
        callDownTendency: 0.45, riskTolerance: 0.50, bluffDetection: 0.65, deepStackThreshold: 200
    )

    static let prodigyPete = AIProfile(
        id: "prodigy_pete", name: "皮特", avatar: .emoji("🎓"),
        description: "年轻气盛，技术超群",
        tightness: 0.45, aggression: 0.82, bluffFreq: 0.32, foldTo3Bet: 0.42,
        cbetFreq: 0.72, cbetTurnFreq: 0.58, positionAwareness: 0.88, tiltSensitivity: 0.18,
        callDownTendency: 0.22, riskTolerance: 0.72, bluffDetection: 0.75, deepStackThreshold: 160
    )

    static let veteranVictor = AIProfile(
        id: "veteran_victor", name: "维克多", avatar: .emoji("🎖️"),
        description: "经验丰富，稳如泰山",
        tightness: 0.62, aggression: 0.55, bluffFreq: 0.18, foldTo3Bet: 0.50,
        cbetFreq: 0.60, cbetTurnFreq: 0.48, positionAwareness: 0.82, tiltSensitivity: 0.08,
        callDownTendency: 0.35, riskTolerance: 0.55, bluffDetection: 0.72, deepStackThreshold: 190
    )

    static let pureFish = AIProfile(
        id: "pure_fish", name: "纯鱼", avatar: .emoji("🐠"),
        description: "完全随机，什么都玩",
        tightness: 0.15, aggression: 0.05, bluffFreq: 0.05, foldTo3Bet: 0.05,
        cbetFreq: 0.10, cbetTurnFreq: 0.05, positionAwareness: 0.02, tiltSensitivity: 0.30,
        callDownTendency: 0.95, riskTolerance: 0.1, bluffDetection: 0.05, deepStackThreshold: 300
    )

    static let callMachine = AIProfile(
        id: "call_machine", name: "跟注机器", avatar: .emoji("🔄"),
        description: "只跟注不弃牌",
        tightness: 0.20, aggression: 0.05, bluffFreq: 0.01, foldTo3Bet: 0.02,
        cbetFreq: 0.08, cbetTurnFreq: 0.05, positionAwareness: 0.10, tiltSensitivity: 0.25,
        callDownTendency: 0.98, riskTolerance: 0.15, bluffDetection: 0.08, deepStackThreshold: 250
    )

    static let coward = AIProfile(
        id: "coward", name: "胆小鬼", avatar: .emoji("😨"),
        description: "极度紧弱，稍有风吹草动就弃牌",
        tightness: 0.92, aggression: 0.08, bluffFreq: 0.01, foldTo3Bet: 0.80,
        cbetFreq: 0.15, cbetTurnFreq: 0.08, positionAwareness: 0.20, tiltSensitivity: 0.35,
        callDownTendency: 0.10, riskTolerance: 0.1, bluffDetection: 0.15, deepStackThreshold: 300
    )

    static let redEnvelope = AIProfile(
        id: "red_envelope", name: "红包", avatar: .emoji("🧧"),
        description: "有钱任性，输赢不在乎",
        tightness: 0.25, aggression: 0.55, bluffFreq: 0.30, foldTo3Bet: 0.15,
        cbetFreq: 0.55, cbetTurnFreq: 0.45, positionAwareness: 0.50, tiltSensitivity: 0.05,
        callDownTendency: 0.60, riskTolerance: 0.95, bluffDetection: 0.20, deepStackThreshold: 100
    )

    static let regular = AIProfile(
        id: "regular", name: "正规军", avatar: .emoji("📋"),
        description: "标准TAG打法",
        tightness: 0.58, aggression: 0.65, bluffFreq: 0.20, foldTo3Bet: 0.48,
        cbetFreq: 0.62, cbetTurnFreq: 0.46, positionAwareness: 0.72, tiltSensitivity: 0.12,
        callDownTendency: 0.28, riskTolerance: 0.55, bluffDetection: 0.60, deepStackThreshold: 175
    )

    static let littleDevil = AIProfile(
        id: "little_devil", name: "小捣蛋", avatar: .emoji("😈"),
        description: "适度松凶，偶尔搞事",
        tightness: 0.42, aggression: 0.72, bluffFreq: 0.35, foldTo3Bet: 0.38,
        cbetFreq: 0.68, cbetTurnFreq: 0.52, positionAwareness: 0.78, tiltSensitivity: 0.22,
        callDownTendency: 0.25, riskTolerance: 0.68, bluffDetection: 0.55, deepStackThreshold: 155
    )

    static let conservative = AIProfile(
        id: "conservative", name: "保守派", avatar: .emoji("🛡️"),
        description: "紧弱保守，求稳",
        tightness: 0.80, aggression: 0.25, bluffFreq: 0.05, foldTo3Bet: 0.60,
        cbetFreq: 0.25, cbetTurnFreq: 0.15, positionAwareness: 0.35, tiltSensitivity: 0.18,
        callDownTendency: 0.35, riskTolerance: 0.25, bluffDetection: 0.30, deepStackThreshold: 250
    )

    static let opportunist = AIProfile(
        id: "opportunist", name: "机会主义者", avatar: .emoji("🎯"),
        description: "等待机会，一击必杀",
        tightness: 0.55, aggression: 0.70, bluffFreq: 0.25, foldTo3Bet: 0.45,
        cbetFreq: 0.58, cbetTurnFreq: 0.45, positionAwareness: 0.85, tiltSensitivity: 0.10,
        callDownTendency: 0.30, riskTolerance: 0.60, bluffDetection: 0.70, deepStackThreshold: 165
    )

    static let proPlayer = AIProfile(
        id: "pro_player", name: "职业牌手", avatar: .emoji("🏆"),
        description: "高水平职业玩家",
        tightness: 0.50, aggression: 0.75, bluffFreq: 0.28, foldTo3Bet: 0.44,
        cbetFreq: 0.70, cbetTurnFreq: 0.55, positionAwareness: 0.90, tiltSensitivity: 0.05,
        callDownTendency: 0.25, riskTolerance: 0.70, bluffDetection: 0.80, deepStackThreshold: 150
    )

    static let psychWarrior = AIProfile(
        id: "psych_warrior", name: "心理战专家", avatar: .emoji("🧠"),
        description: "心理战高手",
        tightness: 0.48, aggression: 0.72, bluffFreq: 0.32, foldTo3Bet: 0.42,
        cbetFreq: 0.68, cbetTurnFreq: 0.52, positionAwareness: 0.82, tiltSensitivity: 0.15,
        callDownTendency: 0.28, riskTolerance: 0.65, bluffDetection: 0.85, deepStackThreshold: 160
    )

    static let exploiter = AIProfile(
        id: "exploiter", name: "剥削者", avatar: .emoji("🔪"),
        description: "针对对手弱点",
        tightness: 0.52, aggression: 0.70, bluffFreq: 0.26, foldTo3Bet: 0.46,
        cbetFreq: 0.65, cbetTurnFreq: 0.50, positionAwareness: 0.88, tiltSensitivity: 0.08,
        callDownTendency: 0.30, riskTolerance: 0.62, bluffDetection: 0.78, deepStackThreshold: 170
    )

    static let balanceMaster = AIProfile(
        id: "balance_master", name: "平衡大师", avatar: .emoji("⚖️"),
        description: "攻守平衡，无懈可击",
        tightness: 0.52, aggression: 0.62, bluffFreq: 0.25, foldTo3Bet: 0.48,
        cbetFreq: 0.62, cbetTurnFreq: 0.48, positionAwareness: 0.85, tiltSensitivity: 0.03,
        callDownTendency: 0.32, riskTolerance: 0.58, bluffDetection: 0.75, deepStackThreshold: 175
    )

    static let valueHunter = AIProfile(
        id: "value_hunter", name: "价值猎手", avatar: .emoji("💎"),
        description: "追求最大价值",
        tightness: 0.55, aggression: 0.78, bluffFreq: 0.18, foldTo3Bet: 0.50,
        cbetFreq: 0.72, cbetTurnFreq: 0.58, positionAwareness: 0.80, tiltSensitivity: 0.10,
        callDownTendency: 0.28, riskTolerance: 0.65, bluffDetection: 0.68, deepStackThreshold: 145
    )

    static let blindRobber = AIProfile(
        id: "blind_robber", name: "盲注掠夺者", avatar: .emoji("🥷"),
        description: "偷盲专家",
        tightness: 0.40, aggression: 0.88, bluffFreq: 0.45, foldTo3Bet: 0.32,
        cbetFreq: 0.80, cbetTurnFreq: 0.65, positionAwareness: 0.92, tiltSensitivity: 0.20,
        callDownTendency: 0.18, riskTolerance: 0.75, bluffDetection: 0.55, deepStackThreshold: 135
    )

    static let ultimateShark = AIProfile(
        id: "ultimate_shark", name: "终极鲨鱼", avatar: .emoji("🦈"),
        description: "顶级猎手，吞噬一切",
        tightness: 0.45, aggression: 0.85, bluffFreq: 0.30, foldTo3Bet: 0.42,
        cbetFreq: 0.80, cbetTurnFreq: 0.62, positionAwareness: 0.92, tiltSensitivity: 0.05,
        callDownTendency: 0.22, riskTolerance: 0.75, bluffDetection: 0.90, deepStackThreshold: 130,
        useGTOStrategy: true
    )

    static let coldAssassin = AIProfile(
        id: "cold_assassin", name: "冷静刺客", avatar: .emoji("❄️"),
        description: "冷静杀手，一击必杀",
        tightness: 0.58, aggression: 0.82, bluffFreq: 0.28, foldTo3Bet: 0.40,
        cbetFreq: 0.78, cbetTurnFreq: 0.60, positionAwareness: 0.88, tiltSensitivity: 0.03,
        callDownTendency: 0.20, riskTolerance: 0.70, bluffDetection: 0.82, deepStackThreshold: 145
    )

    static let bubbleKiller = AIProfile(
        id: "bubble_killer", name: "泡沫杀手", avatar: .emoji("💣"),
        description: "锦标赛泡沫期专家",
        tightness: 0.60, aggression: 0.80, bluffFreq: 0.32, foldTo3Bet: 0.40,
        cbetFreq: 0.82, cbetTurnFreq: 0.65, positionAwareness: 0.85, tiltSensitivity: 0.08,
        callDownTendency: 0.20, riskTolerance: 0.72, bluffDetection: 0.78, deepStackThreshold: 145,
        useGTOStrategy: true
    )

    static let allRounder = AIProfile(
        id: "all_rounder", name: "全能战士", avatar: .emoji("🌟"),
        description: "无明显弱点",
        tightness: 0.52, aggression: 0.65, bluffFreq: 0.24, foldTo3Bet: 0.46,
        cbetFreq: 0.64, cbetTurnFreq: 0.50, positionAwareness: 0.82, tiltSensitivity: 0.06,
        callDownTendency: 0.32, riskTolerance: 0.58, bluffDetection: 0.72, deepStackThreshold: 170
    )

    static let mindReader = AIProfile(
        id: "mind_reader", name: "读心术师", avatar: .emoji("🔮"),
        description: "似乎能读懂对手的想法",
        tightness: 0.45, aggression: 0.78, bluffFreq: 0.28, foldTo3Bet: 0.45,
        cbetFreq: 0.70, cbetTurnFreq: 0.55, positionAwareness: 0.94, tiltSensitivity: 0.02,
        callDownTendency: 0.25, riskTolerance: 0.65, bluffDetection: 0.95, deepStackThreshold: 170,
        useGTOStrategy: true
    )

    static let tournamentChampion = AIProfile(
        id: "tournament_champion", name: "锦标赛冠军", avatar: .emoji("👑"),
        description: "身经百战，冠军级别的选手",
        tightness: 0.48, aggression: 0.80, bluffFreq: 0.30, foldTo3Bet: 0.42,
        cbetFreq: 0.76, cbetTurnFreq: 0.60, positionAwareness: 0.92, tiltSensitivity: 0.04,
        callDownTendency: 0.22, riskTolerance: 0.75, bluffDetection: 0.88, deepStackThreshold: 155,
        useGTOStrategy: true
    )

    static let gtoMachine = AIProfile(
        id: "gto_machine", name: "GTO机器", avatar: .emoji("🤖"),
        description: "严格执行GTO策略，完美平衡",
        tightness: 0.50, aggression: 0.60, bluffFreq: 0.25, foldTo3Bet: 0.48,
        cbetFreq: 0.62, cbetTurnFreq: 0.48, positionAwareness: 0.85, tiltSensitivity: 0.01,
        callDownTendency: 0.32, riskTolerance: 0.55, bluffDetection: 0.88, deepStackThreshold: 180,
        useGTOStrategy: true
    )

    static let solver = AIProfile(
        id: "solver", name: "Solver", avatar: .emoji("🧮"),
        description: "像_solver一样精确计算每一步",
        tightness: 0.52, aggression: 0.58, bluffFreq: 0.24, foldTo3Bet: 0.50,
        cbetFreq: 0.60, cbetTurnFreq: 0.46, positionAwareness: 0.88, tiltSensitivity: 0.00,
        callDownTendency: 0.30, riskTolerance: 0.52, bluffDetection: 0.92, deepStackThreshold: 185,
        useGTOStrategy: true
    )

    static let nitTag = AIProfile(
        id: "nit_tag", name: "紧凶派", avatar: .emoji("🎯"),
        description: "紧凶GTO打法，精准无比",
        tightness: 0.70, aggression: 0.75, bluffFreq: 0.18, foldTo3Bet: 0.40,
        cbetFreq: 0.75, cbetTurnFreq: 0.58, positionAwareness: 0.80, tiltSensitivity: 0.03,
        callDownTendency: 0.22, riskTolerance: 0.60, bluffDetection: 0.75, deepStackThreshold: 170
    )

    static let lagPlayer = AIProfile(
        id: "lag_player", name: "松凶派", avatar: .emoji("🔥"),
        description: "松凶GTO打法，激进无比",
        tightness: 0.35, aggression: 0.82, bluffFreq: 0.35, foldTo3Bet: 0.35,
        cbetFreq: 0.78, cbetTurnFreq: 0.60, positionAwareness: 0.85, tiltSensitivity: 0.08,
        callDownTendency: 0.25, riskTolerance: 0.75, bluffDetection: 0.70, deepStackThreshold: 140
    )

    static let mixedStrategist = AIProfile(
        id: "mixed_strategist", name: "混合策略家", avatar: .emoji("🎲"),
        description: "使用混合策略，难以预测",
        tightness: 0.50, aggression: 0.62, bluffFreq: 0.28, foldTo3Bet: 0.48,
        cbetFreq: 0.65, cbetTurnFreq: 0.50, positionAwareness: 0.82, tiltSensitivity: 0.05,
        callDownTendency: 0.32, riskTolerance: 0.58, bluffDetection: 0.78, deepStackThreshold: 175,
        useGTOStrategy: true
    )

    static let johnnyChan = AIProfile(
        id: "johnny_chan", name: "陈强尼", avatar: .emoji("🚂"),
        description: "东方快车，10条WSOP金手链",
        tightness: 0.48, aggression: 0.78, bluffFreq: 0.30, foldTo3Bet: 0.44,
        cbetFreq: 0.74, cbetTurnFreq: 0.58, positionAwareness: 0.90, tiltSensitivity: 0.02,
        callDownTendency: 0.24, riskTolerance: 0.72, bluffDetection: 0.85, deepStackThreshold: 150
    )

    static let davidChiu = AIProfile(
        id: "david_chiu", name: "邱芳全", avatar: .emoji("🐉"),
        description: "老邱，5条WSOP金手链",
        tightness: 0.55, aggression: 0.72, bluffFreq: 0.24, foldTo3Bet: 0.48,
        cbetFreq: 0.68, cbetTurnFreq: 0.52, positionAwareness: 0.85, tiltSensitivity: 0.05,
        callDownTendency: 0.30, riskTolerance: 0.60, bluffDetection: 0.78, deepStackThreshold: 165
    )

    static let alanDu = AIProfile(
        id: "alan_du", name: "杜悦", avatar: .emoji("🇨🇳"),
        description: "中国首位WSOP冠军",
        tightness: 0.52, aggression: 0.75, bluffFreq: 0.26, foldTo3Bet: 0.46,
        cbetFreq: 0.70, cbetTurnFreq: 0.55, positionAwareness: 0.88, tiltSensitivity: 0.04,
        callDownTendency: 0.26, riskTolerance: 0.68, bluffDetection: 0.80, deepStackThreshold: 155
    )

    static let zhouYinan = AIProfile(
        id: "zhou_yinan", name: "周懿楠", avatar: .emoji("🏅"),
        description: "中国WSOP主赛冠军",
        tightness: 0.50, aggression: 0.80, bluffFreq: 0.28, foldTo3Bet: 0.44,
        cbetFreq: 0.75, cbetTurnFreq: 0.58, positionAwareness: 0.90, tiltSensitivity: 0.03,
        callDownTendency: 0.24, riskTolerance: 0.72, bluffDetection: 0.82, deepStackThreshold: 145
    )

    static let nickyJin = AIProfile(
        id: "nicky_jin", name: "金韬", avatar: .emoji("💰"),
        description: "百万先生，4条WSOP金手链",
        tightness: 0.48, aggression: 0.82, bluffFreq: 0.32, foldTo3Bet: 0.42,
        cbetFreq: 0.78, cbetTurnFreq: 0.62, positionAwareness: 0.92, tiltSensitivity: 0.04,
        callDownTendency: 0.22, riskTolerance: 0.78, bluffDetection: 0.78, deepStackThreshold: 140
    )

    static let philIvey = AIProfile(
        id: "phil_ivey", name: "Phil Ivey", avatar: .emoji("🃏"),
        description: "扑克王子，10条WSOP金手链",
        tightness: 0.45, aggression: 0.85, bluffFreq: 0.32, foldTo3Bet: 0.40,
        cbetFreq: 0.80, cbetTurnFreq: 0.65, positionAwareness: 0.95, tiltSensitivity: 0.02,
        callDownTendency: 0.20, riskTolerance: 0.80, bluffDetection: 0.90, deepStackThreshold: 130
    )

    static let danielNegreanu = AIProfile(
        id: "daniel_negreanu", name: "Daniel Negreanu", avatar: .emoji("🐂"),
        description: "大丹牛，6条WSOP金手链",
        tightness: 0.42, aggression: 0.88, bluffFreq: 0.35, foldTo3Bet: 0.38,
        cbetFreq: 0.82, cbetTurnFreq: 0.68, positionAwareness: 0.94, tiltSensitivity: 0.06,
        callDownTendency: 0.18, riskTolerance: 0.82, bluffDetection: 0.88, deepStackThreshold: 125
    )

    static let philHellmuth = AIProfile(
        id: "phil_hellmuth", name: "Phil Hellmuth", avatar: .emoji("😤"),
        description: "扑克顽童，14条WSOP金手链历史第一",
        tightness: 0.58, aggression: 0.70, bluffFreq: 0.22, foldTo3Bet: 0.50,
        cbetFreq: 0.65, cbetTurnFreq: 0.48, positionAwareness: 0.80, tiltSensitivity: 0.25,
        callDownTendency: 0.30, riskTolerance: 0.55, bluffDetection: 0.75, deepStackThreshold: 175
    )

    static let fedorHolz = AIProfile(
        id: "fedor_holz", name: "Fedor Holz", avatar: .emoji("🇩🇪"),
        description: "德国王子，冠军级表现",
        tightness: 0.48, aggression: 0.82, bluffFreq: 0.30, foldTo3Bet: 0.42,
        cbetFreq: 0.78, cbetTurnFreq: 0.62, positionAwareness: 0.92, tiltSensitivity: 0.02,
        callDownTendency: 0.22, riskTolerance: 0.75, bluffDetection: 0.85, deepStackThreshold: 140
    )

    static let dougPolk = AIProfile(
        id: "doug_polk", name: "Doug Polk", avatar: .emoji("📺"),
        description: "GTO大师",
        tightness: 0.50, aggression: 0.78, bluffFreq: 0.28, foldTo3Bet: 0.45,
        cbetFreq: 0.75, cbetTurnFreq: 0.58, positionAwareness: 0.90, tiltSensitivity: 0.03,
        callDownTendency: 0.25, riskTolerance: 0.70, bluffDetection: 0.82, deepStackThreshold: 150
    )

    static let justinBonomo = AIProfile(
        id: "justin_bonomo", name: "Justin Bonomo", avatar: .emoji("💵"),
        description: "Boon，锦标赛盈利王",
        tightness: 0.46, aggression: 0.80, bluffFreq: 0.30, foldTo3Bet: 0.42,
        cbetFreq: 0.76, cbetTurnFreq: 0.60, positionAwareness: 0.88, tiltSensitivity: 0.02,
        callDownTendency: 0.24, riskTolerance: 0.72, bluffDetection: 0.80, deepStackThreshold: 145
    )

    static let patrikAntonius = AIProfile(
        id: "patrik_antonius", name: "Patrik Antonius", avatar: .emoji("🇫🇮"),
        description: "芬兰冰人",
        tightness: 0.52, aggression: 0.85, bluffFreq: 0.28, foldTo3Bet: 0.44,
        cbetFreq: 0.78, cbetTurnFreq: 0.62, positionAwareness: 0.92, tiltSensitivity: 0.01,
        callDownTendency: 0.22, riskTolerance: 0.75, bluffDetection: 0.85, deepStackThreshold: 135
    )

    // MARK: - All Profiles

    static let allProfiles: [AIProfile] = [
        .rock, .maniac, .callingStation, .fox, .shark, .academic, .tiltDavid,
        .newbieBob, .tightMary, .nitSteve, .bluffJack, .shortStackSam, .trapperTony, .prodigyPete, .veteranVictor,
        .pureFish, .callMachine, .coward, .redEnvelope, .regular, .littleDevil, .conservative, .opportunist,
        .proPlayer, .psychWarrior, .exploiter, .balanceMaster, .valueHunter, .blindRobber,
        .ultimateShark, .coldAssassin, .bubbleKiller, .allRounder, .mindReader, .tournamentChampion,
        .gtoMachine, .solver, .nitTag, .lagPlayer, .mixedStrategist,
        .johnnyChan, .davidChiu, .alanDu, .zhouYinan, .nickyJin,
        .philIvey, .danielNegreanu, .philHellmuth, .fedorHolz, .dougPolk, .justinBonomo, .patrikAntonius
    ]

    static var allAvailableProfiles: [AIProfile] { allProfiles }

    static var emojiMap: [String: String] {
        var map: [String: String] = [:]
        for profile in allProfiles {
            if case .emoji(let emoji) = profile.avatar {
                map[profile.name] = emoji
            }
        }
        return map
    }

    static func emoji(for playerName: String) -> String {
        emojiMap[playerName] ?? "🎭"
    }

    static let balanced = fox
}
