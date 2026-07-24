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
    }

    static func load() -> Credentials? {
        guard
            let token = KeychainHelper.load(account: tokenAccount), !token.isEmpty,
            let userGid = suite.string(forKey: "userGid"), !userGid.isEmpty,
            let workspaceGid = suite.string(forKey: "workspaceGid"), !workspaceGid.isEmpty
        else { return nil }
        let goal = suite.double(forKey: "weeklyGoalHours")
        let firstWeekday = suite.integer(forKey: "firstWeekday")
        return Credentials(
            token: token,
            userGid: userGid,
            userName: suite.string(forKey: "userName") ?? "",
            workspaceGid: workspaceGid,
            workspaceName: suite.string(forKey: "workspaceName") ?? "",
            weeklyGoalHours: goal > 0 ? goal : 40,
            firstWeekday: (1...7).contains(firstWeekday) ? firstWeekday : 2
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
    }
}
