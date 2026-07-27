import Foundation

struct Credentials {
    let token: String
    let userGid: String
    let userName: String
    let workspaceGid: String
    let workspaceName: String
    let weeklyGoalHours: Double
    /// Calendar.firstWeekday convention: 1 = Sunday … 7 = Saturday. Default 2 = Monday.
    let firstWeekday: Int
    /// How many days per week the goal is spread over, for the pace calculation. Default 5.
    let workDaysPerWeek: Int
}

enum CredentialsManager {
    private static let suite = UserDefaults.standard
    private static let tokenAccount = "asanaPAT"

    static func save(_ c: Credentials) {
        KeychainHelper.save(c.token, account: tokenAccount)
        suite.set(c.userGid, forKey: "userGid")
        suite.set(c.userName, forKey: "userName")
        suite.set(c.workspaceGid, forKey: "workspaceGid")
        suite.set(c.workspaceName, forKey: "workspaceName")
        suite.set(c.weeklyGoalHours, forKey: "weeklyGoalHours")
        suite.set(c.firstWeekday, forKey: "firstWeekday")
        suite.set(c.workDaysPerWeek, forKey: "workDaysPerWeek")
    }

    static func load() -> Credentials? {
        guard
            let token = KeychainHelper.load(account: tokenAccount), !token.isEmpty,
            let userGid = suite.string(forKey: "userGid"), !userGid.isEmpty,
            let workspaceGid = suite.string(forKey: "workspaceGid"), !workspaceGid.isEmpty
        else { return nil }
        let goal = suite.double(forKey: "weeklyGoalHours")
        let firstWeekday = suite.integer(forKey: "firstWeekday")
        let workDaysPerWeek = suite.integer(forKey: "workDaysPerWeek")
        return Credentials(
            token: token,
            userGid: userGid,
            userName: suite.string(forKey: "userName") ?? "",
            workspaceGid: workspaceGid,
            workspaceName: suite.string(forKey: "workspaceName") ?? "",
            weeklyGoalHours: goal > 0 ? goal : 40,
            firstWeekday: (1...7).contains(firstWeekday) ? firstWeekday : 2,
            workDaysPerWeek: (1...7).contains(workDaysPerWeek) ? workDaysPerWeek : 5
        )
    }

    static func clear() {
        KeychainHelper.delete(account: tokenAccount)
        suite.removeObject(forKey: "userGid")
        suite.removeObject(forKey: "userName")
        suite.removeObject(forKey: "workspaceGid")
        suite.removeObject(forKey: "workspaceName")
        suite.removeObject(forKey: "weeklyGoalHours")
        suite.removeObject(forKey: "firstWeekday")
        suite.removeObject(forKey: "workDaysPerWeek")
    }
}
