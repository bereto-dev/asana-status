import Foundation

struct TaskMinutes {
    let name: String
    let minutes: Int
    let lastLoggedAt: Date?
}

struct WeeklySummary {
    let totalMinutes: Int
    let goalMinutes: Int
    let topTasks: [TaskMinutes]
    let generatedAt: Date
    let expectedMinutesSoFar: Int

    var totalHours: Double { Double(totalMinutes) / 60 }
    var isOnPace: Bool { totalMinutes >= expectedMinutesSoFar }
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

    func fetchWeeklySummary() async throws -> WeeklySummary {
        let weekStart = WeekCalculator.startOfWeek(firstWeekday: firstWeekday)
        let weekStartDateOnly = WeekCalculator.dateOnlyString(weekStart)
        let weekStartISO = WeekCalculator.isoDateTimeUTC(weekStart)

        let tasks = try await api.fetchCandidateTasks(workspace: workspaceGid, isoDateTime: weekStartISO)

        var perTaskMinutes: [(name: String, minutes: Int, lastLoggedAt: Date?)] = []
        var totalMinutes = 0

        // Asana rejects large bursts of simultaneous requests ("too many requests at the same
        // time"), so time entries are fetched in small concurrent batches instead of all at once.
        let batchSize = 8
        for batchStart in stride(from: 0, to: tasks.count, by: batchSize) {
            let batch = tasks[batchStart..<min(batchStart + batchSize, tasks.count)]
            try await withThrowingTaskGroup(of: (String, Int, Date?).self) { group in
                for task in batch {
                    group.addTask { [api, userGid] in
                        let entries = try await api.fetchTimeEntries(taskGid: task.gid)
                        let mine = entries
                            .filter { $0.createdByGid == userGid }
                            .filter { entry in
                                guard let d = entry.entered_on else { return false }
                                return d >= weekStartDateOnly
                            }
                        let minutes = mine.reduce(0) { $0 + ($1.duration_minutes ?? 0) }
                        let lastLoggedAt = mine.compactMap { $0.createdAtDate }.max()
                        return (task.name, minutes, lastLoggedAt)
                    }
                }
                for try await (name, minutes, lastLoggedAt) in group where minutes > 0 {
                    perTaskMinutes.append((name, minutes, lastLoggedAt))
                    totalMinutes += minutes
                }
            }
        }

        let topTasks = perTaskMinutes
            .sorted { ($0.lastLoggedAt ?? .distantPast) > ($1.lastLoggedAt ?? .distantPast) }
            .prefix(6)
            .map { TaskMinutes(name: $0.name, minutes: $0.minutes, lastLoggedAt: $0.lastLoggedAt) }

        let goalMinutes = Int(goalHours * 60)
        let elapsed = WeekCalculator.elapsedWorkdays(firstWeekday: firstWeekday, totalWorkdays: workDaysPerWeek, from: weekStart)
        let expectedMinutesSoFar = Int(Double(goalMinutes) * Double(elapsed) / Double(workDaysPerWeek))

        return WeeklySummary(
            totalMinutes: totalMinutes,
            goalMinutes: goalMinutes,
            topTasks: topTasks,
            generatedAt: Date(),
            expectedMinutesSoFar: expectedMinutesSoFar
        )
    }
}
