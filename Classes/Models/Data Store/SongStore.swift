//
//  SongStore.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjackSwift

extension Song: FetchableRecord, PersistableRecord {
    static var databaseTableName: String = "song"
    
    enum Column: String, ColumnExpression {
        case serverId, id, title, coverArtId, parentFolderId, tagArtistName, tagAlbumName, playCount, year, tagArtistId, tagAlbumId, genre, path, suffix, transcodedSuffix, duration, kiloBitrate, track, discNumber, size, isVideo
    }
    
    static func createInitialSchema(_ db: Database) throws {
        // Shared table of unique song records
        try db.create(table: Song.databaseTableName) { t in
            t.column(Column.serverId, .integer).notNull()
            t.column(Column.id, .integer).notNull()
            t.column(Column.title, .text).notNull()
            t.column(Column.coverArtId, .text)
            t.column(Column.parentFolderId, .integer)
            t.column(Column.tagArtistName, .text)
            t.column(Column.tagAlbumName, .text)
            t.column(Column.playCount, .integer)
            t.column(Column.year, .integer)
            t.column(Column.tagArtistId, .integer)
            t.column(Column.tagAlbumId, .integer)
            t.column(Column.genre, .text)
            t.column(Column.path, .text).notNull()
            t.column(Column.suffix, .text).notNull()
            t.column(Column.transcodedSuffix, .text)
            t.column(Column.duration, .integer).notNull()
            t.column(Column.kiloBitrate, .integer).notNull()
            t.column(Column.track, .integer).notNull()
            t.column(Column.discNumber, .integer)
            t.column(Column.size, .integer).notNull()
            t.column(Column.isVideo, .boolean).notNull()
            t.primaryKey([Column.serverId, Column.id])
        }
    }
}

extension Store {
    func song(serverId: Int, id: Int) -> Song? {
        do {
            return try pool.read { db in
                try Song.filter(literal: "serverId = \(serverId) AND id = \(id)").fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select song \(id) for server \(serverId): \(error)")
            return nil
        }
    }
    
    func add(song: Song) -> Bool {
        do {
            return try pool.write { db in
                // Insert or update shared song record
                try song.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to insert song \(song): \(error)")
            return false
        }
    }
}
