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
        case id, name
    }
    
    static func createInitialSchema(_ db: Database) throws {
        try db.create(table: MediaFolder.databaseTableName) { t in
            t.column(Column.id, .integer).notNull().primaryKey()
            t.column(Column.name, .text).notNull()
        }
    }
}

@objc extension Store {
    @objc func mediaFolders() -> [MediaFolder] {
        do {
            return try serverDb.read { db in
                try MediaFolder.all().fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all media folders: \(error)")
            return [MediaFolder]()
        }
    }
    
    @objc func deleteMediaFolders() -> Bool {
        do {
            return try serverDb.write { db in
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
            return try serverDb.write { db in
                for mediaFolder in mediaFolders {
                    try mediaFolder.insert(db)
                }
                return true
            }
        } catch {
            DDLogError("Failed to insert media folders: \(error)")
            return false
        }
    }
}
