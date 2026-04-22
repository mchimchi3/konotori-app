import Foundation

// MARK: - Milestone Enum

enum Milestone: String, CaseIterable, Codable {
    // Pre-birth (weeks before due date, negative offset)
    case week36PreBirth = "week36_pre_birth"  // 4 weeks before due date
    case week32PreBirth = "week32_pre_birth"  // 8 weeks before due date
    case week28PreBirth = "week28_pre_birth"  // 12 weeks before due date

    // Post-birth milestones
    case week4  = "week4"
    case week8  = "week8"
    case week12 = "week12"
    case week16 = "week16"
    case week20 = "week20"
    case week24 = "week24"
    case month6 = "month6"
    case month7 = "month7"
    case month8 = "month8"
    case month9 = "month9"
    case month10 = "month10"
    case month11 = "month11"
    case month12 = "month12"
    case month15 = "month15"
    case month18 = "month18"
    case month21 = "month21"
    case month24 = "month24"

    // MARK: - Display Name

    var displayName: String {
        switch self {
        case .week36PreBirth: return "出産4週前"
        case .week32PreBirth: return "出産8週前"
        case .week28PreBirth: return "出産12週前"
        case .week4:  return "生後4週"
        case .week8:  return "生後8週"
        case .week12: return "生後3ヶ月"
        case .week16: return "生後4ヶ月"
        case .week20: return "生後5ヶ月"
        case .week24: return "生後6ヶ月"
        case .month6: return "生後6ヶ月"
        case .month7: return "生後7ヶ月"
        case .month8: return "生後8ヶ月"
        case .month9: return "生後9ヶ月"
        case .month10: return "生後10ヶ月"
        case .month11: return "生後11ヶ月"
        case .month12: return "生後1歳"
        case .month15: return "生後1歳3ヶ月"
        case .month18: return "生後1歳6ヶ月"
        case .month21: return "生後1歳9ヶ月"
        case .month24: return "生後2歳"
        }
    }

    // MARK: - Offset from Reference Date

    /// Returns the number of days from the reference date (dueDate or birthDate).
    var dayOffsetFromReferenceDate: Int {
        switch self {
        // Pre-birth: negative offset from due date
        case .week36PreBirth: return -28   // 4 weeks before
        case .week32PreBirth: return -56   // 8 weeks before
        case .week28PreBirth: return -84   // 12 weeks before

        // Post-birth: positive offset from birth date
        case .week4:   return 28
        case .week8:   return 56
        case .week12:  return 84
        case .week16:  return 112
        case .week20:  return 140
        case .week24:  return 168
        case .month6:  return 182
        case .month7:  return 213
        case .month8:  return 243
        case .month9:  return 274
        case .month10: return 304
        case .month11: return 335
        case .month12: return 365
        case .month15: return 456
        case .month18: return 547
        case .month21: return 638
        case .month24: return 730
        }
    }

    /// Whether this milestone uses dueDate (true) or birthDate (false) as anchor.
    var usesPreBirthAnchor: Bool {
        switch self {
        case .week36PreBirth, .week32PreBirth, .week28PreBirth:
            return true
        default:
            return false
        }
    }

    // MARK: - Notification Title & Body

    var notificationTitle: String {
        switch self {
        case .week36PreBirth: return "出産まであと4週！準備を始めましょう"
        case .week32PreBirth: return "出産まであと8週！必需品リストを確認"
        case .week28PreBirth: return "出産まであと12週！早めの準備を"
        case .week4:  return "\(displayName)おめでとう！"
        case .week8:  return "\(displayName)！成長が楽しみですね"
        case .week12: return "\(displayName)！首すわりの時期です"
        case .week16: return "\(displayName)！寝返りを始める子も"
        case .week20: return "\(displayName)！離乳食の準備を始めましょう"
        case .week24, .month6:  return "\(displayName)！離乳食スタート"
        case .month7: return "\(displayName)！もぐもぐ期です"
        case .month8: return "\(displayName)！ハイハイが盛んな時期"
        case .month9: return "\(displayName)！つかまり立ちが始まる頃"
        case .month10: return "\(displayName)！つたい歩きの時期"
        case .month11: return "もうすぐ1歳！お誕生日の準備を"
        case .month12: return "1歳のお誕生日おめでとう！"
        case .month15: return "\(displayName)！歩く練習が本格的に"
        case .month18: return "\(displayName)！言葉が増える時期"
        case .month21: return "\(displayName)！自分でやりたがる時期"
        case .month24: return "2歳のお誕生日おめでとう！"
        }
    }

