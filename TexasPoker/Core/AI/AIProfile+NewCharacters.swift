import Foundation

// MARK: - AI Profile Extensions
/// 8 New AI Characters + Difficulty System

extension AIProfile {

    // MARK: - 8 New Characters

    /// 8. 新手鲍勃 (Newbie Bob) - Loose-Passive Fish
    /// VPIP 60%, PFR 5%, AF 0.8
    /// 经常limp入池，很少加注，喜欢跟注看牌
    static let newbieBob = AIProfile(
        id: "newbie_bob",
        name: "新手鲍勃",
        avatar: .emoji("🐟"),
        description: "刚学打牌，什么牌都玩，从不弃牌",
        tightness: 0.25,
        aggression: 0.08,
        bluffFreq: 0.02,
        foldTo3Bet: 0.10,
        cbetFreq: 0.05,        // 被动玩家很少c-bet
        cbetTurnFreq: 0.03,
        positionAwareness: 0.05,
        tiltSensitivity: 0.4,
        callDownTendency: 0.90,
        riskTolerance: 0.2,    // Very conservative
        bluffDetection: 0.1,  // Can't read opponents
        deepStackThreshold: 250 // Needs deep to play
    )
    
    /// 9. 紧弱玛丽 (Tight-Passive Mary)
    /// VPIP 12%, PFR 3%, AF 0.5
    /// 只打好牌，但是只跟注不加注，容易被挤出底池
    static let tightMary = AIProfile(
        id: "tight_mary",
        name: "玛丽",
        avatar: .emoji("🐢"),
        description: "只打好牌，但太被动，从不主动加注",
        tightness: 0.88,
        aggression: 0.15,
        bluffFreq: 0.01,
        foldTo3Bet: 0.45,
        cbetFreq: 0.10,        // 紧弱玩家很少c-bet
        cbetTurnFreq: 0.05,
        positionAwareness: 0.25,
        tiltSensitivity: 0.15,
        callDownTendency: 0.40,
        riskTolerance: 0.3,    // Conservative
        bluffDetection: 0.25,  // Low
        deepStackThreshold: 250 // Tight even deep
    )
    
    /// 10. 超紧尼特 (Nit Steve) - 比 Rock 更紧
    /// VPIP 6%, PFR 5%, AF 5.0
    /// 只玩 AA/KK/QQ/AK，几乎不参与任何牌
    static let nitSteve = AIProfile(
        id: "nit_steve",
        name: "史蒂夫",
        avatar: .emoji("🥶"),
        description: "超级紧凶，只玩顶级牌，一小时看不到几手牌",
        tightness: 0.95,
        aggression: 0.95,
        bluffFreq: 0.01,
        foldTo3Bet: 0.05,
        cbetFreq: 0.85,
        cbetTurnFreq: 0.70,
        positionAwareness: 0.15,
        tiltSensitivity: 0.05,
        callDownTendency: 0.05,
        riskTolerance: 0.2,    // Very conservative
        bluffDetection: 0.4,   // Normal
        deepStackThreshold: 300 // Never loosens
    )
    
    /// 11. 诈唬王杰克 (Bluffing Jack)
    /// VPIP 45%, PFR 40%, AF 4.5
    /// 经常诈唬，难读，但容易被抓
    static let bluffJack = AIProfile(
        id: "bluff_jack",
        name: "杰克",
        avatar: .emoji("🎭"),
        description: "诈唬狂魔，半池以上都是诈唬，容易被抓鸡",
        tightness: 0.40,
        aggression: 0.92,
        bluffFreq: 0.55,
        foldTo3Bet: 0.35,
        cbetFreq: 0.82,
        cbetTurnFreq: 0.68,
        positionAwareness: 0.70,
        tiltSensitivity: 0.25,
        callDownTendency: 0.20,
        riskTolerance: 0.85,   // Very aggressive
        bluffDetection: 0.35,   // Overestimates own skill
        deepStackThreshold: 150 // More bluffs deep
    )
    
    /// 12. 短筹码专家 (Short Stack Sam)
    /// 擅长 push/fold 策略，经常 all-in
    static let shortStackSam = AIProfile(
        id: "short_stack_sam",
        name: "山姆",
        avatar: .emoji("💰"),
        description: "短筹码专家，要么全下要么弃牌",
        tightness: 0.60,
        aggression: 0.95,
        bluffFreq: 0.15,
        foldTo3Bet: 0.35,     // 短筹码不应该频繁fold 3bet
        cbetFreq: 0.90,
        cbetTurnFreq: 0.80,
        positionAwareness: 0.90,
        tiltSensitivity: 0.10,
        callDownTendency: 0.10,
        riskTolerance: 0.8,    // Push/fold is high variance
        bluffDetection: 0.45,  // Normal
        deepStackThreshold: 100 // Only good when short
    )
    
    /// 13. 陷阱大师 (Trapper Tony)
    /// 喜欢慢打大牌，经常 check-raise
    static let trapperTony = AIProfile(
        id: "trapper_tony",
        name: "托尼",
        avatar: .emoji("🕸️"),
        description: "陷阱大师，喜欢慢打大牌，check-raise 高手",
        tightness: 0.50,
        aggression: 0.70,
        bluffFreq: 0.20,
        foldTo3Bet: 0.55,
        cbetFreq: 0.60,        // 正常c-bet频率，只是偶尔慢打
        cbetTurnFreq: 0.50,
        positionAwareness: 0.75,
        tiltSensitivity: 0.12,
        callDownTendency: 0.35,
        riskTolerance: 0.5,    // Balanced
        bluffDetection: 0.75,  // Good at trapping
        deepStackThreshold: 180 // Best when deep
    )
    
