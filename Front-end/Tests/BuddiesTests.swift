import Buddies
import Coach
import Core
import Foundation
import Testing

private let brussels: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Brussels")!
    return c
}()

private func at(_ d: Int, _ h: Int = 0, _ m: Int = 0, month: Int = 11) -> Date {
    brussels.date(from: DateComponents(year: 2026, month: month, day: d, hour: h, minute: m))!
}

@Suite struct WeekWindowTests {
    // 2026-11-16 is a Monday.
    @Test func mondayStartsTheWeek() {
        #expect(WeekWindow.start(of: at(18, 9), calendar: brussels) == at(16))
        #expect(WeekWindow.start(of: at(16, 0), calendar: brussels) == at(16))
    }

    @Test func sundayNightBelongsToTheOldWeek() {
        #expect(WeekWindow.start(of: at(22, 23, 59), calendar: brussels) == at(16))
        #expect(WeekWindow.start(of: at(23, 0, 1), calendar: brussels) == at(23))
    }

    @Test func acrossDaylightSaving() {
        // Summer time ends Sunday 25 Oct 2026; the week started Monday 19 Oct.
        #expect(WeekWindow.start(of: at(25, 12, month: 10), calendar: brussels) == at(19, month: 10))
        #expect(WeekWindow.start(of: at(26, 7, month: 10), calendar: brussels) == at(26, month: 10))
    }

    @Test func dayKeyIsLocal() {
        #expect(DayKey.string(at(15, 0, 30), calendar: brussels) == "2026-11-15", "00:30 local is still the 15th")
    }
}

@Suite struct LeaderboardRankingTests {
    let a = LeaderboardRow(displayName: "Anna", weekXP: 200, totalXP: 900, streak: 3)
    let b = LeaderboardRow(displayName: "Bram", weekXP: 200, totalXP: 400, streak: 3)
    let c = LeaderboardRow(displayName: "Cas", weekXP: 150, totalXP: 1200, streak: 9)
    let d = LeaderboardRow(displayName: nil, weekXP: 0, totalXP: 0)

    @Test func tiesShareAPosition() {
        let ranked = LeaderboardRanking.rank([d, c, b, a], by: .week)
        #expect(ranked.map(\.row.displayName) == ["Anna", "Bram", "Cas", nil])
        #expect(ranked.map(\.position) == [1, 1, 3, 4])
        #expect(ranked.map(\.points) == [200, 200, 150, 0])
    }

    @Test func allTimeUsesTotals() {
        let ranked = LeaderboardRanking.rank([a, b, c, d], by: .allTime)
        #expect(ranked.map(\.row.displayName) == ["Cas", "Anna", "Bram", nil])
        #expect(ranked.first?.position == 1)
    }

    @Test func streakBreaksEqualPointsForOrderOnly() {
        let x = LeaderboardRow(displayName: "X", weekXP: 50, totalXP: 50, streak: 1)
        let y = LeaderboardRow(displayName: "Y", weekXP: 50, totalXP: 50, streak: 5)
        let ranked = LeaderboardRanking.rank([x, y], by: .week)
        #expect(ranked.map(\.row.displayName) == ["Y", "X"])
        #expect(ranked.map(\.position) == [1, 1])
    }
}

@Suite struct InviteCodeTests {
    @Test func generatedCodesAreValid() {
        for _ in 0..<50 {
            let code = InviteCode.generate()
            #expect(InviteCode.normalize(code) == code)
            #expect(!code.contains("O") && !code.contains("0") && !code.contains("I") && !code.contains("1"))
        }
    }

    @Test func acceptsWhatPeoplePaste() {
        #expect(InviteCode.normalize(" abcd-2345 ") == "ABCD2345")
        #expect(InviteCode.normalize("ABCD 2345") == "ABCD2345")
        #expect(InviteCode.normalize("earnit://join/ABCD2345") == "ABCD2345")
        #expect(InviteCode.normalize("https://earnit.app/join/abcd-2345") == "ABCD2345")
    }

    @Test func rejectsNonsense() {
        #expect(InviteCode.normalize("ABC") == nil)
        #expect(InviteCode.normalize("ABCD0OI1") == nil, "look-alikes aren't in the alphabet")
        #expect(InviteCode.normalize("earnit://mission") == nil)
        #expect(InviteCode.normalize("") == nil)
    }

    @Test func displayAndShare() {
        #expect(InviteCode.display("ABCD2345") == "ABCD-2345")
        #expect(InviteCode.link("ABCD2345").absoluteString == "earnit://join/ABCD2345")
        #expect(InviteCode.shareText(club: "Gym", code: "ABCD2345").contains("ABCD-2345"))
    }
}

