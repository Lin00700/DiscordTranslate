import Foundation

struct Guild: Codable, Identifiable { let id: String; let name: String }
struct Channel: Codable, Identifiable {
    let id: String
    let name: String?
    let type: Int
    let position: Int?
}
struct Author: Codable { let username: String; let global_name: String? }
struct Message: Codable, Identifiable {
    let id: String
    let content: String
    let author: Author
    let timestamp: String
}
