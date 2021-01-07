//
//  TagAlbumStore.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjackSwift

extension TagAlbum: FetchableRecord, PersistableRecord {
    struct Table {
        static let tagSongList = "tagSongList"
    }
    enum Column: String, ColumnExpression {
        case id, name, coverArtId, tagArtistId, tagArtistName, songCount, duration, playCount, year, genre
    }
    enum RelatedColumn: String, ColumnExpression {
        case tagAlbumId, songId
    }
    
    static func createInitialSchema(_ db: Database) throws {
        // Shared table of unique album records
        try db.create(table: TagAlbum.databaseTableName) { t in
            t.column(TagAlbum.Column.id, .integer).notNull().primaryKey()
            t.column(TagAlbum.Column.name, .text).notNull()
            t.column(TagAlbum.Column.coverArtId, .text)
            t.column(TagAlbum.Column.tagArtistId, .integer).indexed()
            t.column(TagAlbum.Column.tagArtistName, .text)
            t.column(TagAlbum.Column.songCount, .integer).notNull()
            t.column(TagAlbum.Column.duration, .integer).notNull()
            t.column(TagAlbum.Column.playCount, .integer)
            t.column(TagAlbum.Column.year, .integer)
            t.column(TagAlbum.Column.genre, .text)
        }
        
        // Cache of song IDs for each tag album for display
        try db.create(table: TagAlbum.Table.tagSongList) { t in
            t.autoIncrementedPrimaryKey(GRDB.Column.rowID).notNull()
            t.column(TagAlbum.RelatedColumn.tagAlbumId, .integer).notNull().indexed()
            t.column(TagAlbum.RelatedColumn.songId, .integer).notNull()
        }
    }
}

extension Store {
    func deleteTagAlbums(tagArtistId: Int) -> Bool {
        do {
            return try serverDb.write { db in
                try db.execute(literal: "DELETE FROM \(TagAlbum.self) WHERE tagArtistId = \(tagArtistId)")
                return true
            }
        } catch {
            DDLogError("Failed to delete tag albums for tag artist \(tagArtistId): \(error)")
            return false
        }
    }
    
    // TODO: Complete this query when needed for UI
//    func tagAlbumIds(mediaFolderId: Int, orderBy: TagAlbum.Column = .name) -> [String] {
//        do {
//            return try serverDb.read { db in
//                let sql: SQLLiteral = """
//                    SELECT id
//                    FROM \(TagAlbum.self)
//                    JOIN
//                    WHERE mediaFolderId = \(mediaFolderId)
//                    ORDER BY \(orderBy) ASC
//                    """
//                return try SQLRequest<String>(literal: sql).fetchAll(db)
//            }
//        } catch {
//            DDLogError("Failed to select tag album IDs for media folder \(mediaFolderId) ordered by \(orderBy): \(error)")
//            return []
//        }
//    }
    
    func tagAlbumIds(tagArtistId: Int, orderBy: TagAlbum.Column = .name) -> [Int] {
        do {
            return try serverDb.read { db in
                let sql: SQLLiteral = """
                    SELECT id
                    FROM \(TagAlbum.self)
                    WHERE tagArtistId = \(tagArtistId)
                    ORDER BY \(orderBy) ASC
                    """
                return try SQLRequest<Int>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select tag album IDs for tag artist ID \(tagArtistId) ordered by \(orderBy): \(error)")
            return []
        }
    }
    
    func tagAlbum(id: Int) -> TagAlbum? {
        do {
            return try serverDb.read { db in
                try TagAlbum.filter(key: id).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select tag album \(id): \(error)")
            return nil
        }
    }
    
    func add(tagAlbum: TagAlbum) -> Bool {
        do {
            return try serverDb.write { db in
                // Insert or update shared album record
                try tagAlbum.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to insert tag album \(tagAlbum): \(error)")
            return false
        }
    }
    
    func songIds(tagAlbumId: Int) -> [Int] {
        do {
            return try serverDb.read { db in
                let sql: SQLLiteral = """
                    SELECT songId
                    FROM tagSongList
                    WHERE tagAlbumId = \(tagAlbumId)
                    ORDER BY \(Column.rowID) ASC
                    """
                return try SQLRequest<Int>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select song IDs for tag album ID \(tagAlbumId): \(error)")
            return []
        }
    }
    
    func deleteTagSongs(tagAlbumId: Int) -> Bool {
        do {
            return try serverDb.write { db in
                try db.execute(literal: "DELETE FROM tagSongList WHERE tagAlbumId = \(tagAlbumId)")
                return true
            }
        } catch {
            DDLogError("Failed to reset tag album song cache: \(error)")
            return false
        }
    }
    
    func add(tagSong song: NewSong) -> Bool {
        do {
            return try serverDb.write { db in
                // Insert or update shared song record
                try song.save(db)
                
                // Insert song id into list cache
                let sql: SQLLiteral = """
                    INSERT INTO tagSongList
                    (tagAlbumId, songId)
                    VALUES (\(song.tagAlbumId), \(song.id))
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to insert tag song \(song) in tag album \(song.tagAlbumId): \(error)")
            return false
        }
    }
}