    /// 14. 天才少年 (Prodigy Pete)
    /// 适应性强，会根据对手调整策略
    static let prodigyPete = AIProfile(
        id: "prodigy_pete",
        name: "皮特",
        avatar: .emoji("🧠"),
        description: "天才少年，适应性强，会根据对手调整策略",
        tightness: 0.50,
        aggression: 0.65,
        bluffFreq: 0.28,
        foldTo3Bet: 0.50,
        cbetFreq: 0.68,
        cbetTurnFreq: 0.52,
        positionAwareness: 0.88,
        tiltSensitivity: 0.08,
        callDownTendency: 0.28,
        riskTolerance: 0.65,  // Good EV seeker
        bluffDetection: 0.8,  // Adapts well
        deepStackThreshold: 160 // Versatile
    )
    
    /// 15. 老手维克多 (Veteran Victor)
    /// 经验丰富，会针对对手弱点
    static let veteranVictor = AIProfile(
        id: "veteran_victor",
        name: "维克多",
        avatar: .emoji("🎖️"),
        description: "老牌高手，经验丰富，专门抓鱼",
        tightness: 0.52,
        aggression: 0.60,
        bluffFreq: 0.22,
        foldTo3Bet: 0.48,
        cbetFreq: 0.62,
        cbetTurnFreq: 0.48,
        positionAwareness: 0.82,
        tiltSensitivity: 0.05,
        callDownTendency: 0.30,
        riskTolerance: 0.55,  // Experienced
        bluffDetection: 0.85,  // Expert fish detector
        deepStackThreshold: 180 // Solid deep play
    )

    // MARK: - New 20 AI Characters

    /// 16. 纯鱼 (Pure Fish) - 完全随机的新手
    /// 没有任何策略，完全凭感觉
    static let pureFish = AIProfile(
        id: "pure_fish",
        name: "纯鱼",
        avatar: .emoji("🐠"),
        description: "完全随机的新手，不知道自己在玩什么",
        tightness: 0.35,
        aggression: 0.25,
        bluffFreq: 0.10,
        foldTo3Bet: 0.20,
        cbetFreq: 0.15,
        cbetTurnFreq: 0.08,
        positionAwareness: 0.02,
        tiltSensitivity: 0.5,
        callDownTendency: 0.80,
        riskTolerance: 0.5,
        bluffDetection: 0.05,
        deepStackThreshold: 200
    )

    /// 17. 跟注机器 (Call Machine) - 只跟注不弃牌
    static let callMachine = AIProfile(
        id: "call_machine",
        name: "跟注机器",
        avatar: .emoji("🤖"),
        description: "只会跟注，几乎不主动下注或弃牌",
        tightness: 0.20,
        aggression: 0.05,
        bluffFreq: 0.01,
        foldTo3Bet: 0.05,
        cbetFreq: 0.02,
        cbetTurnFreq: 0.01,
        positionAwareness: 0.05,
        tiltSensitivity: 0.3,
        callDownTendency: 0.95,
        riskTolerance: 0.1,
        bluffDetection: 0.08,
        deepStackThreshold: 250
    )

    /// 18. 胆小鬼 (Coward) - 极度紧弱
    static let coward = AIProfile(
        id: "coward",
        name: "胆小鬼",
        avatar: .emoji("😨"),
        description: "极度紧弱，稍微有点危险就弃牌",
        tightness: 0.92,
        aggression: 0.08,
        bluffFreq: 0.01,
        foldTo3Bet: 0.70,
        cbetFreq: 0.12,
        cbetTurnFreq: 0.05,
        positionAwareness: 0.15,
        tiltSensitivity: 0.6,
        callDownTendency: 0.10,
        riskTolerance: 0.05,
        bluffDetection: 0.20,
        deepStackThreshold: 300
    )

    /// 19. 红包 (Red Envelope) - 有钱任性的玩家
    static let redEnvelope = AIProfile(
        id: "red_envelope",
        name: "红包",
        avatar: .emoji("🧧"),
        description: "有钱任性，喜欢撒钱",
        tightness: 0.22,
        aggression: 0.35,
        bluffFreq: 0.25,
        foldTo3Bet: 0.15,
        cbetFreq: 0.30,
        cbetTurnFreq: 0.20,
        positionAwareness: 0.08,
        tiltSensitivity: 0.7,
        callDownTendency: 0.75,
        riskTolerance: 0.95,
        bluffDetection: 0.12,
        deepStackThreshold: 100
    )

    // === Normal 难度新增 (4个) ===

    /// 20. 正规军 (Regular) - 标准TAG
    static let regular = AIProfile(
        id: "regular",
        name: "正规军",
        avatar: .emoji("👮"),
        description: "标准TAG打法，正规军式稳健",
        tightness: 0.58,
        aggression: 0.65,
        bluffFreq: 0.20,
        foldTo3Bet: 0.50,
        cbetFreq: 0.62,
        cbetTurnFreq: 0.45,
        positionAwareness: 0.65,
        tiltSensitivity: 0.18,
        callDownTendency: 0.32,
        riskTolerance: 0.55,
        bluffDetection: 0.55,
        deepStackThreshold: 180
    )

