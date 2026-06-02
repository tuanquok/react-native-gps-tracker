import Foundation
import SQLite3

struct QueuedHttpLocation {
  let id: Int64
  let body: [String: Any]
}

final class GpsTrackerSQLiteQueue {
  static let shared = GpsTrackerSQLiteQueue()

  private let queue = DispatchQueue(label: "GpsTrackerSQLiteQueue")
  private var database: OpaquePointer?

  private init() {
    openDatabase()
    createSchema()
  }

  deinit {
    if database != nil {
      sqlite3_close(database)
    }
  }

  func enqueue(actionIndex: Int, body: [String: Any]) -> Int {
    queue.sync {
      guard
        let database,
        JSONSerialization.isValidJSONObject(body),
        let bodyData = try? JSONSerialization.data(withJSONObject: body),
        let bodyString = String(data: bodyData, encoding: .utf8)
      else {
        return countLocked(actionIndex: actionIndex)
      }

      let sql = """
        INSERT INTO http_locations (action_index, body, created_at)
        VALUES (?, ?, ?)
        """
      var statement: OpaquePointer?
      guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
        return countLocked(actionIndex: actionIndex)
      }

      defer {
        sqlite3_finalize(statement)
      }

      sqlite3_bind_int(statement, 1, Int32(actionIndex))
      sqlite3_bind_text(statement, 2, bodyString, -1, SQLITE_TRANSIENT)
      sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)

      if sqlite3_step(statement) != SQLITE_DONE {
        print("GpsTracker SQLite enqueue failed")
      }

      return countLocked(actionIndex: actionIndex)
    }
  }

  func count(actionIndex: Int) -> Int {
    queue.sync {
      countLocked(actionIndex: actionIndex)
    }
  }

  func loadBatch(actionIndex: Int, limit: Int) -> [QueuedHttpLocation] {
    guard limit > 0 else {
      return []
    }

    return queue.sync {
      guard let database else {
        return []
      }

      let sql = """
        SELECT id, body
        FROM http_locations
        WHERE action_index = ?
        ORDER BY id ASC
        LIMIT ?
        """
      var statement: OpaquePointer?
      guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
        return []
      }

      defer {
        sqlite3_finalize(statement)
      }

      sqlite3_bind_int(statement, 1, Int32(actionIndex))
      sqlite3_bind_int(statement, 2, Int32(limit))

      var rows: [QueuedHttpLocation] = []
      while sqlite3_step(statement) == SQLITE_ROW {
        let id = sqlite3_column_int64(statement, 0)
        guard
          let bodyPointer = sqlite3_column_text(statement, 1)
        else {
          continue
        }

        let bodyString = String(cString: bodyPointer)
        guard
          let data = bodyString.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data),
          let body = object as? [String: Any]
        else {
          continue
        }

        rows.append(QueuedHttpLocation(id: id, body: body))
      }

      return rows
    }
  }

  func delete(ids: [Int64]) {
    guard !ids.isEmpty else {
      return
    }

    queue.sync {
      guard let database else {
        return
      }

      sqlite3_exec(database, "BEGIN TRANSACTION", nil, nil, nil)
      defer {
        sqlite3_exec(database, "COMMIT", nil, nil, nil)
      }

      let sql = "DELETE FROM http_locations WHERE id = ?"
      var statement: OpaquePointer?
      guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
        return
      }

      defer {
        sqlite3_finalize(statement)
      }

      for id in ids {
        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)
        sqlite3_bind_int64(statement, 1, id)
        if sqlite3_step(statement) != SQLITE_DONE {
          print("GpsTracker SQLite delete failed")
        }
      }
    }
  }

  private func openDatabase() {
    guard let url = databaseURL else {
      return
    }

    if sqlite3_open(url.path, &database) != SQLITE_OK {
      print("GpsTracker SQLite open failed")
      database = nil
    }
  }

  private func createSchema() {
    queue.sync {
      guard let database else {
        return
      }

      let sql = """
        CREATE TABLE IF NOT EXISTS http_locations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action_index INTEGER NOT NULL,
          body TEXT NOT NULL,
          created_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_http_locations_action_id
        ON http_locations(action_index, id);
        """

      if sqlite3_exec(database, sql, nil, nil, nil) != SQLITE_OK {
        print("GpsTracker SQLite schema creation failed")
      }
    }
  }

  private func countLocked(actionIndex: Int) -> Int {
    guard let database else {
      return 0
    }

    let sql = "SELECT COUNT(*) FROM http_locations WHERE action_index = ?"
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      return 0
    }

    defer {
      sqlite3_finalize(statement)
    }

    sqlite3_bind_int(statement, 1, Int32(actionIndex))
    guard sqlite3_step(statement) == SQLITE_ROW else {
      return 0
    }

    return Int(sqlite3_column_int(statement, 0))
  }

  private var databaseURL: URL? {
    guard
      let directory = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first
    else {
      return nil
    }

    do {
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
    } catch {
      print("GpsTracker SQLite directory creation failed: \(error)")
      return nil
    }

    return directory.appendingPathComponent("GpsTracker.sqlite")
  }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
