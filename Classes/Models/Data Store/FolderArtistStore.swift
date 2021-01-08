//
//  FolderArtistStore.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjackSwift

extension FolderArtist: FetchableRecord, PersistableRecord {
    struct Table {
        static let folderArtistList = "folderArtistList"
        static let folderArtistTableSection = "folderArtistTableSection"
        static let folderArtistListMetadata = "folderArtistListMetadata"
    }
    enum Column: String, ColumnExpression {
        case id, name
    }
    enum RelatedColumn: String, ColumnExpression {
        case mediaFolderId, folderArtistId
    }
    
    static func createInitialSchema(_ db: Database) throws {
        // Shared table of unique artist records
        try db.create(table: FolderArtist.databaseTableName) { t in
            t.column(Column.id, .integer).notNull().primaryKey()
            t.column(Column.name, .text).notNull().indexed()
        }
        
        // Cache of folder artist IDs for each media folder for display
        try db.create(table: FolderArtist.Table.folderArtistList) { t in
            t.autoIncrementedPrimaryKey(GRDB.Column.rowID).notNull()
            t.column(RelatedColumn.mediaFolderId, .integer).notNull().indexed()
            t.column(RelatedColumn.folderArtistId, .integer).notNull()
        }
        
        // Cache of section indexes for display
        try db.create(table: FolderArtist.Table.folderArtistTableSection) { t in
            t.column(TableSection.Column.mediaFolderId, .integer).notNull().indexed()
            t.column(TableSection.Column.name, .text).notNull()
            t.column(TableSection.Column.position, .integer).notNull()
            t.column(TableSection.Column.itemCount, .integer).notNull()
        }
        
        // Cache of folder artist loading metadata for display
        try db.create(table: FolderArtist.Table.folderArtistListMetadata) { t in
            t.column(RootListMetadata.Column.mediaFolderId, .integer).notNull().primaryKey()
            t.column(RootListMetadata.Column.itemCount, .integer).notNull()
            t.column(RootListMetadata.Column.reloadDate, .datetime).notNull()
        }
    }
}

extension Store {
    func deleteFolderArtists(mediaFolderId: Int) -> Bool {
        do {
            return try serverDb.write { db in
                try db.execute(literal: "DELETE FROM folderArtistList WHERE mediaFolderId = \(mediaFolderId)")
                try db.execute(literal: "DELETE FROM folderArtistTableSection WHERE mediaFolderId = \(mediaFolderId)")
                try db.execute(literal: "DELETE FROM folderArtistListMetadata WHERE mediaFolderId = \(mediaFolderId)")
                return true
            }
        } catch {
            DDLogError("Failed to reset folder artist caches: \(error)")
            return false
        }
    }
    
    func folderArtistIds(mediaFolderId: Int) -> [Int] {
        do {
            return try serverDb.read { db in
                let sql: SQLLiteral = """
                    SELECT folderArtistId
                    FROM folderArtistList
                    WHERE mediaFolderId = \(mediaFolderId)
                    ORDER BY \(Column.rowID) ASC
                    """
                return try SQLRequest<Int>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select folder artist IDs for media folder \(mediaFolderId): \(error)")
            return []
        }
    }
    
    func folderArtist(id: Int) -> FolderArtist? {
        do {
            return try serverDb.read { db in
                try FolderArtist.fetchOne(db, key: id)
            }
        } catch {
            DDLogError("Failed to select folder artist \(id): \(error)")
            return nil
        }
    }
    
    func add(folderArtist: FolderArtist, mediaFolderId: Int) -> Bool {
        do {
            return try serverDb.write { db in
                // Insert or update shared artist record
                try folderArtist.save(db)
                
                // Insert artist id into list cache
                let sql: SQLLiteral = """
                    INSERT INTO folderArtistList
                    (mediaFolderId, folderArtistId)
                    VALUES (\(mediaFolderId), \(folderArtist.id))
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to insert folder artist \(folderArtist) in media folder \(mediaFolderId): \(error)")
            return false
        }
    }
    
    func folderArtistSections(mediaFolderId: Int) -> [TableSection] {
        do {
            return try serverDb.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM folderArtistTableSection
                    WHERE mediaFolderId = \(mediaFolderId)
                    """
                return try SQLRequest<TableSection>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select folder artist table sections for media folder \(mediaFolderId): \(error)")
            return [TableSection]()
        }
    }
    
    func add(folderArtistSection section: TableSection) -> Bool {
        do {
            return try serverDb.write { db in
                // Insert artist id into list cache
                let sql: SQLLiteral = """
                    INSERT INTO folderArtistTableSection
                    (mediaFolderId, name, position, itemCount)
                    VALUES (\(section.mediaFolderId), \(section.name), \(section.position), \(section.itemCount))
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to insert folder artist section \(section) in media folder \(section.mediaFolderId): \(error)")
            return false
        }
    }
    
    func folderArtistMetadata(mediaFolderId: Int) -> RootListMetadata? {
        do {
            return try serverDb.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM folderArtistListMetadata
                    WHERE mediaFolderId = \(mediaFolderId)
                    """
                return try SQLRequest<RootListMetadata>(literal: sql).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select folder artist metadata for media folder \(mediaFolderId): \(error)")
            return nil
        }
    }
    
    func add(folderArtistListMetadata metadata: RootListMetadata) -> Bool {
        do {
            return try serverDb.write { db in
                let sql: SQLLiteral = """
                    INSERT INTO folderArtistListMetadata
                    (mediaFolderId, itemCount, reloadDate)
                    VALUES (\(metadata.mediaFolderId), \(metadata.itemCount), \(metadata.reloadDate))
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to insert folder artist list metadata in media folder \(metadata.mediaFolderId): \(error)")
            return false
        }
    }
    
    // Returns a list of matching tag artist IDs
    func search(folderArtistName name: String, mediaFolderId: Int, offset: Int, limit: Int) -> [Int] {
        do {
            return try serverDb.read { db in
                let searchTerm = "%\(name)%"
                let sql: SQLLiteral = """
                    SELECT folderArtistId
                    FROM folderArtistList
                    JOIN \(FolderArtist.self)
                    ON folderArtistList.folderArtistId = \(FolderArtist.self).id
                    WHERE folderArtistList.mediaFolderId = \(mediaFolderId)
                    AND \(FolderArtist.self).name LIKE \(searchTerm)
                    LIMIT \(limit) OFFSET \(offset)
                    """
                return try SQLRequest<Int>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to search for folder artist \(name) in media folder \(mediaFolderId): \(error)")
            return []
        }
    }
}
