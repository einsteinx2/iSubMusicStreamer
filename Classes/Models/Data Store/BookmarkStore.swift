//
//  BookmarkStore.swift
//  iSub
//
//  Created by Benjamin Baron on 2/2/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjackSwift
import Resolver

extension Bookmark: FetchableRecord, PersistableRecord {
    enum Column: String, ColumnExpression {
        case id, songServerId, songId, localPlaylistId, songIndex, offsetInSeconds, offsetInBytes
    }
    
    static func createInitialSchema(_ db: Database) throws {
        try db.create(table: Bookmark.databaseTableName) { t in
            t.column(Column.id, .integer).notNull().primaryKey()
            t.column(Column.songServerId, .integer).notNull()
            t.column(Column.songId, .integer).notNull()
            t.column(Column.localPlaylistId, .integer).notNull().indexed()
            t.column(Column.songIndex, .integer).notNull()
            t.column(Column.offsetInSeconds, .double).notNull()
            t.column(Column.offsetInBytes, .integer).notNull()
        }
        try db.create(indexOn: Bookmark.databaseTableName, columns: [Column.songServerId, Column.songId])
    }
}

extension Store {
    private var playQueue: PlayQueue { Resolver.resolve() }
    
    var nextBookmarkId: Int? {
        do {
            return try pool.read { db in
                if let maxId = try SQLRequest<Int>(literal: "SELECT MAX(id) FROM \(Bookmark.self)").fetchOne(db) {
                    return maxId + 1
                }
                return 1
            }
        } catch {
            DDLogError("Failed to select next bookmark ID: \(error)")
            return nil
        }
    }
    
    func addBookmark(name: String, songIndex: Int, offsetInSeconds: Double, offsetInBytes: Int) -> Bool {
        do {
            return try pool.write { db in
                // Get the song object
                guard let nextLocalPlaylistId = nextLocalPlaylistId, let nextBookmarkId = nextBookmarkId, let song = playQueue.song(index: songIndex) else { return false }

                // Create the local playlist to store the songs
                var playlist = LocalPlaylist(id: nextLocalPlaylistId, name: name, isBookmark: true)
                try playlist.save(db)

                // Create the bookmark record
                let bookmark = Bookmark(id: nextBookmarkId, song: song, localPlaylist: playlist, songIndex: songIndex, offsetInSeconds: offsetInSeconds, offsetInBytes: offsetInBytes)

                // Add the songs from current play queue to the new playlist
                let sql: SQLLiteral = """
                    SELECT serverId, songId
                    FROM localPlaylistSong
                    WHERE localPlaylistId = \(playQueue.currentPlaylistId)
                    ORDER BY position ASC
                    """
                let rows = try SQLRequest<Row>(literal: sql).fetchCursor(db)
                while let row = try rows.next() {
                    let serverId: Int = row["serverId"]
                    let songId: Int = row["songId"]
                    try LocalPlaylist.insertSong(db, serverId: serverId, songId: songId, position: playlist.songCount, playlistId: playlist.id)
                    playlist.songCount += 1
                }
                
                // Update the playlist count
                try playlist.save(db)

                // Save the bookmark record
                try bookmark.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to insert bookmark \"\(name)\", songIndex \(songIndex), offsetInSeconds \(offsetInSeconds), offsetInBytes \(offsetInBytes): \(error)")
            return false
        }
    }
    
    func bookmarks() -> [Bookmark] {
        do {
            return try pool.read { db in
                try Bookmark.order(Bookmark.Column.id.desc).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all bookmarks: \(error)")
            return []
        }
    }
    
    func bookmark(id: Int) -> Bookmark? {
        do {
            return try pool.read { db in
                try Bookmark.fetchOne(db, key: id)
            }
        } catch {
            DDLogError("Failed to select bookmark \(id): \(error)")
            return nil
        }
    }
    
    func bookmarksCount(song: Song) -> Int? {
        do {
            return try pool.read { db in
                try Bookmark.filter(literal: "songServerId = \(song.serverId) AND songId = \(song.id)").fetchCount(db)
            }
        } catch {
            DDLogError("Failed to select count of bookmarks for song \(song): \(error)")
            return nil
        }
    }
    
    func delete(bookmarkId: Int) -> Bool {
        guard let bookmark = bookmark(id: bookmarkId) else { return false }
        return delete(bookmark: bookmark)
    }
    
    func delete(bookmark: Bookmark) -> Bool {
        do {
            return try pool.write { db in
                try bookmark.delete(db)
                try LocalPlaylist.delete(db, id: bookmark.localPlaylistId)
                return true
            }
        } catch {
            DDLogError("Failed to delete bookmark \(bookmark): \(error)")
            return false
        }
    }
    
    func song(bookmark: Bookmark) -> Song? {
        return song(serverId: bookmark.songServerId, id: bookmark.songId)
    }
    
    func localPlaylist(bookmark: Bookmark) -> LocalPlaylist? {
        return localPlaylist(id: bookmark.localPlaylistId)
    }
}
