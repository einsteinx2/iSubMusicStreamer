//
//  LyricsStore.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjackSwift

extension Lyrics: FetchableRecord, PersistableRecord {
    enum Column: String, ColumnExpression {
        case tagArtistName, songTitle, lyricsText
    }
    
    static func createInitialSchema(_ db: Database) throws {
        try db.create(table: Lyrics.databaseTableName) { t in
            t.column(Column.tagArtistName, .text).notNull()
            t.column(Column.songTitle, .text).notNull()
            t.column(Column.lyricsText, .text).notNull()
            t.primaryKey([Column.tagArtistName, Column.songTitle])
        }
    }
}

extension Store {
    // TODO: Should this return true when the if statement fails to prevent need for the same check in other places?
    func isLyricsCached(song: Song) -> Bool {
        if let tagArtistName = song.tagArtistName, song.title.count > 0 {
            return isLyricsCached(tagArtistName: tagArtistName, songTitle: song.title)
        }
        return false
    }
    
    @objc func isLyricsCached(tagArtistName: String, songTitle: String) -> Bool {
        do {
            return try pool.read { db in
                try Lyrics.filter(literal: "tagArtistName = \(tagArtistName) AND songTitle = \(songTitle)").fetchCount(db) > 0
            }
        } catch {
            DDLogError("Failed to select lyrics count tag artist \(tagArtistName) and song \(songTitle): \(error)")
            return false
        }
    }
    
    func lyrics(tagArtistName: String, songTitle: String) -> Lyrics? {
        do {
            return try pool.read { db in
                try Lyrics.filter(literal: "tagArtistName = \(tagArtistName) AND songTitle = \(songTitle)").fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select lyrics for artist \(tagArtistName) and song \(songTitle): \(error)")
            return nil
        }
    }
    
    func lyricsText(tagArtistName: String, songTitle: String) -> String? {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT lyricsText
                    FROM \(Lyrics.self)
                    WHERE tagArtistName = \(tagArtistName) AND songTitle = \(songTitle)
                    """
                return try SQLRequest<String>(literal: sql).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select lyrics text for artist \(tagArtistName) and song \(songTitle): \(error)")
            return nil
        }
    }
    
    func add(lyrics: Lyrics) -> Bool {
        do {
            return try pool.write { db in
                try lyrics.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to insert lyrics: \(error)")
            return false
        }
    }
}
