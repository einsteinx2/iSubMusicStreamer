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

extension NewSong: FetchableRecord, PersistableRecord {
    static var databaseTableName: String = "song"
    
    enum Column: String, ColumnExpression {
        case id, title, coverArtId, parentFolderId, tagArtistName, tagAlbumName, playCount, year, tagArtistId, tagAlbumId, genre, path, suffix, transcodedSuffix, duration, bitrate, track, discNumber, size, isVideo
    }
    
    static func createInitialSchema(_ db: Database) throws {
        // Shared table of unique song records
        try db.create(table: NewSong.databaseTableName) { t in
            t.column(NewSong.Column.id, .integer).notNull().primaryKey()
            t.column(NewSong.Column.title, .text).notNull()
            t.column(NewSong.Column.coverArtId, .text)
            t.column(NewSong.Column.parentFolderId, .integer)
            t.column(NewSong.Column.tagArtistName, .text)
            t.column(NewSong.Column.tagAlbumName, .text)
            t.column(NewSong.Column.playCount, .integer)
            t.column(NewSong.Column.year, .integer)
            t.column(NewSong.Column.tagArtistId, .integer)
            t.column(NewSong.Column.tagAlbumId, .integer)
            t.column(NewSong.Column.genre, .text)
            t.column(NewSong.Column.path, .text).notNull()
            t.column(NewSong.Column.suffix, .text).notNull()
            t.column(NewSong.Column.transcodedSuffix, .text)
            t.column(NewSong.Column.duration, .integer).notNull()
            t.column(NewSong.Column.bitrate, .integer).notNull()
            t.column(NewSong.Column.track, .integer).notNull()
            t.column(NewSong.Column.discNumber, .integer)
            t.column(NewSong.Column.size, .integer).notNull()
            t.column(NewSong.Column.isVideo, .boolean).notNull()
        }
    }
}

extension Store {
    func song(id: Int) -> NewSong? {
        do {
            return try serverDb.read { db in
                try NewSong.filter(key: id).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select song \(id): \(error)")
            return nil
        }
    }
    
    func add(song: NewSong) -> Bool {
        do {
            return try serverDb.write { db in
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
