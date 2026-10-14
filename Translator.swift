import Foundation

enum Translator {
    static func translate(_ text: String) async throws -> String {
        let d = UserDefaults.standard
        let lang = d.string(forKey: "targetLang") ?? "zh-CN"
        let engine = d.string(forKey: "engine") ?? "google"
        if engine == "libre" {
            return try await libre(text, lang: lang, url: d.string(forKey: "libreURL") ?? "", key: d.string(forKey: "libreKey") ?? "")
        }
        return try await google(text, lang: lang)
    }

    static func google(_ text: String, lang: String) async throws -> String {
        var c = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
        c.queryItems = [
            .init(name: "client", value: "gtx"), .init(name: "sl", value: "auto"),
            .init(name: "tl", value: lang), .init(name: "dt", value: "t"),
            .init(name: "q", value: text)
        ]
        let (data, _) = try await URLSession.shared.data(from: c.url!)
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [Any],
              let segs = arr.first as? [Any] else { throw APIError.bad }
        return segs.compactMap { ($0 as? [Any])?.first as? String }.joined()
    }

    static func libre(_ text: String, lang: String, url: String, key: String) async throws -> String {
        guard let u = URL(string: url.trimmingCharacters(in: .whitespaces) + "/translate") else { throw APIError.bad }
        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: String] = ["q": text, "source": "auto", "target": lang.split(separator: "-").first.map(String.init) ?? lang, "format": "text"]
        if !key.isEmpty { body["api_key"] = key }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let t = obj["translatedText"] as? String else { throw APIError.bad }
        return t
    }
}