    /// 21. 小捣蛋 (Little Devil) - 适度松凶
    static let littleDevil = AIProfile(
        id: "little_devil",
        name: "小捣蛋",
        avatar: .emoji("😈"),
        description: "适度松凶，偶尔捣蛋",
        tightness: 0.38,
        aggression: 0.72,
        bluffFreq: 0.35,
        foldTo3Bet: 0.38,
        cbetFreq: 0.70,
        cbetTurnFreq: 0.52,
        positionAwareness: 0.55,
        tiltSensitivity: 0.28,
        callDownTendency: 0.28,
        riskTolerance: 0.70,
        bluffDetection: 0.45,
        deepStackThreshold: 160
    )

    /// 22. 保守派 (Conservative) - 紧弱保守
    static let conservative = AIProfile(
        id: "conservative",
        name: "保守派",
        avatar: .emoji("📚"),
        description: "打牌保守谨慎，过于保守",
        tightness: 0.78,
        aggression: 0.22,
        bluffFreq: 0.05,
        foldTo3Bet: 0.55,
        cbetFreq: 0.25,
        cbetTurnFreq: 0.15,
        positionAwareness: 0.35,
        tiltSensitivity: 0.12,
        callDownTendency: 0.45,
        riskTolerance: 0.25,
        bluffDetection: 0.30,
        deepStackThreshold: 220
    )

    /// 23. 机会主义者 (Opportunist) - 等待机会
    static let opportunist = AIProfile(
        id: "opportunist",
        name: "机会主义者",
        avatar: .emoji("🎯"),
        description: "等待机会，一击必杀",
        tightness: 0.52,
        aggression: 0.58,
        bluffFreq: 0.18,
        foldTo3Bet: 0.45,
        cbetFreq: 0.55,
        cbetTurnFreq: 0.40,
        positionAwareness: 0.75,
        tiltSensitivity: 0.15,
        callDownTendency: 0.35,
        riskTolerance: 0.60,
        bluffDetection: 0.65,
        deepStackThreshold: 170
    )

    // === Hard 难度新增 (6个) ===

    /// 24. 职业牌手 (Pro Player) - 高手水平
    static let proPlayer = AIProfile(
        id: "pro_player",
        name: "职业牌手",
        avatar: .emoji("🏆"),
        description: "职业水平，稳健而致命",
        tightness: 0.55,
        aggression: 0.70,
        bluffFreq: 0.25,
        foldTo3Bet: 0.48,
        cbetFreq: 0.65,
        cbetTurnFreq: 0.50,
        positionAwareness: 0.82,
        tiltSensitivity: 0.08,
        callDownTendency: 0.28,
        riskTolerance: 0.65,
        bluffDetection: 0.75,
        deepStackThreshold: 160
    )

    /// 25. 心理战专家 (Psychological Warrior) - 心理战
    static let psychWarrior = AIProfile(
        id: "psych_warrior",
        name: "心理战专家",
        avatar: .emoji("🎭"),
        description: "擅长心理战术，让对手犯错",
        tightness: 0.45,
        aggression: 0.75,
        bluffFreq: 0.38,
        foldTo3Bet: 0.42,
        cbetFreq: 0.72,
        cbetTurnFreq: 0.55,
        positionAwareness: 0.78,
        tiltSensitivity: 0.20,
        callDownTendency: 0.25,
        riskTolerance: 0.72,
        bluffDetection: 0.80,
        deepStackThreshold: 150
    )

    /// 26. 剥削者 (Exploiter) - 针对弱点
    static let exploiter = AIProfile(
        id: "exploiter",
        name: "剥削者",
        avatar: .emoji("💎"),
        description: "专门剥削对手的弱点",
        tightness: 0.48,
        aggression: 0.68,
        bluffFreq: 0.22,
        foldTo3Bet: 0.52,
        cbetFreq: 0.60,
        cbetTurnFreq: 0.48,
        positionAwareness: 0.85,
        tiltSensitivity: 0.10,
        callDownTendency: 0.30,
        riskTolerance: 0.58,
        bluffDetection: 0.88,
        deepStackThreshold: 175
    )

    /// 27. 平衡大师 (Balance Master) - 攻守平衡
    static let balanceMaster = AIProfile(
        id: "balance_master",
        name: "平衡大师",
        avatar: .emoji("⚖️"),
        description: "完美平衡，难以针对",
        tightness: 0.52,
        aggression: 0.60,
        bluffFreq: 0.24,
        foldTo3Bet: 0.50,
        cbetFreq: 0.58,
        cbetTurnFreq: 0.44,
        positionAwareness: 0.80,
        tiltSensitivity: 0.05,
        callDownTendency: 0.34,
        riskTolerance: 0.55,
        bluffDetection: 0.72,
        deepStackThreshold: 190
    )

    /// 28. 价值猎手 (Value Hunter) - 追求价值
    static let valueHunter = AIProfile(
        id: "value_hunter",
        name: "价值猎手",
        avatar: .emoji("💰"),
        description: "追求最大价值，绝不便宜对手",
        tightness: 0.50,
        aggression: 0.78,
        bluffFreq: 0.15,
        foldTo3Bet: 0.45,
        cbetFreq: 0.75,
        cbetTurnFreq: 0.60,
        positionAwareness: 0.72,
        tiltSensitivity: 0.12,
        callDownTendency: 0.40,
        riskTolerance: 0.62,
        bluffDetection: 0.60,
        deepStackThreshold: 155
    )

