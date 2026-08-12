import Foundation

enum StatsPeriod {
    case week, today
}

struct TaskMinutes {
    let name: String
    let minutes: Int
    let lastLoggedAt: Date?
}

struct PeriodSummary {
    let totalMinutes: Int
    let goalMinutes: Int
    let topTasks: [TaskMinutes]
    let generatedAt: Date
    let expectedMinutesSoFar: Int

    var totalHours: Double { Double(totalMinutes) / 60 }
    var isOnPace: Bool { totalMinutes >= expectedMinutesSoFar }
}

struct PeriodSummaries {
    let week: PeriodSummary
    let today: PeriodSummary

    func summary(for period: StatsPeriod) -> PeriodSummary {
        switch period {
        case .week: return week
        case .today: return today
        }
    }
}

class WeeklyTimeService {
    private let api: AsanaAPI
    private let userGid: String
    private let workspaceGid: String
    private let goalHours: Double
    private let firstWeekday: Int
    private let workDaysPerWeek: Int

    init(token: String, userGid: String, workspaceGid: String, goalHours: Double, firstWeekday: Int, workDaysPerWeek: Int) {
        self.api = AsanaAPI(token: token)
        self.userGid = userGid
        self.workspaceGid = workspaceGid
        self.goalHours = goalHours
        self.firstWeekday = firstWeekday
        self.workDaysPerWeek = workDaysPerWeek
    }

    func fetchSummaries() async throws -> PeriodSummaries {
        let weekStart = WeekCalculator.startOfWeek(firstWeekday: firstWeekday)
        let weekStartDateOnly = WeekCalculator.dateOnlyString(weekStart)
        let weekStartISO = WeekCalculator.isoDateTimeUTC(weekStart)
        let todayDateOnly = WeekCalculator.dateOnlyString(Date())

        let tasks = try await api.fetchCandidateTasks(workspace: workspaceGid, isoDateTime: weekStartISO)

        var weekPerTask: [(name: String, minutes: Int, lastLoggedAt: Date?)] = []
        var todayPerTask: [(name: String, minutes: Int, lastLoggedAt: Date?)] = []
        var weekTotalMinutes = 0
        var todayTotalMinutes = 0

        // Asana rejects large bursts of simultaneous requests ("too many requests at the same
        // time"), so time entries are fetched in small concurrent batches instead of all at once.
        let batchSize = 8
        for batchStart in stride(from: 0, to: tasks.count, by: batchSize) {
            let batch = tasks[batchStart..<min(batchStart + batchSize, tasks.count)]
            try await withThrowingTaskGroup(of: (String, Int, Date?, Int, Date?).self) { group in
                for task in batch {
                    group.addTask { [api, userGid] in
                        let entries = try await api.fetchTimeEntries(taskGid: task.gid)
                        let mine = entries.filter { $0.createdByGid == userGid }
                        let weekEntries = mine.filter { entry in
                            guard let d = entry.entered_on else { return false }
                            return d >= weekStartDateOnly
                        }
                        let todayEntries = weekEntries.filter { $0.entered_on == todayDateOnly }

                        let weekMinutes = weekEntries.reduce(0) { $0 + ($1.duration_minutes ?? 0) }
                        let todayMinutes = todayEntries.reduce(0) { $0 + ($1.duration_minutes ?? 0) }
                        let weekLastLoggedAt = weekEntries.compactMap { $0.createdAtDate }.max()
                        let todayLastLoggedAt = todayEntries.compactMap { $0.createdAtDate }.max()

                        return (task.name, weekMinutes, weekLastLoggedAt, todayMinutes, todayLastLoggedAt)
                    }
                }
                for try await (name, weekMinutes, weekLastLoggedAt, todayMinutes, todayLastLoggedAt) in group {
                    if weekMinutes > 0 {
                        weekPerTask.append((name, weekMinutes, weekLastLoggedAt))
                        weekTotalMinutes += weekMinutes
                    }
                    if todayMinutes > 0 {
                        todayPerTask.append((name, todayMinutes, todayLastLoggedAt))
                        todayTotalMinutes += todayMinutes
                    }
                }
            }
        }

        func topTasks(from perTask: [(name: String, minutes: Int, lastLoggedAt: Date?)]) -> [TaskMinutes] {
            perTask
                .sorted { ($0.lastLoggedAt ?? .distantPast) > ($1.lastLoggedAt ?? .distantPast) }
                .prefix(6)
                .map { TaskMinutes(name: $0.name, minutes: $0.minutes, lastLoggedAt: $0.lastLoggedAt) }
        }

        let weekGoalMinutes = Int(goalHours * 60)
        let elapsed = WeekCalculator.elapsedWorkdays(firstWeekday: firstWeekday, totalWorkdays: workDaysPerWeek, from: weekStart)
        let weekExpectedMinutesSoFar = Int(Double(weekGoalMinutes) * Double(elapsed) / Double(workDaysPerWeek))

        let dailyGoalMinutes = Int((goalHours * 60) / Double(workDaysPerWeek))

        let now = Date()
        let week = PeriodSummary(
            totalMinutes: weekTotalMinutes,
            goalMinutes: weekGoalMinutes,
            topTasks: topTasks(from: weekPerTask),
            generatedAt: now,
            expectedMinutesSoFar: weekExpectedMinutesSoFar
        )
        let today = PeriodSummary(
            totalMinutes: todayTotalMinutes,
            goalMinutes: dailyGoalMinutes,
            topTasks: topTasks(from: todayPerTask),
            generatedAt: now,
            expectedMinutesSoFar: dailyGoalMinutes
        )

        return PeriodSummaries(week: week, today: today)
    }
}
