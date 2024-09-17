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
        case serverId, id, name, userRating, averageRating, starredDate
    }
    enum RelatedColumn: String, ColumnExpression {
        case mediaFolderId, folderArtistId
    }
    
    static func createInitialSchema(_ db: Database) throws {
        // Shared table of unique artist records
        try db.create(table: FolderArtist.databaseTableName) { t in
            t.column(Column.serverId, .integer).notNull()
            t.column(Column.id, .text).notNull()
            t.column(Column.name, .text).notNull().indexed()
            t.column(Column.userRating, .integer)
            t.column(Column.averageRating, .double)
            t.column(Column.starredDate, .datetime)
            t.primaryKey([Column.serverId, Column.id])
        }
        
        // Cache of folder artist IDs for each media folder for display
        try db.create(table: FolderArtist.Table.folderArtistList) { t in
            t.autoIncrementedPrimaryKey(GRDB.Column.rowID).notNull()
            t.column(Column.serverId, .integer).notNull()
            t.column(RelatedColumn.mediaFolderId, .integer).notNull()
            t.column(RelatedColumn.folderArtistId, .text).notNull()
        }
        try db.create(indexOn: FolderArtist.Table.folderArtistList, columns: [Column.serverId, RelatedColumn.mediaFolderId])
        
        // Cache of section indexes for display
        try db.create(table: FolderArtist.Table.folderArtistTableSection) { t in
            t.column(TableSection.Column.serverId, .integer).notNull()
            t.column(TableSection.Column.mediaFolderId, .integer).notNull()
            t.column(TableSection.Column.name, .text).notNull()
            t.column(TableSection.Column.position, .integer).notNull()
            t.column(TableSection.Column.itemCount, .integer).notNull()
        }
        try db.create(indexOn: FolderArtist.Table.folderArtistTableSection, columns: [TableSection.Column.serverId, TableSection.Column.mediaFolderId])
        
        // Cache of folder artist loading metadata for display
        try db.create(table: FolderArtist.Table.folderArtistListMetadata) { t in
            t.column(RootListMetadata.Column.serverId, .integer).notNull()
            t.column(RootListMetadata.Column.mediaFolderId, .integer).notNull()
            t.column(RootListMetadata.Column.itemCount, .integer).notNull()
            t.column(RootListMetadata.Column.reloadDate, .datetime).notNull()
            t.primaryKey([RootListMetadata.Column.serverId, RootListMetadata.Column.mediaFolderId])
        }
    }
}

extension Store {
    @discardableResult
    func deleteFolderArtists(serverId: Int, mediaFolderId: Int) -> Bool {
        do {
            return try pool.write { db in
                try db.execute(literal: "DELETE FROM folderArtistList WHERE serverId = \(serverId) AND mediaFolderId = \(mediaFolderId)")
                try db.execute(literal: "DELETE FROM folderArtistTableSection WHERE serverId = \(serverId) AND mediaFolderId = \(mediaFolderId)")
                try db.execute(literal: "DELETE FROM folderArtistListMetadata WHERE serverId = \(serverId) AND mediaFolderId = \(mediaFolderId)")
                return true
            }
        } catch {
            DDLogError("Failed to reset folder artist caches server \(serverId) and media folder \(mediaFolderId): \(error)")
            return false
        }
    }
    
    func folderArtistIds(serverId: Int, mediaFolderId: Int) -> [String] {
        do {
            return try pool.read { db in
                let sql: SQL = """
                    SELECT folderArtistId
                    FROM folderArtistList
                    WHERE serverId = \(serverId) AND mediaFolderId = \(mediaFolderId)
                    ORDER BY \(Column.rowID) ASC
                    """
                return try SQLRequest<String>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select folder artist IDs for server \(serverId) and media folder \(mediaFolderId): \(error)")
            return []
        }
    }
    
    func folderArtist(serverId: Int, id: String) -> FolderArtist? {
        do {
            return try pool.read { db in
                try FolderArtist.filter(literal: "serverId = \(serverId) AND id = \(id)").fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select folder artist \(id) server \(serverId): \(error)")
            return nil
        }
    }
    
    func add(folderArtist: FolderArtist, mediaFolderId: Int) -> Bool {
        do {
            return try pool.write { db in
                // Insert or update shared artist record
                try folderArtist.save(db)
                
                // Insert artist id into list cache
                let sql: SQL = """
                    INSERT INTO folderArtistList
                    (serverId, mediaFolderId, folderArtistId)
                    VALUES (\(folderArtist.serverId), \(mediaFolderId), \(folderArtist.id))
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to insert folder artist \(folderArtist) in media folder \(mediaFolderId): \(error)")
            return false
        }
    }
    
    func folderArtistSections(serverId: Int, mediaFolderId: Int) -> [TableSection] {
        do {
            return try pool.read { db in
                let sql: SQL = """
                    SELECT *
                    FROM folderArtistTableSection
                    WHERE serverId = \(serverId) AND mediaFolderId = \(mediaFolderId)
                    """
                return try SQLRequest<TableSection>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select folder artist table sections for server \(serverId) and media folder \(mediaFolderId): \(error)")
            return [TableSection]()
        }
    }
    
    func add(folderArtistSection section: TableSection) -> Bool {
        do {
            return try pool.write { db in
                // Insert artist id into list cache
                let sql: SQL = """
                    INSERT INTO folderArtistTableSection
                    (serverId, mediaFolderId, name, position, itemCount)
                    VALUES (\(section.serverId), \(section.mediaFolderId), \(section.name), \(section.position), \(section.itemCount))
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to insert folder artist section \(section) in media folder \(section.mediaFolderId): \(error)")
            return false
        }
    }
    
    func folderArtistMetadata(serverId: Int, mediaFolderId: Int) -> RootListMetadata? {
        do {
            return try pool.read { db in
                let sql: SQL = """
                    SELECT *
                    FROM folderArtistListMetadata
                    WHERE serverId = \(serverId) AND mediaFolderId = \(mediaFolderId)
                    """
                return try SQLRequest<RootListMetadata>(literal: sql).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select folder artist metadata for server \(serverId) and media folder \(mediaFolderId): \(error)")
            return nil
        }
    }
    
    func add(folderArtistListMetadata metadata: RootListMetadata) -> Bool {
        do {
            return try pool.write { db in
                let sql: SQL = """
                    INSERT INTO folderArtistListMetadata
                    (serverId, mediaFolderId, itemCount, reloadDate)
                    VALUES (\(metadata.serverId), \(metadata.mediaFolderId), \(metadata.itemCount), \(metadata.reloadDate))
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to insert folder artist list metadata \(metadata) in media folder \(metadata.mediaFolderId): \(error)")
            return false
        }
    }
    
    // Returns a list of matching tag artist IDs
    func search(folderArtistName name: String, serverId: Int, mediaFolderId: Int, offset: Int, limit: Int) -> [String] {
        do {
            return try pool.read { db in
                let searchTerm = "%\(name)%"
                let sql: SQL = """
                    SELECT folderArtistId
                    FROM folderArtistList
                    JOIN \(FolderArtist.self)
                    ON folderArtistList.folderArtistId = \(FolderArtist.self).id
                    WHERE folderArtistList.serverId = \(serverId) AND folderArtistList.mediaFolderId = \(mediaFolderId)
                    AND \(FolderArtist.self).name LIKE \(searchTerm)
                    LIMIT \(limit) OFFSET \(offset)
                    """
                return try SQLRequest<String>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to search for folder artist \(name) in media folder \(mediaFolderId): \(error)")
            return []
        }
    }
}