@Suite struct ClubRulesTests {
    @Test func nameLength() {
        #expect(ClubRules.validate(ClubDraft(name: "A")) == .nameLength)
        #expect(ClubRules.validate(ClubDraft(name: "  Gym  ")) == nil)
        #expect(ClubRules.validate(ClubDraft(name: String(repeating: "x", count: 41))) == .nameLength)
        #expect(ClubRules.validate(ClubDraft(name: "Gym", description: String(repeating: "x", count: 201))) == .descriptionLength)
    }

    @Test func publicNamesAreFiltered() {
        #expect(ClubRules.validate(ClubDraft(name: "F*ck mornings", isPublic: true)) == nil, "masked is fine")
        #expect(ClubRules.validate(ClubDraft(name: "Fuck mornings", isPublic: true)) == .inappropriate)
        #expect(ClubRules.validate(ClubDraft(name: "5h1t club", isPublic: true)) == nil, "digit swaps only for known letters")
        #expect(ClubRules.validate(ClubDraft(name: "sh1t club", isPublic: true)) == .inappropriate)
        #expect(ClubRules.validate(ClubDraft(name: "Fuck mornings", isPublic: false)) == nil, "private clubs are the members' business")
        #expect(ClubRules.validate(ClubDraft(name: "Scunthorpe risers", isPublic: true)) == nil, "only word starts count")
    }

    @Test func createLimits() {
        #expect(ClubRules.canCreate(ownedCount: 0, isPro: false))
        #expect(!ClubRules.canCreate(ownedCount: 1, isPro: false))
        #expect(ClubRules.canCreate(ownedCount: 9, isPro: true))
        #expect(!ClubRules.canCreate(ownedCount: 10, isPro: true))
    }
}

@Suite struct FeedGateTests {
    @Test func unlockRule() {
        #expect(!FeedGate.isUnlocked(myPhotoState: .none))
        #expect(FeedGate.isUnlocked(myPhotoState: .posted))
        #expect(FeedGate.isUnlocked(myPhotoState: .skipped))
    }

    @Test func promptOnlyWhenItMatters() {
        #expect(FeedGate.shouldPrompt(missionDoneToday: true, clubCount: 1, myPhotoState: .none))
        #expect(!FeedGate.shouldPrompt(missionDoneToday: false, clubCount: 1, myPhotoState: .none))
        #expect(!FeedGate.shouldPrompt(missionDoneToday: true, clubCount: 0, myPhotoState: .none))
        #expect(!FeedGate.shouldPrompt(missionDoneToday: true, clubCount: 2, myPhotoState: .skipped))
    }
}

@Suite struct WakeReportTests {
    @Test func xpMatchesXPRules() {
        let history = [
            DaySummary(day: at(13), completed: true, reArms: 0, failSafe: false),
            DaySummary(day: at(14), completed: true, reArms: 2, failSafe: false),
        ]
        let report = WakeReport.make(day: at(14), completedAt: at(14, 7, 6), rings: 3, alarmTime: "07:00",
                                     history: history, calendar: brussels)
        // Day 2: 50 − 2×5 = 40, no first-try bonus, + 5 × streak 2 = 50.
        #expect(report.xp == XPRules.xp(for: history[1], streak: 2))
        #expect(report.xp == 50)
        #expect(report.streak == 2)
        #expect(report.day == "2026-11-14")
        #expect(report.rank == XPRules.progress(history, calendar: brussels).rank.title)
    }

    @Test func firstMorningEver() {
        let history = [DaySummary(day: at(14), completed: true, reArms: 0, failSafe: false)]
        let report = WakeReport.make(day: at(14), completedAt: at(14, 6, 30), rings: 1, alarmTime: nil,
                                     history: history, calendar: brussels)
        #expect(report.xp == 80, "50 + 25 first ring + 5 streak")
        #expect(report.streak == 1)
        #expect(report.rank == "Recruit")
    }
}

@Suite @MainActor struct WakeReportQueueTests {
    private func report(_ day: String, xp: Int = 50) -> WakeReport {
        WakeReport(day: day, completedAt: .now, alarmTime: nil, rings: 1, xp: xp, streak: 1, rank: "Recruit")
    }

