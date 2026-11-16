#if DEBUG
import Buddies
import Foundation

/// Screenshot data for `-buddiesSample`: two clubs with members, times, ranking and photos.
@MainActor
enum BuddiesSamples {
    static func make() -> FakeBuddiesService {
        let service = FakeBuddiesService(name: "Joren")
        let day = DayKey.string(.now)
        let monday = WeekWindow.start(of: .now)
        let cal = Calendar.current

        func at(_ h: Int, _ m: Int) -> Date { cal.date(bySettingHour: h, minute: m, second: 0, of: .now) ?? .now }
        func report(_ h: Int, _ m: Int, rings: Int, xp: Int, streak: Int, rank: String) -> WakeReport {
            WakeReport(day: day, completedAt: at(h, m), alarmTime: String(format: "%02d:%02d", h, max(0, m - 5)),
                       rings: rings, xp: xp, streak: streak, rank: rank)
        }

        let crew = service.addClubSync(ClubDraft(name: "Early birds", description: "Up before 7, every weekday.", emoji: "🐦"))
        let gym = service.addClubSync(ClubDraft(name: "Gym rats", emoji: "🏋️"))
        let anna = service.addMember("Anna", to: crew)
        let bram = service.addMember("Bram", to: crew)
        let cas = service.addMember("Cas", to: crew)
        _ = service.addMember("Dana", to: crew)
        _ = service.addMember("Eli", to: gym)

        // Earlier this week (for the weekly board).
        for (offset, user) in [(1, anna), (1, bram), (2, anna), (2, cas)] {
            if let date = cal.date(byAdding: .day, value: offset - 1, to: monday), date < cal.startOfDay(for: .now) {
                service.simulateMorning(of: user, day: DayKey.string(date),
                                        report: WakeReport(day: DayKey.string(date), completedAt: date, alarmTime: nil,
                                                           rings: 1, xp: 85, streak: offset, rank: "Blob"),
                                        photo: false, clubs: [])
            }
        }
        service.simulateMorning(of: anna, day: day, report: report(6, 2, rings: 1, xp: 95, streak: 12, rank: "Gloopling"),
                                photo: true, clubs: [crew])
        service.simulateMorning(of: bram, day: day, report: report(6, 41, rings: 3, xp: 60, streak: 4, rank: "Blob"),
                                photo: true, clubs: [crew, gym])
        service.simulateMorning(of: cas, day: day, report: report(7, 15, rings: 2, xp: 55, streak: 2, rank: "Droplet"),
                                photo: false, clubs: [])
        service.addPublicClub("5 AM Club", emoji: "🌅", members: 48)
        service.addPublicClub("Students who actually go to class", emoji: "🎓", members: 17)
        return service
    }
}
#endif
