//
//  FolderAlbumStore.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjackSwift

extension FolderAlbum: FetchableRecord, PersistableRecord {
    struct Table {
        static let folderAlbumList = "folderAlbumList"
        static let folderSongList = "folderSongList"
    }
    enum Column: String, ColumnExpression {
        case serverId, id, name, coverArtId, parentFolderId, tagArtistName, tagAlbumName, playCount, year, genre, userRating, averageRating, createdDate, starredDate
    }
    enum RelatedColumn: String, ColumnExpression {
        case parentFolderId, folderId, songId
    }
    
    static func createInitialSchema(_ db: Database) throws {
        // Shared table of unique album records
        try db.create(table: FolderAlbum.databaseTableName) { t in
            t.column(Column.serverId, .integer).notNull()
            t.column(Column.id, .text).notNull()
            t.column(Column.name, .text).notNull()
            t.column(Column.coverArtId, .text)
            t.column(Column.parentFolderId, .text)
            t.column(Column.tagArtistName, .text)
            t.column(Column.tagAlbumName, .text)
            t.column(Column.playCount, .integer).notNull()
            t.column(Column.year, .integer)
            t.column(Column.genre, .text)
            t.column(Column.userRating, .integer)
            t.column(Column.averageRating, .double)
            t.column(Column.createdDate, .datetime).notNull()
            t.column(Column.starredDate, .datetime)
            t.primaryKey([Column.serverId, Column.id])
        }
        
        // Cache of folder album IDs for each folder for display
        try db.create(table: FolderAlbum.Table.folderAlbumList) { t in
            t.autoIncrementedPrimaryKey(GRDB.Column.rowID).notNull()
            t.column(Column.serverId, .integer).notNull()
            t.column(RelatedColumn.parentFolderId, .text).notNull()
            t.column(RelatedColumn.folderId, .text).notNull()
        }
        try db.create(indexOn: FolderAlbum.Table.folderAlbumList, columns: [Column.serverId, RelatedColumn.parentFolderId])
        
        // Cache of song IDs for each folder for display
        try db.create(table: FolderAlbum.Table.folderSongList) { t in
            t.autoIncrementedPrimaryKey(GRDB.Column.rowID).notNull()
            t.column(Column.serverId, .integer).notNull()
            t.column(RelatedColumn.parentFolderId, .text).notNull()
            t.column(RelatedColumn.songId, .text).notNull()
        }
        try db.create(indexOn: FolderAlbum.Table.folderSongList, columns: [Column.serverId, RelatedColumn.parentFolderId])
    }
}

extension FolderMetadata: FetchableRecord, PersistableRecord {
    enum Column: String, ColumnExpression {
        case serverId, parentFolderId, folderCount, songCount, duration
    }
    
    static func createInitialSchema(_ db: Database) throws {
        // Cache of metadata for each folder for display
        try db.create(table: FolderMetadata.databaseTableName) { t in
            t.column(FolderMetadata.Column.serverId, .integer).notNull()
            t.column(FolderMetadata.Column.parentFolderId, .integer).notNull()
            t.column(FolderMetadata.Column.folderCount, .integer).notNull()
            t.column(FolderMetadata.Column.songCount, .integer).notNull()
            t.column(FolderMetadata.Column.duration, .integer).notNull()
            t.primaryKey([FolderMetadata.Column.serverId, FolderMetadata.Column.parentFolderId])
        }
    }
}

extension Store {
    @discardableResult
    func resetFolderAlbumCache(serverId: Int) -> Bool {
        do {
            return try pool.write { db in
                try db.execute(literal: "DELETE FROM folderAlbumList WHERE serverId = \(serverId)")
                try db.execute(literal: "DELETE FROM folderSongList WHERE serverId = \(serverId)")
                return true
            }
        } catch {
            DDLogError("Failed to reset folder album cache for server \(serverId): \(error)")
            return false
        }
    }
    
