//
//  LocalPlaylistStore.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjackSwift
import Resolver

extension LocalPlaylist: FetchableRecord, PersistableRecord {
    struct Table {
        static let localPlaylistSong = "localPlaylistSong"
    }
    
    enum Column: String, ColumnExpression {
        case id, name, songCount, isBookmark, createdDate
    }
    enum RelatedColumn: String, ColumnExpression {
        case localPlaylistId, serverId, songId, position
    }
    
    static func createInitialSchema(_ db: Database) throws {
        try db.create(table: LocalPlaylist.databaseTableName) { t in
            t.column(Column.id, .integer).notNull().primaryKey()
            t.column(Column.name, .text).notNull()
            t.column(Column.songCount, .integer).notNull()
            t.column(Column.isBookmark, .boolean).notNull().indexed()
            t.column(Column.createdDate, .datetime).notNull()
        }
        
        // Create default playlists
        let defaultPlaylists = [LocalPlaylist(id: LocalPlaylist.Default.playQueueId, name: "Play Queue"),
                                LocalPlaylist(id: LocalPlaylist.Default.shuffleQueueId, name: "Shuffle Queue"),
                                LocalPlaylist(id: LocalPlaylist.Default.jukeboxPlayQueueId, name: "Jukebox Play Queue"),
                                LocalPlaylist(id: LocalPlaylist.Default.jukeboxShuffleQueueId, name: "Jukebox Shuffle Queue")]
        for playlist in defaultPlaylists {
            try playlist.save(db)
        }
        
        try db.create(table: Table.localPlaylistSong) { t in
            t.column(RelatedColumn.localPlaylistId, .integer).notNull()
            t.column(RelatedColumn.position, .integer).notNull()
            t.column(RelatedColumn.serverId, .integer).notNull()
            t.column(RelatedColumn.songId, .text).notNull()
        }
        try db.create(indexOn: Table.localPlaylistSong, columns: [RelatedColumn.localPlaylistId, RelatedColumn.position])
        try db.create(indexOn: Table.localPlaylistSong, columns: [RelatedColumn.localPlaylistId, RelatedColumn.serverId, RelatedColumn.songId])
    }
    
//    static func add(_ db: Database, id: Int? = nil, name: String, isBookmark: Bool = false) throws {
//        let store: Store = Resolver.resolve()
//        let localPlaylistId = id ?? store.nextLocalPlaylistId()
//        let localPlaylist = LocalPlaylist(id: localPlaylistId, name: name, isBookmark: isBookmark)
//        try localPlaylist.save(db)
//    }
    
    static func fetchSongs(_ db: Database, playlistId: Int) throws -> [Song] {
        let sql: SQLLiteral = """
            SELECT *
            FROM \(Song.self)
            JOIN localPlaylistSong
            ON \(Song.self).serverId = localPlaylistSong.serverId AND \(Song.self).id = localPlaylistSong.songId
            WHERE localPlaylistSong.localPlaylistId = \(playlistId)
            """
        return try SQLRequest<Song>(literal: sql).fetchAll(db)
    }
    
    static func fetchSong(_ db: Database, playlistId: Int, position: Int) throws -> Song? {
        let sql: SQLLiteral = """
            SELECT *
            FROM \(Song.self)
            JOIN localPlaylistSong
            ON \(Song.self).serverId = localPlaylistSong.serverId AND \(Song.self).id = localPlaylistSong.songId
            WHERE localPlaylistSong.localPlaylistId = \(playlistId) AND localPlaylistSong.position = \(position)
            LIMIT 1
            """
        return try SQLRequest<Song>(literal: sql).fetchOne(db)
    }
    
    static func insertSong(_ db: Database, song: Song, position: Int, playlistId: Int) throws {
        try insertSong(db, serverId: song.serverId, songId: song.id, position: position, playlistId: playlistId)
    }
    
    static func insertSong(_ db: Database, serverId: Int, songId: String, position: Int, playlistId: Int) throws {
        let sql: SQLLiteral = """
            INSERT INTO localPlaylistSong (localPlaylistId, position, serverId, songId)
            VALUES (\(playlistId), \(position), \(serverId), \(songId))
            """
        try db.execute(literal: sql)
    }
    
