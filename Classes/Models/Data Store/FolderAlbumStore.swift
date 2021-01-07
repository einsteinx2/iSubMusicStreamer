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
        case id, name, coverArtId, parentFolderId, tagArtistName, tagAlbumName, playCount, year
    }
    enum RelatedColumn: String, ColumnExpression {
        case parentFolderId, folderId, songId
    }
    
    static func createInitialSchema(_ db: Database) throws {
        // Shared table of unique album records
        try db.create(table: FolderAlbum.databaseTableName) { t in
            t.column(FolderAlbum.Column.id, .integer).notNull().primaryKey()
            t.column(FolderAlbum.Column.name, .text).notNull()
            t.column(FolderAlbum.Column.coverArtId, .text)
            t.column(FolderAlbum.Column.parentFolderId, .integer)
            t.column(FolderAlbum.Column.tagArtistName, .text)
            t.column(FolderAlbum.Column.tagAlbumName, .text)
            t.column(FolderAlbum.Column.playCount, .integer)
            t.column(FolderAlbum.Column.year, .integer)
        }
        
        // Cache of folder album IDs for each folder for display
        try db.create(table: FolderAlbum.Table.folderAlbumList) { t in
            t.autoIncrementedPrimaryKey(GRDB.Column.rowID).notNull()
            t.column(FolderAlbum.RelatedColumn.parentFolderId, .integer).notNull().indexed()
            t.column(FolderAlbum.RelatedColumn.folderId, .integer).notNull()
        }
        
        // Cache of song IDs for each folder for display
        try db.create(table: FolderAlbum.Table.folderSongList) { t in
            t.autoIncrementedPrimaryKey(GRDB.Column.rowID).notNull()
            t.column(FolderAlbum.RelatedColumn.parentFolderId, .integer).notNull().indexed()
            t.column(FolderAlbum.RelatedColumn.songId, .integer).notNull()
        }
    }
}

extension FolderMetadata: FetchableRecord, PersistableRecord {
    enum Column: String, ColumnExpression {
        case parentFolderId, folderCount, songCount, duration
    }
    
    static func createInitialSchema(_ db: Database) throws {
        // Cache of metadata for each folder for display
        try db.create(table: FolderMetadata.databaseTableName) { t in
            t.column(FolderMetadata.Column.parentFolderId, .integer).notNull().primaryKey()
            t.column(FolderMetadata.Column.folderCount, .integer).notNull()
            t.column(FolderMetadata.Column.songCount, .integer).notNull()
            t.column(FolderMetadata.Column.duration, .integer).notNull()
        }
    }
}

extension Store {
    func resetFolderAlbumCache(parentFolderId: Int) -> Bool {
        do {
            return try serverDb.write { db in
                try db.execute(literal: "DELETE FROM folderAlbumList WHERE parentFolderId = \(parentFolderId)")
                try db.execute(literal: "DELETE FROM folderSongList WHERE parentFolderId = \(parentFolderId)")
                return true
            }
        } catch {
            DDLogError("Failed to reset folder \(parentFolderId) cache: \(error)")
            return false
        }
    }
    
    func folderAlbumIds(parentFolderId: Int) -> [Int] {
        do {
            return try serverDb.read { db in
                let sql: SQLLiteral = """
                    SELECT id
                    FROM folderAlbumList
                    WHERE parentFolderId = \(parentFolderId)
                    ORDER BY \(Column.rowID) ASC
                    """
                return try SQLRequest<Int>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select folder album IDs for parent folder ID \(parentFolderId): \(error)")
            return []
        }
    }
    
    func folderAlbum(id: Int) -> FolderAlbum? {
        do {
            return try serverDb.read { db in
                try FolderAlbum.filter(key: id).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select folder album \(id): \(error)")
            return nil
        }
    }
    
    func add(folderAlbum: FolderAlbum) -> Bool {
        do {
            return try serverDb.write { db in
                // Insert or update shared album record
                try folderAlbum.save(db)
                
                // Insert folder id into list cache
                let sql: SQLLiteral = """
                    INSERT INTO folderAlbumList
                    (parentFolderId, folderId)
                    VALUES (\(folderAlbum.parentFolderId), \(folderAlbum.id))
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to insert folder album \(folderAlbum): \(error)")
            return false
        }
    }
    
    func songIds(parentFolderId: Int) -> [Int] {
        do {
            return try serverDb.read { db in
                let sql: SQLLiteral = """
                    SELECT songId
                    FROM folderSongList
                    WHERE parentFolderId = \(parentFolderId)
                    ORDER BY \(Column.rowID) ASC
                    """
                return try SQLRequest<Int>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select song IDs for parent folder ID \(parentFolderId): \(error)")
            return []
        }
    }
    
    func add(folderSong song: NewSong) -> Bool {
        do {
            return try serverDb.write { db in
                // Insert or update shared song record
                try song.save(db)
                
                // Insert song id into list cache
                let sql: SQLLiteral = """
                    INSERT INTO folderSongList
                    (parentFolderId, songId)
                    VALUES (\(song.parentFolderId), \(song.id))
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to insert folder song \(song) in folder \(song.parentFolderId): \(error)")
            return false
        }
    }
    
    func folderMetadata(parentFolderId: Int) -> FolderMetadata? {
        do {
            return try serverDb.read { db in
                try FolderMetadata.filter(key: parentFolderId).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select folder metadata \(parentFolderId): \(error)")
            return nil
        }
    }
    
    func add(folderMetadata: FolderMetadata) -> Bool {
        do {
            return try serverDb.write { db in
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

