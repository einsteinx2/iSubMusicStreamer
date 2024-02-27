//
//  ServerStore.swift
//  iSub
//
//  Created by Benjamin Baron on 1/8/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjackSwift

extension Server: FetchableRecord, PersistableRecord {
    enum Column: String, ColumnExpression {
        case id, type, url, username, password, path, isVideoSupported, isNewSearchSupported, isTagSearchSupported
    }
    
    static func createInitialSchema(_ db: Database) throws {
        try db.create(table: Server.databaseTableName) { t in
            t.autoIncrementedPrimaryKey(Column.id).notNull()
            t.column(Column.type, .text).notNull()
            t.column(Column.url, .text).notNull()
            t.column(Column.username, .text).notNull()
            t.column(Column.password, .text).notNull()
            t.column(Column.path, .text).notNull()
            t.column(Column.isVideoSupported, .boolean).notNull()
            t.column(Column.isNewSearchSupported, .boolean).notNull()
            t.column(Column.isTagSearchSupported, .boolean).notNull()
        }
    }
}

extension Store {
    func nextServerId() -> Int {
        do {
            return try pool.read { db in
                let maxId = try SQLRequest<Int>(literal: "SELECT MAX(id) FROM \(Server.self)").fetchOne(db) ?? 0
                return maxId + 1
            }
        } catch {
            DDLogError("Failed to select next server ID: \(error)")
            return -1
        }
    }
    
    func servers() -> [Server] {
        do {
            return try pool.read { db in
                try Server.fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all servers: \(error)")
            return []
        }
    }

    func server(id: Int) -> Server? {
        do {
            return try pool.read { db in
                try Server.fetchOne(db, key: id)
            }
        } catch {
            DDLogError("Failed to select servers \(id): \(error)")
            return nil
        }
    }
    
    func add(server: Server) -> Bool {
        do {
            return try pool.write { db in
                try server.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to insert server \(server): \(error)")
            return false
        }
    }
    
    @discardableResult
    func deleteServer(id: Int) -> Bool {
        do {
            return try pool.write { db in
                let sql: SQLLiteral = """
                DELETE FROM \(Server.self)
                WHERE id = \(id)
                """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to delete server \(id): \(error)")
            return false
        }
    }
}