    static func delete(_ db: Database, id: Int) throws {
        try db.execute(literal: "DELETE FROM \(LocalPlaylist.self) WHERE id = \(id)")
        try db.execute(literal: "DELETE FROM localPlaylistSong WHERE localPlaylistId = \(id)")
    }
}

// TODO: Handle Jukebox mode properly
extension Store {
    private var settings: Settings { Resolver.resolve() }
    private var playQueue: PlayQueue { Resolver.resolve() }
    
    var nextLocalPlaylistId: Int? {
        do {
            return try pool.read { db in
                if let maxId = try SQLRequest<Int>(literal: "SELECT MAX(id) FROM \(LocalPlaylist.self)").fetchOne(db) {
                    return maxId + 1
                }
                return nil
            }
        } catch {
            DDLogError("Failed to select next local playlist ID: \(error)")
            return nil
        }
    }
    
    func localPlaylistsCount(isBookmark: Bool = false) -> Int? {
        do {
            return try pool.read { db in
                try LocalPlaylist.filter(literal: "id > \(LocalPlaylist.Default.maxDefaultId) AND isBookmark = \(isBookmark)").fetchCount(db)
            }
        } catch {
            DDLogError("Failed to select count of local playlists, isBookmark \(isBookmark): \(error)")
            return nil
        }
    }
    
