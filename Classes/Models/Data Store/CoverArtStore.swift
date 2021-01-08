//
//  CoverArtStore.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjackSwift

extension CoverArt: FetchableRecord, PersistableRecord {
    enum Column: String, ColumnExpression {
        case id, isLarge, data
    }
    
    static func createInitialSchema(_ db: Database) throws {
        try db.create(table: CoverArt.databaseTableName) { t in
            t.column(Column.id, .text).notNull()
            t.column(Column.isLarge, .boolean).notNull()
            t.column(Column.data, .blob).notNull()
            t.primaryKey([Column.id.rawValue, Column.isLarge.rawValue])
        }
    }
}

extension ArtistArt: FetchableRecord, PersistableRecord {
    enum Column: String, ColumnExpression {
        case id, isLarge, data
    }
    
    static func createInitialSchema(_ db: Database) throws {
        // Artist header art
        try db.create(table: ArtistArt.databaseTableName) { t in
            t.column(Column.id, .text).notNull().primaryKey()
            t.column(Column.data, .blob).notNull()
        }
    }
}

@objc extension Store {
    @objc func coverArt(id: String, isLarge: Bool) -> CoverArt? {
        do {
            return try mainDb.read { db in
                try CoverArt.fetchOne(db, key: [CoverArt.Column.id.rawValue: id, CoverArt.Column.isLarge.rawValue: isLarge])
            }
        } catch {
            DDLogError("Failed to select cover art \(id) isLarge \(isLarge): \(error)")
            return nil
        }
    }
    
    @objc func artistArt(id: String) -> ArtistArt? {
        do {
            return try mainDb.read { db in
                try ArtistArt.fetchOne(db, key: id)
            }
        } catch {
            DDLogError("Failed to select artist art \(id): \(error)")
            return nil
        }
    }
    
    @objc func isCoverArtCached(id: String, isLarge: Bool) -> Bool {
        do {
            return try mainDb.read { db in
                try CoverArt.filter(literal: "id = \(id) AND isLarge = \(isLarge)").fetchCount(db) > 0
            }
        } catch {
            DDLogError("Failed to select cover art count \(id) isLarge \(isLarge): \(error)")
            return false
        }
    }
    
    @objc func isArtistArtCached(id: String) -> Bool {
        do {
            return try mainDb.read { db in
                try ArtistArt.filter(key: id).fetchCount(db) > 0
            }
        } catch {
            DDLogError("Failed to select artist art count \(id): \(error)")
            return false
        }
    }
    
    @objc func add(coverArt: CoverArt) -> Bool {
        do {
            return try mainDb.write { db in
                try coverArt.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to insert cover art \(coverArt.id) isLarge \(coverArt.isLarge): \(error)")
            return false
        }
    }
    
    @objc func add(artistArt: CoverArt) -> Bool {
        do {
            return try mainDb.write { db in
                try artistArt.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to insert artist art \(artistArt.id): \(error)")
            return false
        }
    }
}
