import Foundation

enum APIError: LocalizedError {
    case noToken, http(Int, String), bad
    var errorDescription: String? {
        switch self {
        case .noToken: return "请先在设置里填写 Bot Token"
        case .http(let c, let m): return "HTTP \(c)：\(m)"
        case .bad: return "返回数据异常"
        }
    }
}

enum DiscordAPI {
    static let base = "https://discord.com/api/v10"

    static func get<T: Decodable>(_ path: String) async throws -> T {
        guard let token = UserDefaults.standard.string(forKey: "token"), !token.isEmpty else { throw APIError.noToken }
        var req = URLRequest(url: URL(string: base + path)!)
        req.setValue("Bot \(token.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.bad }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func guilds() async throws -> [Guild] { try await get("/users/@me/guilds") }
    static func channels(_ guild: String) async throws -> [Channel] {
        let all: [Channel] = try await get("/guilds/\(guild)/channels")
        return all.filter { $0.type == 0 || $0.type == 5 }.sorted { ($0.position ?? 0) < ($1.position ?? 0) }
    }
    static func messages(_ channel: String) async throws -> [Message] {
        let m: [Message] = try await get("/channels/\(channel)/messages?limit=50")
        return m.reversed()
    }
}
