import AppKit
import Combine
import Foundation

final class ClipboardStore: ObservableObject {
    @Published var clips: [Clip] = []
    @Published var sessions: [Session] = []
    @Published var currentSessionId: Int64
    @Published var searchText: String = ""

    private let db: Database
    private var pasteboardTimer: Timer?
    private var lastChangeCount: Int
    private let defaults = UserDefaults.standard
    private let currentSessionKey = "com.clipboardmini.currentSessionId"

    var filteredClips: [Clip] {
        guard !searchText.isEmpty else { return clips }
        return clips.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    var currentSession: Session? {
        sessions.first { $0.id == currentSessionId }
    }

    init() {
        let supportDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipboardMini", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        let dbPath = supportDir.appendingPathComponent("clipboard.sqlite3").path

        let db = Database(path: dbPath)
        self.db = db
        self.lastChangeCount = NSPasteboard.general.changeCount

        var loadedSessions = db.fetchSessions()
        if loadedSessions.isEmpty {
            let id = db.createSession(name: "Default")
            loadedSessions = db.fetchSessions()
            self.currentSessionId = id
        } else {
            let savedId = Int64(defaults.integer(forKey: currentSessionKey))
            self.currentSessionId = loadedSessions.contains { $0.id == savedId } ? savedId : loadedSessions[0].id
        }
        self.sessions = loadedSessions

        refreshClips()
        startMonitoring()
    }

    private func startMonitoring() {
        pasteboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }

    private func checkPasteboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount
        guard let raw = pb.string(forType: .string) else { return }
        let str = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !str.isEmpty, str != db.latestContent(sessionId: currentSessionId) else { return }
        _ = db.insertClip(sessionId: currentSessionId, content: str)
        refreshClips()
    }

    func refreshClips() {
        clips = db.fetchClips(sessionId: currentSessionId)
    }

    func refreshSessions() {
        sessions = db.fetchSessions()
    }

    func copyToClipboard(_ content: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(content, forType: .string)
        lastChangeCount = pb.changeCount // don't re-capture our own copy as a "new" clip
    }

    func updateClip(_ clip: Clip, newContent: String) {
        db.updateClipContent(id: clip.id, content: newContent)
        refreshClips()
    }

    func togglePin(_ clip: Clip) {
        db.togglePin(id: clip.id, pinned: !clip.pinned)
        refreshClips()
    }

    func deleteClip(_ clip: Clip) {
        db.deleteClip(id: clip.id)
        refreshClips()
    }

    func clearUnpinned() {
        db.deleteUnpinnedClips(sessionId: currentSessionId)
        refreshClips()
    }

    func createSession(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Session \(sessions.count + 1)" : trimmed
        let id = db.createSession(name: finalName)
        refreshSessions()
        switchSession(to: id)
    }

    func switchSession(to id: Int64) {
        currentSessionId = id
        defaults.set(Int(id), forKey: currentSessionKey)
        refreshClips()
    }

    func deleteSession(_ session: Session) {
        guard sessions.count > 1 else { return } // always keep at least one session
        db.deleteSession(id: session.id)
        refreshSessions()
        if currentSessionId == session.id {
            switchSession(to: sessions.first?.id ?? 0)
        }
    }
}
