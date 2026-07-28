import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Thin wrapper around the SQLite3 C API. Stores everything in a single
/// file under Application Support so history survives app restarts.
final class Database {
    private var db: OpaquePointer?

    init(path: String) {
        if sqlite3_open(path, &db) != SQLITE_OK {
            fatalError("Unable to open database at \(path)")
        }
        createSchema()
    }

    deinit {
        sqlite3_close(db)
    }

    private func createSchema() {
        exec("""
        CREATE TABLE IF NOT EXISTS sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at REAL NOT NULL
        );
        """)
        exec("""
        CREATE TABLE IF NOT EXISTS clips (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            content TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            pinned INTEGER NOT NULL DEFAULT 0
        );
        """)
    }

    private func exec(_ sql: String) {
        var errMsg: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(errMsg)
            print("SQLite error: \(msg)")
        }
    }

    // MARK: - Sessions

    func createSession(name: String) -> Int64 {
        let sql = "INSERT INTO sessions (name, created_at) VALUES (?, ?);"
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 2, Date().timeIntervalSince1970)
        sqlite3_step(stmt)
        return sqlite3_last_insert_rowid(db)
    }

    func fetchSessions() -> [Session] {
        let sql = "SELECT id, name, created_at FROM sessions ORDER BY created_at ASC;"
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        var results: [Session] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
            results.append(Session(id: id, name: name, createdAt: createdAt))
        }
        return results
    }

    func deleteSession(id: Int64) {
        exec("DELETE FROM clips WHERE session_id = \(id);")
        exec("DELETE FROM sessions WHERE id = \(id);")
    }

    // MARK: - Clips

    func insertClip(sessionId: Int64, content: String) -> Int64 {
        let sql = "INSERT INTO clips (session_id, content, created_at, updated_at, pinned) VALUES (?, ?, ?, ?, 0);"
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        let now = Date().timeIntervalSince1970
        sqlite3_bind_int64(stmt, 1, sessionId)
        sqlite3_bind_text(stmt, 2, content, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 3, now)
        sqlite3_bind_double(stmt, 4, now)
        sqlite3_step(stmt)
        return sqlite3_last_insert_rowid(db)
    }

    func fetchClips(sessionId: Int64) -> [Clip] {
        let sql = """
        SELECT id, session_id, content, created_at, updated_at, pinned
        FROM clips WHERE session_id = ?
        ORDER BY pinned DESC, created_at DESC;
        """
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, sessionId)
        var results: [Clip] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let sid = sqlite3_column_int64(stmt, 1)
            let content = String(cString: sqlite3_column_text(stmt, 2))
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
            let updatedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
            let pinned = sqlite3_column_int(stmt, 5) == 1
            results.append(Clip(id: id, sessionId: sid, content: content,
                                 createdAt: createdAt, updatedAt: updatedAt, pinned: pinned))
        }
        return results
    }

    func updateClipContent(id: Int64, content: String) {
        let sql = "UPDATE clips SET content = ?, updated_at = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, content, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 2, Date().timeIntervalSince1970)
        sqlite3_bind_int64(stmt, 3, id)
        sqlite3_step(stmt)
    }

    func togglePin(id: Int64, pinned: Bool) {
        exec("UPDATE clips SET pinned = \(pinned ? 1 : 0) WHERE id = \(id);")
    }

    func deleteClip(id: Int64) {
        exec("DELETE FROM clips WHERE id = \(id);")
    }

    func deleteUnpinnedClips(sessionId: Int64) {
        exec("DELETE FROM clips WHERE session_id = \(sessionId) AND pinned = 0;")
    }

    func latestContent(sessionId: Int64) -> String? {
        let sql = "SELECT content FROM clips WHERE session_id = ? ORDER BY created_at DESC LIMIT 1;"
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, sessionId)
        if sqlite3_step(stmt) == SQLITE_ROW {
            return String(cString: sqlite3_column_text(stmt, 0))
        }
        return nil
    }
}
