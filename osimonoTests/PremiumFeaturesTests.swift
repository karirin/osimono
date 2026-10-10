//
//  PremiumFeaturesTests.swift
//  osimonoTests
//

import Testing
import Foundation
@testable import osimono

struct GreetingScheduleTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func monthDay(_ text: String) -> [Int]? {
        GreetingSchedule.parseMonthDay(text).map { [$0.month, $0.day] }
    }

    @Test func parsesFreeFormBirthdays() {
        #expect(monthDay("1月1日") == [1, 1])
        #expect(monthDay("2000年12月25日") == [12, 25])
        #expect(monthDay("2000/3/9") == [3, 9])
        #expect(monthDay("07-14") == [7, 14])
        #expect(monthDay("December 25") == [12, 25])
        #expect(monthDay("Mar 3, 1999") == [3, 3])
        #expect(GreetingSchedule.parseMonthDay("") == nil)
        #expect(GreetingSchedule.parseMonthDay("不明") == nil)
        #expect(GreetingSchedule.parseMonthDay("13月40日") == nil)
    }

    @Test func upcomingSlotsAreNextMorningAndNight() {
        let slots = GreetingSchedule.upcomingSlots(after: date(2026, 9, 25, 7, 0), calendar: calendar)
        #expect(slots.map(\.slot) == [.morning, .night])
        #expect(slots[0].date == date(2026, 9, 25, 8))
        #expect(slots[1].date == date(2026, 9, 25, 22))

        let afterMorning = GreetingSchedule.upcomingSlots(after: date(2026, 9, 25, 9, 0), calendar: calendar)
        #expect(afterMorning.map(\.slot) == [.night, .morning])
        #expect(afterMorning[1].date == date(2026, 9, 26, 8))
    }

    @Test func detectsBirthdayAndAnniversary() {
        #expect(GreetingSchedule.occasion(on: date(2026, 1, 1), birthday: "1月1日", createdAt: nil, calendar: calendar) == .birthday)
        #expect(GreetingSchedule.occasion(on: date(2026, 1, 2), birthday: "1月1日", createdAt: nil, calendar: calendar) == nil)

        let created = date(2026, 1, 1, 20).timeIntervalSince1970
        #expect(GreetingSchedule.occasion(on: date(2026, 4, 11), birthday: nil, createdAt: created, calendar: calendar) == .anniversary(days: 100))
        #expect(GreetingSchedule.occasion(on: date(2027, 1, 1), birthday: nil, createdAt: created, calendar: calendar) == .anniversary(days: 365))
        #expect(GreetingSchedule.occasion(on: date(2026, 4, 12), birthday: nil, createdAt: created, calendar: calendar) == nil)
    }

    @Test func occasionPromptsFollowLanguage() {
        #expect(PremiumGreetingManager.instruction(slot: .morning, occasion: .birthday, language: "ja").contains("誕生日"))
        #expect(PremiumGreetingManager.instruction(slot: .night, occasion: nil, language: "en").contains("goodnight"))
        #expect(PremiumGreetingManager.instruction(slot: nil, occasion: .anniversary(days: 100), language: "ja").contains("100日"))
    }
}

struct PremiumRoleplayGatingTests {

    @Test func characterDetailsAreIgnoredForFreePlan() {
        var oshi = Oshi(name: "凛")
        oshi.id = "rin"
        var state = RoleplayState()
        state.profile.description = "クールで少しツンデレな幼なじみ"

        let premium = RoleplayChatService.makeContext(oshi: oshi, state: state, language: "ja", query: "", isPremium: true)
        let free = RoleplayChatService.makeContext(oshi: oshi, state: state, language: "ja", query: "", isPremium: false)
        #expect(premium.character.description == "クールで少しツンデレな幼なじみ")
        #expect(free.character.description.isEmpty)
    }

    @Test func premiumRemembersMore() {
        #expect(PremiumFeatures.recentMessageLimit(isPremium: true) > PremiumFeatures.recentMessageLimit(isPremium: false))
        #expect(PremiumFeatures.promptMemoryLimit(isPremium: true) > PremiumFeatures.promptMemoryLimit(isPremium: false))
        #expect(PremiumFeatures.maxStoredMemories(isPremium: true) > PremiumFeatures.maxStoredMemories(isPremium: false))

        let history = (0..<60).map {
            ChatMessage(id: "\($0)", content: "m\($0)", isUser: $0 % 2 == 0, timestamp: TimeInterval($0), oshiId: "rin")
        }
        var oshi = Oshi(name: "凛")
        oshi.id = "rin"
        let context = RoleplayChatService.makeContext(oshi: oshi, state: RoleplayState(), language: "ja", query: "")
        let premium = RoleplayChatService.buildMessages(context: context, userMessage: "", chatHistory: history, isPremium: true)
        let free = RoleplayChatService.buildMessages(context: context, userMessage: "", chatHistory: history, isPremium: false)
        #expect(premium.count > free.count)
    }
}

@Suite(.serialized)
struct RoleplayTrialTests {
    private func reset() {
        UserDefaults.standard.removeObject(forKey: "roleplayTrialStarted")
        UserDefaults.standard.removeObject(forKey: "roleplayTrialUsedReplies")
    }

    @Test func trialAllowsOneSessionThenEnds() {
        reset()
        defer { reset() }
        #expect(RoleplayTrial.status == .available)
        #expect(!RoleplayTrial.canUseRoleplay(isPremium: false))

        RoleplayTrial.start()
        #expect(RoleplayTrial.status == .active(remaining: RoleplayTrial.replyLimit))
        #expect(RoleplayTrial.canUseRoleplay(isPremium: false))

        for _ in 0..<(RoleplayTrial.replyLimit - 1) {
            #expect(!RoleplayTrial.consumeReply())
        }
        #expect(RoleplayTrial.consumeReply())
        #expect(RoleplayTrial.status == .used)
        #expect(!RoleplayTrial.canUseRoleplay(isPremium: false))
        #expect(RoleplayTrial.canUseRoleplay(isPremium: true))

        // 2回目のお試しはできない
        RoleplayTrial.start()
        #expect(RoleplayTrial.status == .used)
    }

    @Test func situationIsIgnoredWhenRoleplayDisabled() {
        var oshi = Oshi(name: "凛")
        oshi.id = "rin"
        var state = RoleplayState()
        state.situation = RoleplaySituation(location: "学校の屋上", time: "放課後")
        state.profile.description = "幼なじみ"

        let trial = RoleplayChatService.makeContext(oshi: oshi, state: state, language: "ja", query: "", isPremium: false, roleplayEnabled: true)
        let expired = RoleplayChatService.makeContext(oshi: oshi, state: state, language: "ja", query: "", isPremium: false, roleplayEnabled: false)
        #expect(trial.situation.location == "学校の屋上")
        #expect(trial.character.description == "幼なじみ")
        #expect(expired.situation.isEmpty)
        #expect(expired.character.description.isEmpty)
    }
}
