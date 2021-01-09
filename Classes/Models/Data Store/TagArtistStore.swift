//
//  TagArtistStore.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjackSwift

extension TagArtist: FetchableRecord, PersistableRecord {
    struct Table {
        static let tagArtistList = "tagArtistList"
        static let tagArtistTableSection = "tagArtistTableSection"
        static let tagArtistListMetadata = "tagArtistListMetadata"
    }
    enum Column: String, ColumnExpression {
        case serverId, id, name, coverArtId, artistImageUrl, albumCount
    }
    enum RelatedColumn: String, ColumnExpression {
        case mediaFolderId, tagArtistId
    }
    
    static func createInitialSchema(_ db: Database) throws {
        // Shared table of unique artist records
        try db.create(table: TagArtist.databaseTableName) { t in
            t.column(Column.serverId, .integer).notNull()
            t.column(Column.id, .integer).notNull()
            t.column(Column.name, .text).notNull().indexed()
            t.column(Column.coverArtId, .text)
            t.column(Column.artistImageUrl, .text)
            t.column(Column.albumCount, .integer).notNull()
            t.primaryKey([Column.serverId, Column.id])
        }
        
        // Cache of tag artist IDs for each media folder for display
        try db.create(table: TagArtist.Table.tagArtistList) { t in
            t.autoIncrementedPrimaryKey(GRDB.Column.rowID).notNull()
            t.column(Column.serverId).notNull()
            t.column(RelatedColumn.mediaFolderId, .integer).notNull()
            t.column(RelatedColumn.tagArtistId, .integer).notNull()
        }
        try db.create(indexOn: TagArtist.Table.tagArtistList, columns: [Column.serverId, RelatedColumn.mediaFolderId])
        
        // Cache of section indexes for display
        try db.create(table: TagArtist.Table.tagArtistTableSection) { t in
            t.column(TableSection.Column.serverId).notNull()
            t.column(TableSection.Column.mediaFolderId, .integer).notNull()
            t.column(TableSection.Column.name, .text).notNull()
            t.column(TableSection.Column.position, .integer).notNull()
            t.column(TableSection.Column.itemCount, .integer).notNull()
        }
        try db.create(indexOn: TagArtist.Table.tagArtistTableSection, columns: [TableSection.Column.serverId, TableSection.Column.mediaFolderId])
        
        // Cache of tag artist loading metadata for display
        try db.create(table: TagArtist.Table.tagArtistListMetadata) { t in
            t.column(RootListMetadata.Column.serverId, .integer).notNull()
            t.column(RootListMetadata.Column.mediaFolderId, .integer).notNull()
            t.column(RootListMetadata.Column.itemCount, .integer).notNull()
            t.column(RootListMetadata.Column.reloadDate, .datetime).notNull()
            t.primaryKey([RootListMetadata.Column.serverId, RootListMetadata.Column.mediaFolderId])
        }
    }
}

extension Store {
    func deleteTagArtists(serverId: Int, mediaFolderId: Int) -> Bool {
        do {
            return try pool.write { db in
                try db.execute(literal: "DELETE FROM tagArtistList WHERE serverId = \(serverId) AND mediaFolderId = \(mediaFolderId)")
                try db.execute(literal: "DELETE FROM tagArtistTableSection WHERE serverId = \(serverId) AND mediaFolderId = \(mediaFolderId)")
                try db.execute(literal: "DELETE FROM tagArtistListMetadata WHERE serverId = \(serverId) AND mediaFolderId = \(mediaFolderId)")
                return true
            }
        } catch {
            DDLogError("Failed to reset tag artist caches server \(serverId) and media folder \(mediaFolderId): \(error)")
            return false
        }
    }
    
