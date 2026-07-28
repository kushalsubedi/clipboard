import Foundation

struct Session: Identifiable, Hashable {
    let id: Int64
    var name: String
    var createdAt: Date
}

enum ClipKind: String {
    case text
    case rtf
    case image
}

struct Clip: Identifiable, Hashable {
    let id: Int64
    var sessionId: Int64
    var kind: ClipKind
    /// Plain-text representation. For rich text this is the extracted string
    /// (used for search and collapsed previews); for images it's a label like "Image 640×480".
    var content: String
    /// RTF bytes for `.rtf` clips, PNG bytes for `.image` clips, nil for plain text.
    var data: Data?
    var createdAt: Date
    var updatedAt: Date
    var pinned: Bool
}