    func localPlaylists(isBookmark: Bool = false) -> [LocalPlaylist] {
        do {
            return try pool.read { db in
                try LocalPlaylist.filter(literal: "id > \(LocalPlaylist.Default.maxDefaultId) AND isBookmark = \(isBookmark)").fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all local playlists: \(error)")
            return []
        }
    }
    
    func localPlaylist(id: Int) -> LocalPlaylist? {
        do {
            return try pool.read { db in
                try LocalPlaylist.fetchOne(db, key: id)
            }
        } catch {
            DDLogError("Failed to select local playlist \(id): \(error)")
            return nil
        }
    }
    
//    func addLocalPlaylist(id: Int? = nil, name: String, isBookmark: Bool = false) -> Bool {
//        do {
//            return try pool.write { db in
//                try LocalPlaylist.add(db, id: id, name: name)
//                return true
//            }
//        } catch {
//            DDLogError("Failed to insert local playlist \(name): \(error)")
//            return false
//        }
//    }
    
    func add(localPlaylist: LocalPlaylist) -> Bool {
        do {
            return try pool.write { db in
                try localPlaylist.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to insert local playlist \(localPlaylist): \(error)")
            return false
        }
    }
    
    func delete(localPlaylistId: Int) -> Bool {
        do {
            return try pool.write { db in
                try LocalPlaylist.delete(db, id: localPlaylistId)
                return true
            }
        } catch {
            DDLogError("Failed to delete local playlist \(localPlaylistId): \(error)")
            return false
        }
    }
    
    func clear(localPlaylistId: Int) -> Bool {
        do {
            return try pool.write { db in
                try db.execute(literal: "UPDATE \(LocalPlaylist.self) SET songCount = 0 WHERE id = \(localPlaylistId)")
                try db.execute(literal: "DELETE FROM localPlaylistSong WHERE localPlaylistId = \(localPlaylistId)")
                return true
            }
        } catch {
            DDLogError("Failed to clear local playlist \(localPlaylistId): \(error)")
            return false
        }
    }
    
    func songs(localPlaylistId: Int) -> [Song] {
        do {
            return try pool.read { db in
                return try LocalPlaylist.fetchSongs(db, playlistId: localPlaylistId)
            }
        } catch {
            DDLogError("Failed to select songs in local playlist \(localPlaylistId): \(error)")
            return []
        }
    }
    
    func song(localPlaylistId: Int, position: Int) -> Song? {
        do {
            return try pool.read { db in
                return try LocalPlaylist.fetchSong(db, playlistId: localPlaylistId, position: position)
            }
        } catch {
            DDLogError("Failed to select song at position \(position) in local playlist \(localPlaylistId): \(error)")
            return nil
        }
    }
    
    func add(song: Song, localPlaylistId: Int) -> Bool {
        do {
            return try pool.write { db in
                // Select the playlist to get the count as it's O(1) instead of MAX(position) which is O(N)
                guard var playlist = try LocalPlaylist.fetchOne(db, key: localPlaylistId) else { return false }
                    
                // Add the song to the playlist
                try LocalPlaylist.insertSong(db, song: song, position: playlist.songCount, playlistId: localPlaylistId)
                
                // Update the playlist count
                playlist.songCount += 1
                try playlist.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to add song to end of local playlist \(localPlaylistId): \(error)")
            return false
        }
    }
    
    func add(song: Song, localPlaylistId: Int, position: Int) -> Bool {
        do {
            return try pool.write { db in
                // Select the playlist to get the count as it's O(1) instead of MAX(position) which is O(N)
                guard var playlist = try LocalPlaylist.fetchOne(db, key: localPlaylistId), position <= playlist.songCount else { return false }
                    
                // Update all song positions after the current position
                let positionSql: SQLLiteral = """
                    UPDATE localPlaylistSong
                    SET position = position + 1
                    WHERE position >= \(position) AND localPlaylistId = \(localPlaylistId)
                    """
                try db.execute(literal: positionSql)

                // Add the song to the playlist
                try LocalPlaylist.insertSong(db, song: song, position: position, playlistId: localPlaylistId)
                
                // Update the playlist count
                playlist.songCount += 1
                try playlist.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to add song to position \(position) in local playlist \(localPlaylistId): \(error)")
            return false
        }
    }
    
    func add(songIds: [String], serverId: Int, localPlaylistId: Int) -> Bool {
        do {
            return try pool.write { db in
                // Select the playlist to get the count as it's O(1) instead of MAX(position) which is O(N)
                guard var playlist = try LocalPlaylist.fetchOne(db, key: localPlaylistId) else { return false }
                    
                // Add the song to the playlist
                for (index, songId) in songIds.enumerated() {
                    let sql: SQLLiteral = """
                        INSERT INTO localPlaylistSong (localPlaylistId, position, serverId, songId)
                        VALUES (\(localPlaylistId), \(index + playlist.songCount), \(serverId), \(songId))
                        """
                    try db.execute(literal: sql)
                }
                
                // Update the playlist count
                playlist.songCount += songIds.count
                try playlist.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to add song to end of local playlist \(localPlaylistId): \(error)")
            return false
        }
    }
    
    // TODO: Move this to a single transaction
    func queue(song: Song) -> Bool {
        var success = true
        if settings.isJukeboxEnabled {
            if playQueue.isShuffle {
                success = add(song: song, localPlaylistId: LocalPlaylist.Default.jukeboxShuffleQueueId)
            }
            if success {
                success = add(song: song, localPlaylistId: LocalPlaylist.Default.jukeboxPlayQueueId)
            }
        } else {
            if playQueue.isShuffle {
                success = add(song: song, localPlaylistId: LocalPlaylist.Default.shuffleQueueId)
            }
            if success {
                success = add(song: song, localPlaylistId: LocalPlaylist.Default.playQueueId)
            }
        }
        return success
    }
    
    func queueNext(song: Song, offset: Int = 0) -> Bool {
        var success = true
        if settings.isJukeboxEnabled {
            if playQueue.isShuffle {
                // Add next
                success = add(song: song, localPlaylistId: LocalPlaylist.Default.jukeboxShuffleQueueId, position: playQueue.nextIndexIgnoringRepeatMode + offset)
                if success {
                    // Add to end
                    success = add(song: song, localPlaylistId: LocalPlaylist.Default.jukeboxPlayQueueId)
                }
            } else {
                // Add next
                success = add(song: song, localPlaylistId: LocalPlaylist.Default.jukeboxPlayQueueId, position: playQueue.nextIndexIgnoringRepeatMode + offset)
            }
        } else {
            if playQueue.isShuffle {
                // Add next
                success = add(song: song, localPlaylistId: LocalPlaylist.Default.shuffleQueueId, position: playQueue.nextIndexIgnoringRepeatMode + offset)
                if success {
                    // Add to end
                    success = add(song: song, localPlaylistId: LocalPlaylist.Default.playQueueId)
                }
            } else {
                success = add(song: song, localPlaylistId: LocalPlaylist.Default.playQueueId, position: playQueue.nextIndexIgnoringRepeatMode + offset)
            }
        }
        return success
    }
    
    // TODO: Move this to a single transaction
    func queue(songIds: [String], serverId: Int) -> Bool {
        var success = true
        if settings.isJukeboxEnabled {
            if playQueue.isShuffle {
                success = add(songIds: songIds, serverId: serverId, localPlaylistId: LocalPlaylist.Default.jukeboxShuffleQueueId)
            }
            if success {
                success = add(songIds: songIds, serverId: serverId, localPlaylistId: LocalPlaylist.Default.jukeboxPlayQueueId)
            }
        } else {
            if playQueue.isShuffle {
                success = add(songIds: songIds, serverId: serverId, localPlaylistId: LocalPlaylist.Default.shuffleQueueId)
            }
            if success {
                success = add(songIds: songIds, serverId: serverId, localPlaylistId: LocalPlaylist.Default.playQueueId)
            }
        }
        return success
    }
    
    func clearPlayQueue() -> Bool {
        var success = true
        if settings.isJukeboxEnabled {
            if playQueue.isShuffle {
                success = clear(localPlaylistId: LocalPlaylist.Default.jukeboxShuffleQueueId)
            }
            if success {
                success = clear(localPlaylistId: LocalPlaylist.Default.jukeboxPlayQueueId)
            }
        } else {
            if playQueue.isShuffle {
                success = clear(localPlaylistId: LocalPlaylist.Default.shuffleQueueId)
            }
            if success {
                success = clear(localPlaylistId: LocalPlaylist.Default.playQueueId)
            }
        }
        return success
    }
    
    // TODO: Move this to a single transaction
    func clearAndQueue(songIds: [String], serverId: Int) -> Bool {
        if clearPlayQueue() {
            return queue(songIds: songIds, serverId: serverId)
        }
        return false
    }
    
    // TODO: Move this to a single transaction
    func clearAndQueue(songs: [Song]) -> Bool {
        if clearPlayQueue() {
            for song in songs {
                if !queue(song: song) {
                    return false
                }
            }
        }
        return true
    }
    
    func playSong(position: Int, songIds: [String], serverId: Int) -> Song? {
        if clearAndQueue(songIds: songIds, serverId: serverId) {
            // Set player defaults
            playQueue.isShuffle = false
            
            NotificationCenter.postOnMainThread(name: Notifications.currentPlaylistSongsQueued)
            
            // Start the song
            return playQueue.playSong(position: position)
        }
        return nil
    }
    
    func playSong(position: Int, songs: [Song]) -> Song? {
        if clearAndQueue(songs: songs) {
            // Set player defaults
            playQueue.isShuffle = false
            
            NotificationCenter.postOnMainThread(name: Notifications.currentPlaylistSongsQueued)
            
            // Start the song
            return playQueue.playSong(position: position)
        }
        return nil
    }
    
    // TODO: Improve performance by preventing the need to convert to song objects
    func playSong(position: Int, downloadedSongs: [DownloadedSong]) -> Song? {
        let songs = downloadedSongs.compactMap { song(downloadedSong: $0) }
        return playSong(position: position, songs: songs)
    }
    
    // TODO: implement this - handle Jukebox mode and shuffle
    func playSong(position: Int, localPlaylistId: Int, secondsOffset: Double = 0.0, byteOffset: Int = 0) -> Song? {
        guard clearPlayQueue() else { return nil }
        
        do {
            // Fill the play queue
            try pool.write { db in
                // Add the songs from the playlist to the play queue
                // NOTE: This is NOT an SQLLiteral as that string interpolation doesn't work in the SELECT statement.
                //       There is no security risk directly interpolating the values here as they are integers and
                //       there is no posibility of SQL injection. Plus the values come from the code not user input.
                let sql = """
                    INSERT INTO localPlaylistSong (localPlaylistId, position, serverId, songId)
                    SELECT \(playQueue.currentPlaylistId) AS localPlaylistId, position, serverId, songId
                    FROM localPlaylistSong
                    WHERE localPlaylistId = \(localPlaylistId)
                    ORDER BY position ASC
                    """
                try db.execute(sql: sql)
            }
            
            // Set player defaults
            playQueue.isShuffle = false
            
            NotificationCenter.postOnMainThread(name: Notifications.currentPlaylistSongsQueued)
            
            // Start the song
            playQueue.currentIndex = position
            playQueue.startSong(offsetInBytes: byteOffset, offsetInSeconds: secondsOffset)
            return playQueue.currentSong
        } catch {
            DDLogError("Failed to play song at position \(position) from local playlist \(localPlaylistId) at secondsOffset \(secondsOffset) and byteOffset \(byteOffset): \(error)")
            return nil
        }
    }
    
    func playSong(bookmark: Bookmark) -> Song? {
        return playSong(position: bookmark.songIndex, localPlaylistId: bookmark.localPlaylistId, secondsOffset: bookmark.offsetInSeconds, byteOffset: bookmark.offsetInBytes)
    }
    
    func move(songAtPosition from: Int, toPosition to: Int, localPlaylistId: Int) -> Bool {
        guard from != to, to >= 0 else { return false }
        
        do {
            return try pool.write { db in
                // Select the playlist to get the count as it's O(1) instead of MAX(position) which is O(N)
                guard let playlist = try LocalPlaylist.fetchOne(db, key: localPlaylistId), to < playlist.songCount else { return false }
                
                // Get the song we're moving
                guard let song = try LocalPlaylist.fetchSong(db, playlistId: localPlaylistId, position: from) else { return false }
                
                // Remove the song from the playlist
                let removeSongSql: SQLLiteral = """
                    DELETE FROM localPlaylistSong
                    WHERE localPlaylistId = \(localPlaylistId) AND position = \(from)
                    """
                try db.execute(literal: removeSongSql)
                
                // Update song positions
                if to < from {
                    let positionSql: SQLLiteral = """
                        UPDATE localPlaylistSong
                        SET position = position + 1
                        WHERE localPlaylistId = \(localPlaylistId) AND position >= \(to) AND position < \(from)
                        """
                    try db.execute(literal: positionSql)
                } else {
                    let positionSql: SQLLiteral = """
                        UPDATE localPlaylistSong
                        SET position = position - 1
                        WHERE localPlaylistId = \(localPlaylistId) AND position > \(from) AND position <= \(to)
                        """
                    try db.execute(literal: positionSql)
                }
                
                // Re-insert the song
                try LocalPlaylist.insertSong(db, song: song, position: to, playlistId: localPlaylistId)
                return true
            }
        } catch {
            DDLogError("Failed to move song from position \(from) to position \(to) in local playlist \(localPlaylistId): \(error)")
            return false
        }
    }
    
    func remove(songsAtPositions positions: [Int], localPlaylistId: Int) -> Bool {
        do {
            return try pool.write { db in
                // Select the playlist to get the count as it's O(1) instead of MAX(position) which is O(N)
                guard var playlist = try LocalPlaylist.fetchOne(db, key: localPlaylistId) else { return false }
                
                // Filter the valid positions
                let validPositions = positions.filter { $0 >= 0 && $0 < playlist.songCount }
                
                // Remove the songs from the playlist
                let removeSongsSql: SQLLiteral = """
                    DELETE FROM localPlaylistSong
                    WHERE localPlaylistId = \(localPlaylistId) AND position IN \(validPositions)
                    """
                try db.execute(literal: removeSongsSql)
                
                // Update song positions
                let songRequestSql: SQLLiteral = """
                    SELECT serverId, songId
                    FROM localPlaylistSong
                    WHERE localPlaylistId = \(localPlaylistId)
                    ORDER BY position ASC
                    """
                let songTuples = try SQLRequest<Row>(literal: songRequestSql).fetchAll(db).map({ ($0[0] as Int, $0[1] as Int) })
                for (index, tuple) in songTuples.enumerated() {
                    let updateSql: SQLLiteral = """
                        UPDATE localPlaylistSong
                        SET position = \(index)
                        WHERE localPlaylistId = \(localPlaylistId) AND serverId = \(tuple.0) AND songId = \(tuple.1)
                        """
                    try db.execute(literal: updateSql)
                }
                
                // Update the playlist count
                playlist.songCount = songTuples.count
                try playlist.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to remove songs from positions \(positions) in local playlist \(localPlaylistId): \(error)")
            return false
        }
    }
}