    /// 29. 盲注掠夺者 (Blind Robber) - 偷盲专家
    static let blindRobber = AIProfile(
        id: "blind_robber",
        name: "盲注掠夺者",
        avatar: .emoji("🦹"),
        description: "专门偷盲注，胆大包天",
        tightness: 0.42,
        aggression: 0.85,
        bluffFreq: 0.48,
        foldTo3Bet: 0.30,
        cbetFreq: 0.82,
        cbetTurnFreq: 0.65,
        positionAwareness: 0.92,
        tiltSensitivity: 0.15,
        callDownTendency: 0.18,
        riskTolerance: 0.82,
        bluffDetection: 0.70,
        deepStackThreshold: 130
    )

    // === Expert 难度新增 (6个) ===

    /// 30. 终极鲨鱼 (Ultimate Shark) - 顶级猎手
    static let ultimateShark = AIProfile(
        id: "ultimate_shark",
        name: "终极鲨鱼",
        avatar: .emoji("🦈"),
        description: "顶级猎手，吞噬一切",
        tightness: 0.45,
        aggression: 0.85,
        bluffFreq: 0.30,
        foldTo3Bet: 0.42,
        cbetFreq: 0.80,
        cbetTurnFreq: 0.62,
        positionAwareness: 0.92,
        tiltSensitivity: 0.05,
        callDownTendency: 0.22,
        riskTolerance: 0.75,
        bluffDetection: 0.90,
        deepStackThreshold: 130
    )

    /// 31. 冷静刺客 (Cold Assassin) - 冷静杀手
    static let coldAssassin = AIProfile(
        id: "cold_assassin",
        name: "冷静刺客",
        avatar: .emoji("🗡️"),
        description: "冷静致命，一击必杀",
        tightness: 0.55,
        aggression: 0.72,
        bluffFreq: 0.28,
        foldTo3Bet: 0.52,
        cbetFreq: 0.68,
        cbetTurnFreq: 0.52,
        positionAwareness: 0.90,
        tiltSensitivity: 0.02,
        callDownTendency: 0.26,
        riskTolerance: 0.68,
        bluffDetection: 0.92,
        deepStackThreshold: 165
    )

    /// 32. 泡沫杀手 (Bubble Killer) - 锦标赛专家
    static let bubbleKiller = AIProfile(
        id: "bubble_killer",
        name: "泡沫杀手",
        avatar: .emoji("💣"),
        description: "锦标赛泡沫期专家",
        tightness: 0.60,
        aggression: 0.80,
        bluffFreq: 0.32,
        foldTo3Bet: 0.40,
        cbetFreq: 0.82,
        cbetTurnFreq: 0.65,
        positionAwareness: 0.85,
        tiltSensitivity: 0.08,
        callDownTendency: 0.20,
        riskTolerance: 0.72,
        bluffDetection: 0.78,
        deepStackThreshold: 145
    )

    /// 33. 全能战士 (All-Rounder) - 无明显弱点
    static let allRounder = AIProfile(
        id: "all_rounder",
        name: "全能战士",
        avatar: .emoji("🌟"),
        description: "全能型选手，无明显弱点",
        tightness: 0.50,
        aggression: 0.65,
        bluffFreq: 0.26,
        foldTo3Bet: 0.48,
        cbetFreq: 0.64,
        cbetTurnFreq: 0.50,
        positionAwareness: 0.86,
        tiltSensitivity: 0.04,
        callDownTendency: 0.30,
        riskTolerance: 0.62,
        bluffDetection: 0.82,
        deepStackThreshold: 170
    )

    /// 34. 读心术师 (Mind Reader) - 读牌专家
    static let mindReader = AIProfile(
        id: "mind_reader",
        name: "读心术师",
        avatar: .emoji("🔮"),
        description: "似乎能读懂对手的想法",
        tightness: 0.45,
        aggression: 0.78,
        bluffFreq: 0.28,
        foldTo3Bet: 0.45,
        cbetFreq: 0.70,
        cbetTurnFreq: 0.55,
        positionAwareness: 0.94,
        tiltSensitivity: 0.02,
        callDownTendency: 0.25,
        riskTolerance: 0.65,
        bluffDetection: 0.95,
        deepStackThreshold: 170
    )

    /// 35. 锦标赛冠军 (Tournament Champion) - 大赛型选手
    static let tournamentChampion = AIProfile(
        id: "tournament_champion",
        name: "锦标赛冠军",
        avatar: .emoji("👑"),
        description: "身经百战，冠军级别的选手",
        tightness: 0.48,
        aggression: 0.80,
        bluffFreq: 0.30,
        foldTo3Bet: 0.42,
        cbetFreq: 0.76,
        cbetTurnFreq: 0.60,
        positionAwareness: 0.92,
        tiltSensitivity: 0.04,
        callDownTendency: 0.22,
        riskTolerance: 0.75,
        bluffDetection: 0.88,
        deepStackThreshold: 155
    )

    // MARK: - All AI Profiles