    @Test func keepsOnePerDayAndFlushesOnce() async {
        let queue = WakeReportQueue(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        queue.enqueue(report("2026-11-14", xp: 10))
        queue.enqueue(report("2026-11-14", xp: 60))
        queue.enqueue(report("2026-11-15"))
        #expect(queue.pending.count == 2)
        #expect(queue.pending.first { $0.day == "2026-11-14" }?.xp == 60, "newest wins")

        var sent: [String] = []
        await queue.flush { sent.append($0.day) }
        #expect(sent.sorted() == ["2026-11-14", "2026-11-15"])
        #expect(queue.pending.isEmpty)
        await queue.flush { sent.append($0.day) }
        #expect(sent.count == 2, "nothing sent twice")
    }

    @Test func failuresStayQueued() async {
        let queue = WakeReportQueue(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        queue.enqueue(report("2026-11-14"))
        queue.enqueue(report("2026-11-15"))
        await queue.flush { if $0.day == "2026-11-15" { throw BuddiesError.message("offline") } }
        #expect(queue.pending.map(\.day) == ["2026-11-15"])
    }
}

@Suite @MainActor struct FakeBuddiesServiceTests {
    let day = "2026-11-15"

    @Test func createJoinAndLeave() async throws {
        let owner = FakeBuddiesService(name: "Owner")
        let id = try await owner.createClub(ClubDraft(name: "Early birds", emoji: "🐦"))
        let clubs = try await owner.myClubs(day: day)
        #expect(clubs.count == 1 && clubs[0].isOwner && clubs[0].memberCount == 1)

        let friend = owner.addMember("Friend", to: id)
        #expect(try await owner.myClubs(day: day)[0].memberCount == 2)

        try await owner.leaveClub(id)
        #expect(try await owner.myClubs(day: day).isEmpty)
        #expect(owner.clubs[id]?.members[friend] == .owner, "ownership passes on")
    }

    @Test func privateClubsNeedTheCode() async throws {
        let service = FakeBuddiesService()
        let id = try await service.createClub(ClubDraft(name: "Family"))
        let code = try #require(service.clubs[id]?.club.inviteCode)
        await #expect(throws: BuddiesError.self) { try await service.joinPublicClub(id) }
        #expect(try await service.joinClub(code: InviteCode.display(code).lowercased()) == id)
    }

    @Test func discoverFindsPublicClubs() async throws {
        let service = FakeBuddiesService()
        service.addPublicClub("5 AM Club", emoji: "🌅", members: 12)
        service.addPublicClub("Gym rats", emoji: "🏋️", members: 3)
        let all = try await service.searchPublicClubs("")
        #expect(all.map(\.name) == ["5 AM Club", "Gym rats"])
        let found = try await service.searchPublicClubs("gym")
        #expect(found.count == 1)
        try await service.joinPublicClub(found[0].id)
        #expect(try await service.searchPublicClubs("gym")[0].isMember)
    }

    @Test func feedUnlocksAfterPostingOrSkipping() async throws {
        let service = FakeBuddiesService()
        let club = try await service.createClub(ClubDraft(name: "Crew"))
        let anna = service.addMember("Anna", to: club)
        let report = WakeReport(day: day, completedAt: .now, alarmTime: "07:00", rings: 1, xp: 80, streak: 1, rank: "Recruit")
        service.simulateMorning(of: anna, day: day, report: report, photo: true, clubs: [club])

        let locked = try await service.feed(club: club, day: day)
        #expect(locked.count == 1 && locked[0].locked && locked[0].imagePath == nil)

        try await service.skipMorning(day: day)
        let open = try await service.feed(club: club, day: day)
        #expect(!open[0].locked && open[0].imagePath != nil)

        try await service.react(to: open[0].id, emoji: "🔥")
        #expect(try await service.feed(club: club, day: day)[0].reactions == ["🔥": 1])
    }

    @Test func blockingHidesSomeone() async throws {
        let service = FakeBuddiesService()
        let club = try await service.createClub(ClubDraft(name: "Crew"))
        let troll = service.addMember("Troll", to: club)
        try await service.block(troll)
        #expect(try await service.today(club: club, day: day).map(\.userID) == [service.me])
        #expect(try await service.leaderboard(club: club, weekStart: "2026-11-09").count == 1)
        try await service.unblock(troll)
        #expect(try await service.today(club: club, day: day).count == 2)
    }

    @Test func weeklyLeaderboardCountsOnlyThisWeek() async throws {
        let service = FakeBuddiesService()
        let club = try await service.createClub(ClubDraft(name: "Crew"))
        try await service.send(WakeReport(day: "2026-11-08", completedAt: .now, alarmTime: nil, rings: 1, xp: 70, streak: 1, rank: "Recruit"))
        try await service.send(WakeReport(day: "2026-11-09", completedAt: .now, alarmTime: nil, rings: 1, xp: 80, streak: 2, rank: "Recruit"))
        try await service.send(WakeReport(day: "2026-11-15", completedAt: .now, alarmTime: nil, rings: 1, xp: 90, streak: 3, rank: "Private"))
        let rows = try await service.leaderboard(club: club, weekStart: "2026-11-09")
        #expect(rows[0].weekXP == 170)
        #expect(rows[0].totalXP == 240)
        #expect(rows[0].streak == 3 && rows[0].coachRank == .privateSoldier)
    }

    @Test func signedOutFails() async {
        let service = FakeBuddiesService()
        service.signedIn = false
        await #expect(throws: BuddiesError.signedOut) { try await service.myClubs(day: day) }
    }
}
