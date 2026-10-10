//
//  PremiumGreetingManager.swift
//  osimono
//
//  プレミアム限定: 推しから朝・夜のメッセージが通知で届く。誕生日・記念日には特別なメッセージになる。
//
//  サーバープッシュは使わず、アプリ起動時に次の朝・夜の分をAIで先に生成してローカル通知として予約する。
//  予約した本文は UserDefaults に保持し、配信時刻を過ぎたらチャット履歴に保存する。
//

import Foundation
import UserNotifications

// MARK: - 日付まわり（Foundationのみ・テスト可能）

enum GreetingSchedule {
    enum Slot: String, CaseIterable, Codable {
        case morning, night

        var hour: Int { self == .morning ? 8 : 22 }
    }

    enum Occasion: Equatable {
        case birthday
        case anniversary(days: Int)
    }

    /// 記念日として特別なメッセージを送る「推し始めてからの日数」（365日ごとも対象）
    static let anniversaryMilestones: Set<Int> = [30, 100, 200, 300, 500, 1000]

    /// now より後の、各スロットの次の配信時刻
    static func upcomingSlots(after now: Date, calendar: Calendar = .current) -> [(slot: Slot, date: Date)] {
        Slot.allCases.compactMap { slot in
            let components = DateComponents(hour: slot.hour, minute: 0, second: 0)
            guard let date = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) else { return nil }
            return (slot, date)
        }
        .sorted { $0.date < $1.date }
    }

    /// 自由入力の誕生日（例: "1月1日", "2000/1/1", "01-01", "January 1"）から月日を取り出す
    static func parseMonthDay(_ text: String?) -> (month: Int, day: Int)? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }

        let numbers = text
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .filter { !$0.isEmpty }
            .compactMap { Int($0) }

        var month: Int?
        var day: Int?

        let monthNames = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        let lowered = text.lowercased()
        if let index = monthNames.firstIndex(where: { lowered.contains($0) }) {
            month = index + 1
            day = numbers.first { $0 >= 1 && $0 <= 31 }
        } else if numbers.count >= 3, numbers[0] >= 1000 {
            month = numbers[1]
            day = numbers[2]
        } else if numbers.count >= 2 {
            month = numbers[0]
            day = numbers[1]
        }

        guard let m = month, let d = day, (1...12).contains(m), (1...31).contains(d) else { return nil }
        return (m, d)
    }

    static func occasion(on date: Date, birthday: String?, createdAt: TimeInterval?, calendar: Calendar = .current) -> Occasion? {
        let components = calendar.dateComponents([.month, .day], from: date)
        if let birthday = parseMonthDay(birthday), birthday.month == components.month, birthday.day == components.day {
            return .birthday
        }
        if let createdAt = createdAt {
            let start = calendar.startOfDay(for: Date(timeIntervalSince1970: createdAt))
            let days = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day ?? 0
            if days > 0 && (anniversaryMilestones.contains(days) || days % 365 == 0) {
                return .anniversary(days: days)
            }
        }
        return nil
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

// MARK: - Manager

final class PremiumGreetingManager: NSObject {
    static let shared = PremiumGreetingManager()

    struct PendingGreeting: Codable, Equatable {
        let id: String
        let oshiId: String
        let content: String
        let fireAt: TimeInterval
        let isOccasion: Bool
    }

    private let enabledKey = "premiumGreetingsEnabled"
    private let pendingKey = "premiumGreetingsPending"
    private let occasionSentKeyPrefix = "premiumGreetingOccasionSent_"
    private let identifierPrefix = "oshi_greeting_"
    private let stateQueue = DispatchQueue(label: "PremiumGreetingManager.state")
    private var isRefreshing = false
    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
    }

    /// 設定画面のON/OFF（初期値ON）
    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            if !newValue {
                cancelScheduled()
            }
        }
    }

    // MARK: - Public

    /// アプリ起動・復帰時に呼ぶ。届いた分をチャットに保存し、次の朝・夜の分を予約し直す
    func refresh(for oshi: Oshi?) {
        deliverDueGreetings()

        guard let oshi = oshi, !oshi.id.isEmpty else { return }
        guard PremiumFeatures.isActive, isEnabled else {
            cancelScheduled()
            return
        }

        let started: Bool = stateQueue.sync {
            if isRefreshing { return false }
            isRefreshing = true
            return true
        }
        guard started else { return }

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            self.sendTodaysOccasionIfNeeded(for: oshi) {
                if granted {
                    self.scheduleUpcoming(for: oshi) { self.finishRefresh() }
                } else {
                    self.finishRefresh()
                }
            }
        }
    }

    /// 配信時刻を過ぎた予約メッセージをチャット履歴に保存する
    func deliverDueGreetings(now: Date = Date()) {
        let due: [PendingGreeting] = stateQueue.sync {
            let pending = loadPending()
            let due = pending.filter { $0.fireAt <= now.timeIntervalSince1970 }
            if !due.isEmpty {
                savePending(pending.filter { $0.fireAt > now.timeIntervalSince1970 })
            }
            return due
        }

        for greeting in due {
            if greeting.isOccasion {
                markOccasionSent(oshiId: greeting.oshiId, date: Date(timeIntervalSince1970: greeting.fireAt))
            }
            let message = ChatMessage(
                id: greeting.id,
                content: greeting.content,
                isUser: false,
                timestamp: greeting.fireAt,
                oshiId: greeting.oshiId
            )
            ChatDatabaseManager.shared.saveMessage(message) { error in
                if let error = error {
                    print("❌ 推しからの定期メッセージの保存に失敗: \(error.localizedDescription)")
                }
            }
        }
    }

    func cancelScheduled() {
        let ids: [String] = stateQueue.sync {
            let pending = loadPending()
            savePending([])
            return pending.map { identifierPrefix + $0.id }
        }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Scheduling

    private func finishRefresh() {
        stateQueue.sync { isRefreshing = false }
    }

    private func scheduleUpcoming(for oshi: Oshi, completion: @escaping () -> Void) {
        let now = Date()
        let slots = GreetingSchedule.upcomingSlots(after: now)
        let slotTimes = Set(slots.map { $0.date.timeIntervalSince1970 })

        // 別の推しに切り替えた・時刻が変わった予約は取り消す
        let (stale, existing): ([PendingGreeting], [PendingGreeting]) = stateQueue.sync {
            let pending = loadPending()
            let future = pending.filter { $0.fireAt > now.timeIntervalSince1970 }
            let stale = future.filter { $0.oshiId != oshi.id || !slotTimes.contains($0.fireAt) }
            savePending(pending.filter { !stale.contains($0) })
            return (stale, pending.filter { !stale.contains($0) })
        }
        center.removePendingNotificationRequests(withIdentifiers: stale.map { identifierPrefix + $0.id })

        let missing = slots.filter { slot in
            !existing.contains { $0.oshiId == oshi.id && $0.fireAt == slot.date.timeIntervalSince1970 }
        }
        guard !missing.isEmpty else {
            completion()
            return
        }

        ChatDatabaseManager.shared.fetchRecentMessagesOnce(for: oshi.id, limit: 12) { messages, _ in
            let history = messages ?? []
            let group = DispatchGroup()

            for (slot, date) in missing {
                group.enter()
                let occasion = slot == .morning
                    ? GreetingSchedule.occasion(on: date, birthday: oshi.birthday, createdAt: oshi.createdAt)
                    : nil
                AIMessageGenerator.shared.generateGreetingMessage(
                    for: oshi,
                    instruction: { Self.instruction(slot: slot, occasion: occasion, language: $0) },
                    chatHistory: history
                ) { content, error in
                    defer { group.leave() }
                    guard let content = content?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
                        if let error = error {
                            print("❌ 推しからの定期メッセージの生成に失敗: \(error.localizedDescription)")
                        }
                        return
                    }
                    let greeting = PendingGreeting(
                        id: UUID().uuidString,
                        oshiId: oshi.id,
                        content: content,
                        fireAt: date.timeIntervalSince1970,
                        isOccasion: occasion != nil
                    )
                    self.schedule(greeting, oshiName: oshi.name, date: date)
                }
            }

            group.notify(queue: .global(qos: .utility), execute: completion)
        }
    }

    private func schedule(_ greeting: PendingGreeting, oshiName: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = oshiName
        content.body = greeting.content
        content.sound = .default
        content.userInfo = ["oshiId": greeting.oshiId, "type": "oshi_greeting"]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifierPrefix + greeting.id, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("❌ 推しからの定期メッセージの予約に失敗: \(error.localizedDescription)")
                return
            }
            self.stateQueue.sync {
                var pending = self.loadPending()
                // 同じ推し・同じ時刻の予約が並行して作られていたら後から来た方を捨てる
                if pending.contains(where: { $0.oshiId == greeting.oshiId && $0.fireAt == greeting.fireAt }) {
                    self.center.removePendingNotificationRequests(withIdentifiers: [self.identifierPrefix + greeting.id])
                    return
                }
                pending.append(greeting)
                self.savePending(pending)
            }
        }
    }

    // MARK: - Birthday / anniversary

    /// 今日が誕生日・記念日で、まだ特別メッセージを送っていなければ、アプリを開いたタイミングでチャットに届ける
    private func sendTodaysOccasionIfNeeded(for oshi: Oshi, completion: @escaping () -> Void) {
        let now = Date()
        guard let occasion = GreetingSchedule.occasion(on: now, birthday: oshi.birthday, createdAt: oshi.createdAt),
              !isOccasionSent(oshiId: oshi.id, date: now) else {
            completion()
            return
        }

        // 今日の朝に届く予約がまだ残っているなら、そちらに任せる
        let todayKey = GreetingSchedule.dayKey(for: now)
        let hasPendingToday: Bool = stateQueue.sync {
            loadPending().contains {
                $0.oshiId == oshi.id && $0.isOccasion && GreetingSchedule.dayKey(for: Date(timeIntervalSince1970: $0.fireAt)) == todayKey
            }
        }
        guard !hasPendingToday else {
            completion()
            return
        }

        ChatDatabaseManager.shared.fetchRecentMessagesOnce(for: oshi.id, limit: 12) { messages, _ in
            AIMessageGenerator.shared.generateGreetingMessage(
                for: oshi,
                instruction: { Self.instruction(slot: nil, occasion: occasion, language: $0) },
                chatHistory: messages ?? []
            ) { content, _ in
                guard let content = content?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
                    completion()
                    return
                }
                self.markOccasionSent(oshiId: oshi.id, date: now)
                let message = ChatMessage(
                    id: UUID().uuidString,
                    content: content,
                    isUser: false,
                    timestamp: Date().timeIntervalSince1970,
                    oshiId: oshi.id
                )
                ChatDatabaseManager.shared.saveMessage(message) { _ in completion() }
            }
        }
    }

    private func occasionSentKey(oshiId: String, date: Date) -> String {
        occasionSentKeyPrefix + oshiId + "_" + GreetingSchedule.dayKey(for: date)
    }

    private func isOccasionSent(oshiId: String, date: Date) -> Bool {
        UserDefaults.standard.bool(forKey: occasionSentKey(oshiId: oshiId, date: date))
    }

    private func markOccasionSent(oshiId: String, date: Date) {
        UserDefaults.standard.set(true, forKey: occasionSentKey(oshiId: oshiId, date: date))
    }

    // MARK: - Prompts

    static func instruction(slot: GreetingSchedule.Slot?, occasion: GreetingSchedule.Occasion?, language: String) -> String {
        let ja = language == "ja"
        switch occasion {
        case .birthday:
            return ja
                ? "今日はあなた（キャラクター）の誕生日です。いつも応援してくれるファンに、誕生日を一緒に過ごせる嬉しさと感謝を、キャラクターらしく特別な気持ちを込めて伝えてください。2〜3文で。"
                : "Today is your (the character's) birthday. Tell your fan, in character and with special warmth, how happy you are to spend it together and thank them for always supporting you. 2-3 sentences."
        case .anniversary(let days):
            return ja
                ? "ファンがあなたを推し始めてから今日で\(days)日目の記念日です。これまで一緒に過ごしてくれた感謝と、これからもよろしくという気持ちを、キャラクターらしく特別に伝えてください。2〜3文で。"
                : "Today marks \(days) days since your fan started supporting you. In character, thank them for the time together and say you look forward to what's ahead. 2-3 sentences."
        case nil:
            break
        }

        switch slot {
        case .night:
            return ja
                ? "夜です。ファンに向けて、今日一日をねぎらう「おやすみ」のメッセージをキャラクターらしく送ってください。1〜2文で。"
                : "It's night. Send your fan a goodnight message in character that acknowledges their day. 1-2 sentences."
        default:
            return ja
                ? "朝です。ファンに向けて、今日一日を応援する「おはよう」のメッセージをキャラクターらしく送ってください。1〜2文で。"
                : "It's morning. Send your fan a good-morning message in character that cheers them on for the day. 1-2 sentences."
        }
    }

    // MARK: - Storage

    private func loadPending() -> [PendingGreeting] {
        guard let data = UserDefaults.standard.data(forKey: pendingKey) else { return [] }
        return (try? JSONDecoder().decode([PendingGreeting].self, from: data)) ?? []
    }

    private func savePending(_ pending: [PendingGreeting]) {
        let data = try? JSONEncoder().encode(pending)
        UserDefaults.standard.set(data, forKey: pendingKey)
    }
}

// MARK: - Foreground presentation

extension PremiumGreetingManager: UNUserNotificationCenterDelegate {
    /// アプリ使用中に届いた場合もバナーを出し、チャット履歴に反映する
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if notification.request.content.userInfo["type"] as? String == "oshi_greeting" {
            deliverDueGreetings(now: Date().addingTimeInterval(1))
        }
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        deliverDueGreetings(now: Date().addingTimeInterval(1))
        completionHandler()
    }
}