    @discardableResult
    func resetFolderAlbumCache(serverId: Int, parentFolderId: String) -> Bool {
        do {
            return try pool.write { db in
                try db.execute(literal: "DELETE FROM folderAlbumList WHERE serverId = \(serverId) AND parentFolderId = \(parentFolderId)")
                try db.execute(literal: "DELETE FROM folderSongList WHERE serverId = \(serverId) AND parentFolderId = \(parentFolderId)")
                return true
            }
        } catch {
            DDLogError("Failed to reset folder album \(parentFolderId) in server \(serverId) cache: \(error)")
            return false
        }
    }
    
    func folderAlbumIds(serverId: Int, parentFolderId: String) -> [String] {
        do {
            return try pool.read { db in
                let sql: SQL = """
                    SELECT folderId
                    FROM folderAlbumList
                    WHERE serverId = \(serverId) AND parentFolderId = \(parentFolderId)
                    ORDER BY \(Column.rowID) ASC
                    """
                return try SQLRequest<String>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select folder album IDs for server \(serverId) and parent folder \(parentFolderId): \(error)")
            return []
        }
    }
    
    func folderAlbum(serverId: Int, id: String) -> FolderAlbum? {
        do {
            return try pool.read { db in
                try FolderAlbum.filter(literal: "serverId = \(serverId) AND id = \(id)").fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select server \(serverId) and folder album \(id): \(error)")
            return nil
        }
    }
    
    func add(folderAlbum: FolderAlbum) -> Bool {
        do {
            return try pool.write { db in
                // Insert or update shared album record
                try folderAlbum.save(db)
                
                // Insert folder id into list cache
                let sql: SQL = """
                    INSERT INTO folderAlbumList
                    (serverId, parentFolderId, folderId)
                    VALUES (\(folderAlbum.serverId), \(folderAlbum.parentFolderId), \(folderAlbum.id))
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to insert folder album \(folderAlbum): \(error)")
            return false
        }
    }
    
    func songIds(serverId: Int, parentFolderId: String) -> [String] {
        do {
            return try pool.read { db in
                let sql: SQL = """
                    SELECT songId
                    FROM folderSongList
                    WHERE serverId = \(serverId) AND parentFolderId = \(parentFolderId)
                    ORDER BY \(Column.rowID) ASC
                    """
                return try SQLRequest<String>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select song IDs for server \(serverId) and parent folder \(parentFolderId): \(error)")
            return []
        }
    }
    
    func add(folderSong song: Song) -> Bool {
        guard let parentFolderId = song.parentFolderId else {
            DDLogError("Failed to insert folder song \(song) in folder because it's missing a parent folder id")
            return false
        }
        
        do {
            return try pool.write { db in
                // Insert or update shared song record
                try song.save(db)
                
                // Insert song id into list cache
                let sql: SQL = """
                    INSERT INTO folderSongList
                    (serverId, parentFolderId, songId)
                    VALUES (\(song.serverId), \(parentFolderId), \(song.id))
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to insert folder song \(song) in folder \(parentFolderId): \(error)")
            return false
        }
    }
    
    func isFolderMetadataCached(serverId: Int, parentFolderId: String) -> Bool {
        do {
            return try pool.read { db in
                try FolderMetadata.filter(literal: "serverId = \(serverId) AND parentFolderId = \(parentFolderId)").fetchCount(db) > 0
            }
        } catch {
            DDLogError("Failed to check if folder metadata is cached for server \(serverId) and parent folder \(parentFolderId): \(error)")
            return false
        }
    }
    
    func folderMetadata(serverId: Int, parentFolderId: String) -> FolderMetadata? {
        do {
            return try pool.read { db in
                try FolderMetadata.filter(literal: "serverId = \(serverId) AND parentFolderId = \(parentFolderId)").fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select folder metadata for server \(serverId) and parent folder \(parentFolderId): \(error)")
            return nil
        }
    }
    
    func add(folderMetadata: FolderMetadata) -> Bool {
        do {
            return try pool.write { db in
                // Insert or update folder metadata record
                try folderMetadata.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to insert folder folderMetadata \(folderMetadata): \(error)")
            return false
        }
    }
}