    static let allProfiles: [AIProfile] = [
        .rock,           // 1. 石头
        .maniac,         // 2. 疯子麦克
        .callingStation, // 3. 安娜
        .fox,            // 4. 老狐狸
        .shark,          // 5. 鲨鱼汤姆
        .academic,       // 6. 艾米
        .tiltDavid,      // 7. 大卫
        .newbieBob,      // 8. 新手鲍勃
        .tightMary,      // 9. 玛丽
        .nitSteve,       // 10. 史蒂夫
        .bluffJack,      // 11. 杰克
        .shortStackSam,  // 12. 山姆
        .trapperTony,    // 13. 托尼
        .prodigyPete,    // 14. 皮特
        .veteranVictor,  // 15. 维克多
        // 新增20个
        .pureFish,       // 16. 纯鱼
        .callMachine,    // 17. 跟注机器
        .coward,         // 18. 胆小鬼
        .redEnvelope,    // 19. 红包
        .regular,        // 20. 正规军
        .littleDevil,    // 21. 小捣蛋
        .conservative,   // 22. 保守派
        .opportunist,    // 23. 机会主义者
        .proPlayer,      // 24. 职业牌手
        .psychWarrior,   // 25. 心理战专家
        .exploiter,      // 26. 剥削者
        .balanceMaster,  // 27. 平衡大师
        .valueHunter,    // 28. 价值猎手
        .blindRobber,    // 29. 盲注掠夺者
        .ultimateShark,  // 30. 终极鲨鱼
        .coldAssassin,   // 31. 冷静刺客
        .bubbleKiller,   // 32. 泡沫杀手
        .allRounder,     // 33. 全能战士
        .mindReader,     // 34. 读心术师
        .tournamentChampion, // 35. 锦标赛冠军
        // GTO风格角色
        .gtoMachine,        // 36. GTO机器
        .solver,            // 37. Solver
        .nitTag,            // 38. 紧凶派
        .lagPlayer,         // 39. 松凶派
        .mixedStrategist,    // 40. 混合策略家
        // 真实职业牌手
        .johnnyChan,        // 41. 陈强尼
        .davidChiu,         // 42. 邱芳全
        .alanDu,            // 43. 杜悦
        .zhouYinan,         // 44. 周懿楠
        .nickyJin,          // 45. 金韬
        // 国际牌手
        .philIvey,          // 46. Phil Ivey
        .danielNegreanu,    // 47. Daniel Negreanu
        .philHellmuth,     // 48. Phil Hellmuth
        .fedorHolz,         // 49. Fedor Holz
        .dougPolk,          // 50. Doug Polk
        .justinBonomo,      // 51. Justin Bonomo
        .patrikAntonius,    // 52. Patrik Antonius

        // GTO风格角色
        .gtoMachine,         // 36. GTO机器
        .solver,             // 37. Solver
        .nitTag,             // 38. 紧凶派
        .lagPlayer,          // 39. 松凶派
        .mixedStrategist,    // 40. 混合策略家

        // 真实职业牌手
        .johnnyChan,         // 41. 陈强尼
        .davidChiu,          // 42. 邱芳全
        .alanDu,             // 43. 杜悦
        .zhouYinan,          // 44. 周懿楠
        .nickyJin,           // 45. 金韬
        .philIvey,           // 46. Phil Ivey
        .danielNegreanu,     // 47. Daniel Negreanu
        .philHellmuth,       // 48. Phil Hellmuth
        .fedorHolz,          // 49. Fedor Holz
        .dougPolk,           // 50. Doug Polk
        .justinBonomo,       // 51. Justin Bonomo
        .patrikAntonius      // 52. Patrik Antonius
    ]

    // MARK: - GTO风格角色

    /// 36. GTO机器 (GTO Machine) - 严格GTO
    static let gtoMachine = AIProfile(
        id: "gto_machine",
        name: "GTO机器",
        avatar: .emoji("🤖"),
        description: "严格执行GTO策略，完美平衡",
        tightness: 0.50,
        aggression: 0.60,
        bluffFreq: 0.25,
        foldTo3Bet: 0.48,
        cbetFreq: 0.62,
        cbetTurnFreq: 0.48,
        positionAwareness: 0.85,
        tiltSensitivity: 0.01,
        callDownTendency: 0.32,
        riskTolerance: 0.55,
        bluffDetection: 0.88,
        deepStackThreshold: 180
    )

    /// 37. Solver (Solver) - 精确计算
        static let solver = AIProfile(
            id: "solver",
            name: "Solver",
            avatar: .emoji("🧮"),
            description: "像_solver一样精确计算每一步",
            tightness: 0.52,
            aggression: 0.58,
            bluffFreq: 0.24,
            foldTo3Bet: 0.50,
            cbetFreq: 0.60,
            cbetTurnFreq: 0.46,
            positionAwareness: 0.88,
            tiltSensitivity: 0.00,
            callDownTendency: 0.30,
            riskTolerance: 0.52,
            bluffDetection: 0.92,
            deepStackThreshold: 185
        )

        /// 38. 紧凶派 (NitTAG) - 紧凶GTO
        static let nitTag = AIProfile(
            id: "nit_tag",
            name: "紧凶派",
            avatar: .emoji("🎯"),
            description: "紧凶GTO打法，精准无比",
            tightness: 0.70,
            aggression: 0.75,
            bluffFreq: 0.18,
            foldTo3Bet: 0.40,
            cbetFreq: 0.75,
            cbetTurnFreq: 0.58,
            positionAwareness: 0.80,
            tiltSensitivity: 0.03,
            callDownTendency: 0.22,
            riskTolerance: 0.60,
            bluffDetection: 0.75,
            deepStackThreshold: 170
        )