    var notificationBody: String {
        switch self {
        case .week36PreBirth: return "入院バッグや新生児グッズの確認を。おすすめアイテムをチェックしましょう。"
        case .week32PreBirth: return "ベビーベッドや授乳グッズの準備はできていますか？"
        case .week28PreBirth: return "マタニティウェアや産前産後のサポートグッズを準備しましょう。"
        case .week4:  return "新生児に必要なアイテムをチェック！おすすめ商品を見てみましょう。"
        case .week8:  return "この時期に役立つグッズをご紹介します。"
        case .week12: return "バウンサーやプレイマットが活躍する時期です。"
        case .week16: return "ファンのある場所でも過ごしやすいグッズをご紹介。"
        case .week20: return "離乳食グッズの準備を始める時期です。"
        case .week24, .month6: return "ブレンダーや食器など、離乳食グッズをチェック！"
        case .month7: return "もぐもぐ期に便利な食器やスタイをご紹介。"
        case .month8: return "赤ちゃんの行動範囲が広がります。安全グッズを確認しましょう。"
        case .month9: return "コーナーガードやベビーゲートが活躍する時期です。"
        case .month10: return "ファーストシューズの準備を始めましょう。"
        case .month11: return "1歳のお誕生日プレゼントを探してみましょう。"
        case .month12: return "ファーストバースデーを盛大に祝いましょう！"
        case .month15: return "歩き始めの靴や外遊びグッズをご紹介。"
        case .month18: return "言葉を育てる絵本やおもちゃをチェック！"
        case .month21: return "自分でできる練習グッズをご紹介します。"
        case .month24: return "2歳になりました！成長を振り返りましょう。"
        }
    }
}

// MARK: - NotificationSchedule

struct NotificationSchedule: Identifiable, Equatable {
    let id: UUID
    let milestone: Milestone
    let scheduledDate: Date
    let productURL: URL?
    let babyProfileID: UUID

    init(
        id: UUID = UUID(),
        milestone: Milestone,
        referenceDate: Date,
        productURL: URL? = nil,
        babyProfileID: UUID
    ) {
        self.id = id
        self.milestone = milestone
        self.productURL = productURL
        self.babyProfileID = babyProfileID

        // Compute scheduled date: referenceDate + offset days, then normalized to 9:00 AM
        let rawDate = Calendar.current.date(
            byAdding: .day,
            value: milestone.dayOffsetFromReferenceDate,
            to: referenceDate
        ) ?? referenceDate

        var components = Calendar.current.dateComponents([.year, .month, .day], from: rawDate)
        components.hour = 9
        components.minute = 0
        components.second = 0
        self.scheduledDate = Calendar.current.date(from: components) ?? rawDate
    }

    // MARK: - UNNotificationRequest

    func makeNotificationContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = milestone.notificationTitle
        content.body = milestone.notificationBody
        content.sound = .default
        content.badge = 1

        var userInfo: [String: Any] = ["milestoneID": milestone.rawValue]
        if let url = productURL {
            userInfo["productURL"] = url.absoluteString
        }
        content.userInfo = userInfo
        return content
    }

    var isFuture: Bool {
        scheduledDate > Date()
    }
}

import UserNotifications
