import Foundation

struct Session: Identifiable, Hashable {
    let id: Int64
    var name: String
    var createdAt: Date
}

struct Clip: Identifiable, Hashable {
    let id: Int64
    var sessionId: Int64
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var pinned: Bool
}
