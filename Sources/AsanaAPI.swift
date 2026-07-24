import Foundation

struct AsanaWorkspaceRef: Decodable {
    let gid: String
    let name: String
}

struct AsanaMe: Decodable {
    let gid: String
    let name: String
    let workspaces: [AsanaWorkspaceRef]
}

struct AsanaTaskRef: Decodable {
    let gid: String
    let name: String
}

private struct AsanaTimeEntryUser: Decodable {
    let gid: String
}

struct AsanaTimeEntry: Decodable {
    let duration_minutes: Int?
    let entered_on: String?
    let created_at: String?
    fileprivate let created_by: AsanaTimeEntryUser?

    var createdByGid: String? { created_by?.gid }

    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    var createdAtDate: Date? {
        guard let created_at else { return nil }
        return Self.formatter.date(from: created_at)
    }
}

enum AsanaAPIError: Error, LocalizedError {
    case invalidToken
    case http(Int, String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidToken: return "Token inválido o expirado."
        case .http(let code, let msg): return "Error de Asana (\(code)): \(msg)"
        case .decoding: return "Respuesta inesperada de Asana."
        }
    }
}

class AsanaAPI {
    private let token: String
    private let base = "https://app.asana.com/api/1.0"

    init(token: String) { self.token = token }

    private func get(_ path: String, query: [String: String] = [:]) async throws -> Data {
        var comps = URLComponents(string: base + path)!
        if !query.isEmpty {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var req = URLRequest(url: comps.url!, timeoutInterval: 20)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AsanaAPIError.decoding }
        if http.statusCode == 401 { throw AsanaAPIError.invalidToken }
        if !(200...299).contains(http.statusCode) {
            let msg = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])
                .flatMap { ($0["errors"] as? [[String: Any]])?.first?["message"] as? String } ?? "Unknown error"
            throw AsanaAPIError.http(http.statusCode, msg)
        }
        return data
    }

    func fetchMe() async throws -> AsanaMe {
        struct Wrapper: Decodable { let data: AsanaMe }
        let data = try await get("/users/me", query: ["opt_fields": "gid,name,workspaces.gid,workspaces.name"])
        return try JSONDecoder().decode(Wrapper.self, from: data).data
    }

    /// Candidate tasks that may have received a time-tracking entry from me this week: the
    /// union of tasks I'm assigned to and tasks I follow (Asana auto-follows you on tasks you
    /// log time on even when someone else — or nobody — is the assignee), modified since the
    /// given ISO datetime. Requires Advanced Search (Premium/Business/Enterprise workspace).
    func fetchCandidateTasks(workspace: String, isoDateTime: String) async throws -> [AsanaTaskRef] {
        async let assigned = searchTasks(workspace: workspace, filterKey: "assignee.any", filterValue: "me", modifiedAtAfter: isoDateTime)
        async let followed = searchTasks(workspace: workspace, filterKey: "followers.any", filterValue: "me", modifiedAtAfter: isoDateTime)
        let (a, f) = try await (assigned, followed)

        var seen = Set<String>()
        var results: [AsanaTaskRef] = []
        for t in a + f where !seen.contains(t.gid) {
            seen.insert(t.gid)
            results.append(t)
        }
        return results
    }

    private func searchTasks(workspace: String, filterKey: String, filterValue: String, modifiedAtAfter: String) async throws -> [AsanaTaskRef] {
        struct Wrapper: Decodable { let data: [AsanaTaskRef]; let next_page: NextPage? }
        struct NextPage: Decodable { let offset: String }
        var results: [AsanaTaskRef] = []
        var offset: String? = nil
        repeat {
            var q = [
                filterKey: filterValue,
                "modified_at.after": modifiedAtAfter,
                "opt_fields": "gid,name",
                "limit": "100",
            ]
            if let o = offset { q["offset"] = o }
            let data = try await get("/workspaces/\(workspace)/tasks/search", query: q)
            let wrapper = try JSONDecoder().decode(Wrapper.self, from: data)
            results.append(contentsOf: wrapper.data)
            offset = wrapper.next_page?.offset
        } while offset != nil
        return results
    }

    func fetchTimeEntries(taskGid: String) async throws -> [AsanaTimeEntry] {
        struct Wrapper: Decodable { let data: [AsanaTimeEntry] }
        let data = try await get(
            "/tasks/\(taskGid)/time_tracking_entries",
            query: ["opt_fields": "duration_minutes,entered_on,created_by.gid,created_at"]
        )
        return try JSONDecoder().decode(Wrapper.self, from: data).data
    }
}
