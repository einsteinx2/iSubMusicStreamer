//
//  MediaFolderStore.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjackSwift

extension MediaFolder: FetchableRecord, PersistableRecord {
    enum Column: String, ColumnExpression {
        case serverId, id, name
    }
    
    static func createInitialSchema(_ db: Database) throws {
        try db.create(table: MediaFolder.databaseTableName) { t in
            t.column(Column.serverId, .integer).notNull()
            t.column(Column.id, .integer).notNull()
            t.column(Column.name, .text).notNull()
            t.primaryKey([Column.serverId, Column.id])
        }
    }
}

@objc extension Store {
    @objc func mediaFolders(serverId: Int) -> [MediaFolder] {
        do {
            return try mainDb.read { db in
                try MediaFolder.filter(literal: "serverId = \(serverId)").fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all media folders: \(error)")
            return []
        }
    }
    
    @objc func deleteMediaFolders() -> Bool {
        do {
            return try mainDb.write { db in
                try MediaFolder.deleteAll(db)
                return true
            }
        } catch {
            DDLogError("Failed to delete all media folders: \(error)")
            return false
        }
    }
    
    @objc func add(mediaFolders: [MediaFolder]) -> Bool {
        do {
            return try mainDb.write { db in
                for mediaFolder in mediaFolders {
                    try mediaFolder.save(db)
                }
                return true
            }
        } catch {
            DDLogError("Failed to insert media folders: \(error)")
            return false
        }
    }
}