    func tagArtistIds(serverId: Int, mediaFolderId: Int) -> [Int] {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT tagArtistId
                    FROM tagArtistList
                    WHERE serverId = \(serverId) AND mediaFolderId = \(mediaFolderId)
                    ORDER BY \(Column.rowID) ASC
                    """
                return try SQLRequest<Int>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select tag artist IDs for server \(serverId) and media folder \(mediaFolderId): \(error)")
            return []
        }
    }
    
    func tagArtist(serverId: Int, id: Int) -> TagArtist? {
        do {
            return try pool.read { db in
                try TagArtist.filter(literal: "serverId = \(serverId) AND id = \(id)").fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select server \(serverId) and tag artist \(id): \(error)")
            return nil
        }
    }
    
    func add(tagArtist: TagArtist, mediaFolderId: Int) -> Bool {
        do {
            return try pool.write { db in
                // Insert or update shared artist record
                try tagArtist.save(db)
                
                // Insert artist id into list cache
                let sql: SQLLiteral = """
                    INSERT INTO tagArtistList
                    (serverId, mediaFolderId, tagArtistId)
                    VALUES (\(tagArtist.serverId), \(mediaFolderId), \(tagArtist.id))
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to insert tag artist \(tagArtist) in media folder \(mediaFolderId): \(error)")
            return false
        }
    }
    
    func tagArtistSections(serverId: Int, mediaFolderId: Int) -> [TableSection] {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM tagArtistTableSection
                    WHERE serverId = \(serverId) AND mediaFolderId = \(mediaFolderId)
                    """
                return try SQLRequest<TableSection>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select tag artist table sections for server \(serverId) and media folder \(mediaFolderId): \(error)")
            return [TableSection]()
        }
    }
    
    func add(tagArtistSection section: TableSection) -> Bool {
        do {
            return try pool.write { db in
                // Insert artist id into list cache
                let sql: SQLLiteral = """
                    INSERT INTO tagArtistTableSection
                    (serverId, mediaFolderId, name, position, itemCount)
                    VALUES (\(section.serverId), \(section.mediaFolderId), \(section.name), \(section.position), \(section.itemCount))
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to insert tag artist section \(section): \(error)")
            return false
        }
    }
    
    func tagArtistMetadata(serverId: Int, mediaFolderId: Int) -> RootListMetadata? {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM tagArtistListMetadata
                    WHERE serverId = \(serverId) AND mediaFolderId = \(mediaFolderId)
                    """
                return try SQLRequest<RootListMetadata>(literal: sql).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select tag artist metadata for server \(serverId) and media folder \(mediaFolderId): \(error)")
            return nil
        }
    }
    
    func add(tagArtistListMetadata metadata: RootListMetadata) -> Bool {
        do {
            return try pool.write { db in
                let sql: SQLLiteral = """
                    INSERT INTO tagArtistListMetadata
                    (serverId, mediaFolderId, itemCount, reloadDate)
                    VALUES (\(metadata.serverId), \(metadata.mediaFolderId), \(metadata.itemCount), \(metadata.reloadDate))
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to insert tag artist list metadata \(metadata) in media folder \(metadata.mediaFolderId): \(error)")
            return false
        }
    }
    
    // Returns a list of matching tag artist IDs
    func search(tagArtistName name: String, serverId: Int, mediaFolderId: Int, offset: Int, limit: Int) -> [Int] {
        do {
            return try pool.read { db in
                let searchTerm = "%\(name)%"
                let sql: SQLLiteral = """
                    SELECT tagArtistId
                    FROM tagArtistList
                    JOIN \(TagArtist.self)
                    ON tagArtistList.tagArtistId = \(TagArtist.self).id
                    WHERE tagArtistList.serverId = \(serverId) AND tagArtistList.mediaFolderId = \(mediaFolderId)
                    AND \(TagArtist.self).name LIKE \(searchTerm)
                    LIMIT \(limit) OFFSET \(offset)
                    """
                return try SQLRequest<Int>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to search for tag artist \(name) in server \(serverId) and media folder \(mediaFolderId): \(error)")
            return []
        }
    }
}