        /// 39. 松凶派 (LAG) - 松凶GTO
        static let lagPlayer = AIProfile(
            id: "lag_player",
            name: "松凶派",
            avatar: .emoji("🔥"),
            description: "松凶GTO打法，激进无比",
            tightness: 0.35,
            aggression: 0.82,
            bluffFreq: 0.35,
            foldTo3Bet: 0.35,
            cbetFreq: 0.78,
            cbetTurnFreq: 0.60,
            positionAwareness: 0.85,
            tiltSensitivity: 0.08,
            callDownTendency: 0.25,
            riskTolerance: 0.75,
            bluffDetection: 0.70,
            deepStackThreshold: 140
        )

        /// 40. 混合策略家 (Mixed Strategist) - 随机混合
        static let mixedStrategist = AIProfile(
            id: "mixed_strategist",
            name: "混合策略家",
            avatar: .emoji("🎲"),
            description: "使用混合策略，难以预测",
            tightness: 0.50,
            aggression: 0.62,
            bluffFreq: 0.28,
            foldTo3Bet: 0.48,
            cbetFreq: 0.65,
            cbetTurnFreq: 0.50,
            positionAwareness: 0.82,
            tiltSensitivity: 0.05,
            callDownTendency: 0.32,
            riskTolerance: 0.58,
            bluffDetection: 0.78,
            deepStackThreshold: 175
        )

        // MARK: - 真实职业牌手角色

        /// 41. 陈强尼 (Johnny Chan) - "东方快车"
        /// 10条WSOP金手链，1987-1988连续WSOP主赛冠军，《赌神》高进原型
        /// 喜怒不形于色，令对手难以捉摸
        static let johnnyChan = AIProfile(
            id: "johnny_chan",
            name: "陈强尼",
            avatar: .image("johnny_chan"),
            description: "东方快车，10条金手链得主，喜怒不形于色",
            tightness: 0.55,
            aggression: 0.72,
            bluffFreq: 0.28,
            foldTo3Bet: 0.45,
            cbetFreq: 0.68,
            cbetTurnFreq: 0.52,
            positionAwareness: 0.85,
            tiltSensitivity: 0.08,
            callDownTendency: 0.30,
            riskTolerance: 0.65,
            bluffDetection: 0.82,
            deepStackThreshold: 165
        )

        /// 42. 邱芳全 (David Chiu) - "老邱"
        /// 5条WSOP金手链，WPT冠军，华裔牌手传奇
        static let davidChiu = AIProfile(
            id: "david_chiu",
            name: "邱芳全",
            avatar: .image("david_chiu"),
            description: "老邱，5条金手链，稳健著称",
            tightness: 0.60,
            aggression: 0.58,
            bluffFreq: 0.20,
            foldTo3Bet: 0.50,
            cbetFreq: 0.62,
            cbetTurnFreq: 0.48,
            positionAwareness: 0.78,
            tiltSensitivity: 0.10,
            callDownTendency: 0.35,
            riskTolerance: 0.50,
            bluffDetection: 0.75,
            deepStackThreshold: 180
        )

        /// 43. 杜悦 (Alan Du) - 中国首位WSOP冠军
        /// 2016年WSOP金手链得主，前人人网副总裁
        static let alanDu = AIProfile(
            id: "alan_du",
            name: "杜悦",
            avatar: .image("alan_du"),
            description: "中国首位WSOP冠军，理性决策",
            tightness: 0.52,
            aggression: 0.65,
            bluffFreq: 0.25,
            foldTo3Bet: 0.48,
            cbetFreq: 0.65,
            cbetTurnFreq: 0.50,
            positionAwareness: 0.80,
            tiltSensitivity: 0.12,
            callDownTendency: 0.32,
            riskTolerance: 0.58,
            bluffDetection: 0.72,
            deepStackThreshold: 175
        )

        /// 44. 周懿楠 (Zhou Yinan) - 中国WSOP主赛冠军
        /// 2024年WSOP天堂岛超级主赛冠军，中国主赛第一人
        static let zhouYinan = AIProfile(
            id: "zhou_yinan",
            name: "周懿楠",
            avatar: .image("zhou_yinan"),
            description: "中国首位WSOP主赛冠军，年轻气盛",
            tightness: 0.45,
            aggression: 0.78,
            bluffFreq: 0.30,
            foldTo3Bet: 0.40,
            cbetFreq: 0.72,
            cbetTurnFreq: 0.55,
            positionAwareness: 0.82,
            tiltSensitivity: 0.15,
            callDownTendency: 0.28,
            riskTolerance: 0.70,
            bluffDetection: 0.68,
            deepStackThreshold: 155
        )

        /// 45. 金韬 (Nicky Jin) - "百万先生"
        /// 4条WSOP金手链，85个比赛冠军
        static let nickyJin = AIProfile(
            id: "nicky_jin",
            name: "金韬",
            avatar: .image("nicky_jin"),
            description: "百万先生，4条金手链，网络战绩辉煌",
            tightness: 0.48,
            aggression: 0.75,
            bluffFreq: 0.28,
            foldTo3Bet: 0.42,
            cbetFreq: 0.70,
            cbetTurnFreq: 0.54,
            positionAwareness: 0.80,
            tiltSensitivity: 0.18,
            callDownTendency: 0.30,
            riskTolerance: 0.68,
            bluffDetection: 0.70,
            deepStackThreshold: 160
        )

