import AppKit
import Combine
import Foundation

final class ClipboardStore: ObservableObject {
    @Published var clips: [Clip] = []
    @Published var sessions: [Session] = []
    @Published var currentSessionId: Int64
    @Published var searchText: String = ""
    @Published var openOnHover: Bool {
        didSet { defaults.set(openOnHover, forKey: openOnHoverKey) }
    }

    private let db: Database
    private var pasteboardTimer: Timer?
    private var lastChangeCount: Int
    private let defaults = UserDefaults.standard
    private let currentSessionKey = "com.clipboardmini.currentSessionId"
    private let openOnHoverKey = "com.clipboardmini.openOnHover"

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
        self.openOnHover = defaults.bool(forKey: openOnHoverKey)

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
        guard let captured = capture(from: pb) else { return }
        if let latest = db.latestClip(sessionId: currentSessionId),
           latest.kind == captured.kind,
           latest.content == captured.content,
           latest.data == captured.data {
            return // consecutive duplicate
        }
        _ = db.insertClip(sessionId: currentSessionId, kind: captured.kind,
                          content: captured.content, data: captured.data)
        refreshClips()
    }

    /// Reads the richest supported representation off the pasteboard.
    /// Priority: image → rich text → plain text.
    private func capture(from pb: NSPasteboard) -> (kind: ClipKind, content: String, data: Data?)? {
        let types = pb.types ?? []

        // Images — but not file copies (Finder puts the file's icon on the pasteboard).
        if !types.contains(.fileURL), let png = pngData(from: pb) {
            let label: String
            if let rep = NSBitmapImageRep(data: png) {
                label = "Image \(rep.pixelsWide)×\(rep.pixelsHigh)"
            } else {
                label = "Image"
            }
            return (.image, label, png)
        }

        // Rich text — keep the RTF bytes, extract plain text for search/preview.
        // Browsers and many chat apps put HTML (not RTF) on the pasteboard,
        // so fall back to converting their HTML into RTF.
        if let rtf = pb.data(forType: .rtf) ?? rtfFromHTML(pb.data(forType: .html)),
           let plain = pb.string(forType: .string) ?? plainText(fromRTF: rtf) {
            let trimmed = plain.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return (.rtf, trimmed, rtf)
            }
        }

        // Plain text.
        if let raw = pb.string(forType: .string) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return (.text, trimmed, nil)
            }
        }
        return nil
    }

    private func pngData(from pb: NSPasteboard) -> Data? {
        if let png = pb.data(forType: .png) {
            return png
        }
        if let tiff = pb.data(forType: .tiff),
           let rep = NSBitmapImageRep(data: tiff) {
            return rep.representation(using: .png, properties: [:])
        }
        return nil
    }

    private func plainText(fromRTF data: Data) -> String? {
        NSAttributedString(rtf: data, documentAttributes: nil)?.string
    }

    /// Converts pasteboard HTML into RTF so styled copies from browsers
    /// survive as rich text. The WebKit-based HTML importer must run on the
    /// main thread; the pasteboard timer already fires there.
    private func rtfFromHTML(_ html: Data?) -> Data? {
        guard let html, !html.isEmpty, html.count < 1_000_000,
              let attributed = try? NSAttributedString(
                  data: html,
                  options: [.documentType: NSAttributedString.DocumentType.html,
                            .characterEncoding: String.Encoding.utf8.rawValue],
                  documentAttributes: nil),
              attributed.length > 0 else { return nil }
        return try? attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    func refreshClips() {
        clips = db.fetchClips(sessionId: currentSessionId)
    }

    func refreshSessions() {
        sessions = db.fetchSessions()
    }

    func copyToClipboard(_ clip: Clip) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch clip.kind {
        case .text:
            pb.setString(clip.content, forType: .string)
        case .rtf:
            if let data = clip.data {
                pb.setData(data, forType: .rtf)
            }
            pb.setString(clip.content, forType: .string) // fallback for plain-text targets
        case .image:
            if let data = clip.data, let image = NSImage(data: data) {
                pb.writeObjects([image])
            }
        }
        lastChangeCount = pb.changeCount // don't re-capture our own copy as a "new" clip
    }

    /// Puts a generated image (e.g. a QR code) on the pasteboard without
    /// recording it as a new clip.
    func copyGeneratedImage(_ png: Data) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(png, forType: .png)
        if let image = NSImage(data: png),
           let tiff = image.tiffRepresentation {
            pb.setData(tiff, forType: .tiff)
        }
        lastChangeCount = pb.changeCount
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