        // === 国际知名牌手 ===

        /// 46. Phil Ivey - "扑克王子"
        /// 10条WSOP金手链，被誉为史上最伟大牌手
        static let philIvey = AIProfile(
            id: "phil_ivey",
            name: "Phil Ivey",
            avatar: .image("phil_ivey"),
            description: "扑克王子，史上最伟大牌手之一",
            tightness: 0.38,
            aggression: 0.85,
            bluffFreq: 0.35,
            foldTo3Bet: 0.38,
            cbetFreq: 0.78,
            cbetTurnFreq: 0.60,
            positionAwareness: 0.90,
            tiltSensitivity: 0.05,
            callDownTendency: 0.25,
            riskTolerance: 0.75,
            bluffDetection: 0.88,
            deepStackThreshold: 145
        )

        /// 47. Daniel Negreanu - "大丹牛"
        /// 6条WSOP金手链，锦标赛盈利历史第一
        static let danielNegreanu = AIProfile(
            id: "daniel_negreanu",
            name: "Daniel Negreanu",
            avatar: .image("daniel_negreanu"),
            description: "大丹牛，高情商，读人能力超强",
            tightness: 0.55,
            aggression: 0.70,
            bluffFreq: 0.22,
            foldTo3Bet: 0.48,
            cbetFreq: 0.65,
            cbetTurnFreq: 0.50,
            positionAwareness: 0.85,
            tiltSensitivity: 0.12,
            callDownTendency: 0.35,
            riskTolerance: 0.58,
            bluffDetection: 0.80,
            deepStackThreshold: 170
        )

        /// 48. Phil Hellmuth - "扑克顽童"
        /// 14条WSOP金手链，历史第一
        /// 注意：他的夸张情绪是表演风格，实际决策能力很强
        static let philHellmuth = AIProfile(
            id: "phil_hellmuth",
            name: "Phil Hellmuth",
            avatar: .image("phil_hellmuth"),
            description: "扑克顽童，14条金手链，历史第一人",
            tightness: 0.50,
            aggression: 0.72,
            bluffFreq: 0.22,
            foldTo3Bet: 0.48,
            cbetFreq: 0.65,
            cbetTurnFreq: 0.52,
            positionAwareness: 0.80,
            tiltSensitivity: 0.25,
            callDownTendency: 0.30,
            riskTolerance: 0.60,
            bluffDetection: 0.78,
            deepStackThreshold: 170
        )

        /// 49. Fedor Holz - "德国王子"
        /// 年轻天才，32岁退休，$3000万+
        static let fedorHolz = AIProfile(
            id: "fedor_holz",
            name: "Fedor Holz",
            avatar: .image("fedor_holz"),
            description: "德国王子，年轻轻冠军，情绪管理大师",
            tightness: 0.42,
            aggression: 0.80,
            bluffFreq: 0.32,
            foldTo3Bet: 0.40,
            cbetFreq: 0.75,
            cbetTurnFreq: 0.58,
            positionAwareness: 0.85,
            tiltSensitivity: 0.08,
            callDownTendency: 0.26,
            riskTolerance: 0.72,
            bluffDetection: 0.78,
            deepStackThreshold: 150
        )

        /// 50. Doug Polk - GTO大师
        /// 将GTO理论发扬光大，单挑无敌
        static let dougPolk = AIProfile(
            id: "doug_polk",
            name: "Doug Polk",
            avatar: .image("doug_polk"),
            description: "GTO先驱，单挑王者",
            tightness: 0.50,
            aggression: 0.68,
            bluffFreq: 0.26,
            foldTo3Bet: 0.50,
            cbetFreq: 0.65,
            cbetTurnFreq: 0.52,
            positionAwareness: 0.88,
            tiltSensitivity: 0.05,
            callDownTendency: 0.30,
            riskTolerance: 0.60,
            bluffDetection: 0.82,
            deepStackThreshold: 170
        )

        /// 51. Justin Bonomo - "Boon"
        /// $4300万+总收入，历史第二
        static let justinBonomo = AIProfile(
            id: "justin_bonomo",
            name: "Justin Bonomo",
            avatar: .image("justin_bonomo"),
            description: "Boon，锦标赛历史第二收入",
            tightness: 0.48,
            aggression: 0.72,
            bluffFreq: 0.28,
            foldTo3Bet: 0.45,
            cbetFreq: 0.68,
            cbetTurnFreq: 0.52,
            positionAwareness: 0.82,
            tiltSensitivity: 0.10,
            callDownTendency: 0.28,
            riskTolerance: 0.65,
            bluffDetection: 0.75,
            deepStackThreshold: 165
        )

        /// 52. Patrik Antonius - 芬兰冰人
        /// 高额桌传奇，冷静著称
        static let patrikAntonius = AIProfile(
            id: "patrik_antonius",
            name: "Patrik Antonius",
            avatar: .image("patrik_antonius"),
            description: "芬兰冰人，高额桌传奇",
            tightness: 0.45,
            aggression: 0.78,
            bluffFreq: 0.32,
            foldTo3Bet: 0.42,
            cbetFreq: 0.72,
            cbetTurnFreq: 0.55,
            positionAwareness: 0.85,
            tiltSensitivity: 0.03,
            callDownTendency: 0.26,
            riskTolerance: 0.70,
            bluffDetection: 0.78,
            deepStackThreshold: 155
        )

    // MARK: - Difficulty Levels
    
    enum Difficulty: String, CaseIterable, Identifiable {
        case easy = "简单"
        case normal = "普通"
        case hard = "困难"
        case expert = "专家"
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .easy: return "适合新手，对手较弱"
            case .normal: return "平衡体验，标准难度"
            case .hard: return "有挑战性，对手较强"
            case .expert: return "地狱模式，顶级对手"
            }
        }

        /// Profiles available at this difficulty level
        var availableProfiles: [AIProfile] {
            switch self {
            case .easy:
                // 8人: 纯鱼、跟注机器、胆小鬼、红包、新手鲍勃、玛丽、安娜、疯子麦克
                return [.pureFish, .callMachine, .coward, .redEnvelope,
                       .newbieBob, .tightMary, .callingStation, .maniac]
            case .normal:
                // 8人: 正规军、小捣蛋、保守派、机会主义者 + Easy角色
                return [.regular, .littleDevil, .conservative, .opportunist,
                       .pureFish, .callMachine, .coward, .redEnvelope]
            case .hard:
                // 8人+: 职业牌手、心理战专家、剥削者、平衡大师、价值猎手、盲注掠夺者 + Expert角色
                return [.proPlayer, .psychWarrior, .exploiter, .balanceMaster,
                       .valueHunter, .blindRobber, .shark, .academic]
            case .expert:
                // 8人+: 终极鲨鱼、冷静刺客 + 读心术师、锦标赛冠军 + 真实职业牌手
                return [.ultimateShark, .coldAssassin,
                       .mindReader, .tournamentChampion,
                       // 国际顶级牌手
                       .philIvey, .danielNegreanu, .philHellmuth,
                       .fedorHolz, .dougPolk, .justinBonomo,
                       // 华裔牌手
                       .johnnyChan, .davidChiu]
            }
        }
        
        /// Returns random opponents for a game
        func randomOpponents(count: Int) -> [AIProfile] {
            let pool = availableProfiles
            guard !pool.isEmpty else { return [] }
            
            var selected: [AIProfile] = []
            var available = pool
            
            for _ in 0..<count {
                guard !available.isEmpty else { break }
                
                if let index = available.indices.randomElement() {
                    let profile = available[index]
                    selected.append(profile)
                    available.remove(at: index)
                }
            }
            return selected
        }
    }
    
    // MARK: - Tournament Entry System
    
    /// Random entry for tournament (can be called at any time)
    /// Returns new player to add to table
    static func randomTournamentEntry(difficulty: Difficulty, startingChips: Int) -> Player {
        let profile = difficulty.availableProfiles.randomElement() ?? .fox
        return Player(
            name: profile.name,
            chips: startingChips,
            isHuman: false,
            aiProfile: profile,
            entryIndex: 1
        )
    }
    
    /// Random entry with custom starting stack based on tournament stage
    static func randomTournamentEntry(
        difficulty: Difficulty,
        stage: TournamentStage,
        averageStack: Int
    ) -> Player {
        let profile = difficulty.availableProfiles.randomElement() ?? .fox
        
        // Late stage players get adjusted stacks
        let startingChips: Int
        switch stage {
        case .early:
            startingChips = averageStack
        case .middle:
            startingChips = Int(Double(averageStack) * 0.8)
        case .late:
            startingChips = Int(Double(averageStack) * 0.6)
        case .finalTable:
            startingChips = Int(Double(averageStack) * 0.5)
        }
        
        return Player(
            name: profile.name,
            chips: max(1000, startingChips),
            isHuman: false,
            aiProfile: profile,
            entryIndex: 1
        )
    }
}

// MARK: - Tournament Stage
enum TournamentStage {
    case early      // First few levels
    case middle     // Middle levels
    case late       // Approaching bubble
    case finalTable // Final table
    
    static func from(handNumber: Int, totalPlayers: Int) -> TournamentStage {
        let eliminationRate = Double(handNumber) / Double(totalPlayers * 10)
        
        switch eliminationRate {
        case 0..<0.3:
            return .early
        case 0.3..<0.6:
            return .middle
        case 0.6..<0.85:
            return .late
        default:
            return .finalTable
        }
    }
}

// MARK: - Game Setup Helper
struct GameSetup {
    let difficulty: AIProfile.Difficulty
    let playerCount: Int
    let startingChips: Int
    let gameMode: GameMode
    
    /// Generates player list including Hero and AI opponents
    func generatePlayers(heroName: String = "Hero") -> [Player] {
        var players: [Player] = []
        
        // Add Hero
        players.append(Player(name: heroName, chips: startingChips, isHuman: true))
        
        // Add AI opponents
        let aiCount = min(playerCount - 1, 7) // Max 8 players total
        let profiles = difficulty.randomOpponents(count: aiCount)
        
        for profile in profiles {
            players.append(Player(
                name: profile.name,
                chips: startingChips,
                isHuman: false,
                aiProfile: profile
            ))
        }
        
        return players
    }
    
    /// Static method for quick setup
    static func quickSetup(
        difficulty: AIProfile.Difficulty = .normal,
        playerCount: Int = 6,
        startingChips: Int = 1000,
        gameMode: GameMode = .cashGame
    ) -> GameSetup {
        return GameSetup(
            difficulty: difficulty,
            playerCount: playerCount,
            startingChips: startingChips,
            gameMode: gameMode
        )
    }
}
