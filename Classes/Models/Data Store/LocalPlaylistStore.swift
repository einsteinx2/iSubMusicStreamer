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
        let sql: SQL = """
            SELECT *
            FROM \(Song.self)
            JOIN localPlaylistSong
            ON \(Song.self).serverId = localPlaylistSong.serverId AND \(Song.self).id = localPlaylistSong.songId
            WHERE localPlaylistSong.localPlaylistId = \(playlistId)
            """
        return try SQLRequest<Song>(literal: sql).fetchAll(db)
    }
    
    static func fetchSong(_ db: Database, playlistId: Int, position: Int) throws -> Song? {
        let sql: SQL = """
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
        let sql: SQL = """
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
    private var settings: SavedSettings { Resolver.resolve() }
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
    
    @discardableResult
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
    
    @discardableResult
    func clear(localPlaylistId: Int) -> Bool {
        do {
            return try pool.write { db in
                try clear(db: db, localPlaylistId: localPlaylistId)
                return true
            }
        } catch {
            DDLogError("Failed to clear local playlist \(localPlaylistId): \(error)")
            return false
        }
    }
    
    private func clear(db: Database, localPlaylistId: Int) throws {
        try db.execute(literal: "UPDATE \(LocalPlaylist.self) SET songCount = 0 WHERE id = \(localPlaylistId)")
        try db.execute(literal: "DELETE FROM localPlaylistSong WHERE localPlaylistId = \(localPlaylistId)")
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
    
    func getSongPosition(localPlaylistId: Int, songId: String) -> Int? {
        do {
            return try pool.read { db in
                let sql: SQL = """
                    SELECT position
                    FROM localPlaylistSong
                    WHERE localPlaylistId = \(localPlaylistId)
                    AND songId = \(Int(songId))
                    """
                return try SQLRequest<Int>(literal: sql).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to get the position of song with id \(songId) in local playlist \(localPlaylistId): \(error.localizedDescription) ")
            return nil
        }
    }
    
    func add(song: Song, localPlaylistId: Int) -> Bool {
        do {
            return try pool.write { db in
                try add(db: db, song: song, localPlaylistId: localPlaylistId)
                return true
            }
        } catch {
            DDLogError("Failed to add song to end of local playlist \(localPlaylistId): \(error)")
            return false
        }
    }
    
    private func add(db: Database, song: Song, localPlaylistId: Int) throws {
        // Select the playlist to get the count as it's O(1) instead of MAX(position) which is O(N)
        guard var playlist = try LocalPlaylist.fetchOne(db, key: localPlaylistId) else { throw RuntimeError(message: "Local playlist not found") }
            
        // Add the song to the playlist
        try LocalPlaylist.insertSong(db, song: song, position: playlist.songCount, playlistId: localPlaylistId)
        
        // Update the playlist count
        playlist.songCount += 1
        try playlist.save(db)
    }
    
    func add(song: Song, localPlaylistId: Int, position: Int) -> Bool {
        do {
            return try pool.write { db in
                try add(db: db, song: song, localPlaylistId: localPlaylistId, position: position)
                return true
            }
        } catch {
            DDLogError("Failed to add song to position \(position) in local playlist \(localPlaylistId): \(error)")
            return false
        }
    }
    
    private func add(db: Database, song: Song, localPlaylistId: Int, position: Int) throws {
        // Select the playlist to get the count as it's O(1) instead of MAX(position) which is O(N)
        guard var playlist = try LocalPlaylist.fetchOne(db, key: localPlaylistId), position <= playlist.songCount else { throw RuntimeError(message: "Local playlist not found") }
            
        // Update all song positions after the current position
        let positionSql: SQL = """
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
    }
    
    func add(songIds: [String], serverId: Int, localPlaylistId: Int) -> Bool {
        do {
            return try pool.write { db in
                try add(db: db, songIds: songIds, serverId: serverId, localPlaylistId: localPlaylistId)
                return true
            }
        } catch {
            DDLogError("Failed to add songs to end of local playlist \(localPlaylistId): \(error)")
            return false
        }
    }
    
    private func add(db: Database, songIds: [String], serverId: Int, localPlaylistId: Int) throws {
        // Select the playlist to get the count as it's O(1) instead of MAX(position) which is O(N)
        guard var playlist = try LocalPlaylist.fetchOne(db, key: localPlaylistId) else { throw RuntimeError(message: "Local playlist not found") }
            
        // Add the song to the playlist
        for (index, songId) in songIds.enumerated() {
            let sql: SQL = """
                INSERT INTO localPlaylistSong (localPlaylistId, position, serverId, songId)
                VALUES (\(localPlaylistId), \(index + playlist.songCount), \(serverId), \(songId))
                """
            try db.execute(literal: sql)
        }
        
        // Update the playlist count
        playlist.songCount += songIds.count
        try playlist.save(db)
    }
    
    private func queuePlaylistIds() -> (playQueueId: Int, shuffleQueueId: Int) {
        let isJukeboxEnabled = settings.isJukeboxEnabled
        let playQueuePlaylistId = isJukeboxEnabled ? LocalPlaylist.Default.jukeboxPlayQueueId : LocalPlaylist.Default.playQueueId
        let shuffleQueuePlaylistId = isJukeboxEnabled ? LocalPlaylist.Default.jukeboxShuffleQueueId : LocalPlaylist.Default.shuffleQueueId
        return (playQueueId: playQueuePlaylistId, shuffleQueueId: shuffleQueuePlaylistId)
    }
    
    @discardableResult
    func queue(song: Song) -> Bool {
        let (playQueueId, shuffleQueueId) = queuePlaylistIds()
        do {
            return try pool.write { db in
                try queue(db: db, song: song, playQueueId: playQueueId, shuffleQueueId: shuffleQueueId)
                return true
            }
        } catch {
            DDLogError("Failed to queue song: \(error)")
            return false
        }
    }
    
    private func queue(db: Database, song: Song, playQueueId: Int, shuffleQueueId: Int) throws {
        if playQueue.isShuffle {
            try add(db: db, song: song, localPlaylistId: shuffleQueueId)
        }
        try add(db: db, song: song, localPlaylistId: playQueueId)
    }
    
    @discardableResult
    func queueNext(song: Song, offset: Int = 0) -> Bool {
        let (playQueueId, shuffleQueueId) = queuePlaylistIds()
        do {
            return try pool.write { db in
                if playQueue.isShuffle {
                    // Add next
                    try add(db: db, song: song, localPlaylistId: shuffleQueueId, position: playQueue.nextIndexIgnoringRepeatMode + offset)
                    
                    // Add to end
                    try add(db: db, song: song, localPlaylistId: playQueueId)
                } else {
                    // Add next
                    try add(db: db, song: song, localPlaylistId: playQueueId, position: playQueue.nextIndexIgnoringRepeatMode + offset)
                }
                return true
            }
        } catch {
            DDLogError("Failed to queue song: \(error)")
            return false
        }
    }
    
    @discardableResult
    func queue(songIds: [String], serverId: Int) -> Bool {
        let (playQueueId, shuffleQueueId) = queuePlaylistIds()
        do {
            return try pool.write { db in
                try queue(db: db, songIds: songIds, serverId: serverId, playQueueId: playQueueId, shuffleQueueId: shuffleQueueId)
                return true
            }
        } catch {
            DDLogError("Failed to queue song: \(error)")
            return false
        }
    }
    
    private func queue(db: Database, songIds: [String], serverId: Int, playQueueId: Int, shuffleQueueId: Int) throws {
        if playQueue.isShuffle {
            try add(db: db, songIds: songIds, serverId: serverId, localPlaylistId: shuffleQueueId)
        }
        try add(db: db, songIds: songIds, serverId: serverId, localPlaylistId: playQueueId)
    }
    
    @discardableResult
    func clearPlayQueue() -> Bool {
        let (playQueueId, shuffleQueueId) = queuePlaylistIds()
        do {
            return try pool.write { db in
                try clearPlayQueue(db: db, playQueueId: playQueueId, shuffleQueueId: shuffleQueueId)
                return true
            }
        } catch {
            DDLogError("Failed to queue song: \(error)")
            return false
        }
    }
    
    private func clearPlayQueue(db: Database, playQueueId: Int, shuffleQueueId: Int) throws {
        if playQueue.isShuffle {
            try clear(db: db, localPlaylistId: shuffleQueueId)
        }
        try clear(db: db, localPlaylistId: playQueueId)
    }
    
    /// Create the shuffle queue for the playlist.
    /// - Parameter currentPosition: Current song position in localplaylist.
    /// - Returns: True or False.
    @discardableResult
    func createShuffleQueue(currentPosition: Int) -> Bool {
        do {
            // Clear the existing shuffle play queue playlist
            clear(localPlaylistId: LocalPlaylist.Default.shuffleQueueId)
            
            try pool.write { db in
                //Insert current playing song into the localPlaylistSong at the first position.
                let insertCurrentSongSQL: SQL = """
                    INSERT INTO localPlaylistSong (localPlaylistId, position, serverId, songId)
                    SELECT \(LocalPlaylist.Default.shuffleQueueId) AS localPlaylistId, 0 AS position, serverId, songId 
                    FROM localPlaylistSong
                    WHERE localPlaylistId = \(LocalPlaylist.Default.playQueueId)
                    AND position = \(currentPosition)                    
                    """
                try db.execute(literal: insertCurrentSongSQL)
                
                // Create a random list of songs from play queue.
                // Insert the shuffled queue into local playlist songs excluding the first position.
                let randomizeSql: SQL = """
                    INSERT INTO localPlaylistSong (localPlaylistId, position, serverId, songId)
                    SELECT \(LocalPlaylist.Default.shuffleQueueId) 
                    AS localPlaylistId, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS position, serverId, songId
                    FROM localPlaylistSong
                    WHERE localPlaylistId = \(LocalPlaylist.Default.playQueueId)
                    AND position != \(currentPosition)
                    """
                try db.execute(literal: randomizeSql)
                
                // Update the shuffle queue songCount in localPlaylist.
                let updateCountSql: SQL = """
                    UPDATE localPlaylist
                    SET songCount = (SELECT songCount FROM localPlaylist WHERE id = \(LocalPlaylist.Default.playQueueId))
                    WHERE id = \(LocalPlaylist.Default.shuffleQueueId)
                    """
                try db.execute(literal: updateCountSql)
            }
            return true
        } catch {
            DDLogError("Failed to create Shuffle queue: \(error)")
            return false
        }
    }
    
    @discardableResult
    func clearAndQueue(songIds: [String], serverId: Int) -> Bool {
        let (playQueueId, shuffleQueueId) = queuePlaylistIds()
        do {
            return try pool.write { db in
                try clearPlayQueue(db: db, playQueueId: playQueueId, shuffleQueueId: shuffleQueueId)
                try queue(db: db, songIds: songIds, serverId: serverId, playQueueId: playQueueId, shuffleQueueId: shuffleQueueId)
                return true
            }
        } catch {
            DDLogError("Failed to clear and queue songIds: \(error)")
            return false
        }
    }
    
    @discardableResult
    func clearAndQueue(songs: [Song]) -> Bool {
        let (playQueueId, shuffleQueueId) = queuePlaylistIds()
        do {
            return try pool.write { db in
                try clearPlayQueue(db: db, playQueueId: playQueueId, shuffleQueueId: shuffleQueueId)
                for song in songs {
                    try queue(db: db, song: song, playQueueId: playQueueId, shuffleQueueId: shuffleQueueId)
                }
                return true
            }
        } catch {
            DDLogError("Failed to clear and queue songIds: \(error)")
            return false
        }
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
                // NOTE: This is NOT an SQL as that string interpolation doesn't work in the SELECT statement.
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
    
    /// Change the song position in a playlist.
    /// - Parameters:
    ///   - from: The current song position.
    ///   - to: The new song position.
    ///   - localPlaylistId: The ID of the local playlist.
    /// - Returns: True or False.
    func move(songAtPosition from: Int, toPosition to: Int, localPlaylistId: Int) -> Bool {
        guard from != to, to >= 0 else { return false }
        
        do {
            return try pool.write { db in
                // Select the playlist to get the count as it's O(1) instead of MAX(position) which is O(N)
                guard let playlist = try LocalPlaylist.fetchOne(db, key: localPlaylistId), to < playlist.songCount else { return false }
                
                // Get the song we're moving
                guard let song = try LocalPlaylist.fetchSong(db, playlistId: localPlaylistId, position: from) else { return false }
                
                // Remove the song from the playlist
                let removeSongSql: SQL = """
                    DELETE FROM localPlaylistSong
                    WHERE localPlaylistId = \(localPlaylistId) AND position = \(from)
                    """
                try db.execute(literal: removeSongSql)
                
                // Update song positions
                if to < from {
                    let positionSql: SQL = """
                        UPDATE localPlaylistSong
                        SET position = position + 1
                        WHERE localPlaylistId = \(localPlaylistId) AND position >= \(to) AND position < \(from)
                        """
                    try db.execute(literal: positionSql)
                } else {
                    let positionSql: SQL = """
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
    
    @discardableResult
    func remove(songsAtPositions positions: [Int], localPlaylistId: Int) -> Bool {
        do {
            return try pool.write { db in
                // Select the playlist to get the count as it's O(1) instead of MAX(position) which is O(N)
                guard var playlist = try LocalPlaylist.fetchOne(db, key: localPlaylistId) else { return false }
                
                // Filter the valid positions
                let validPositions = positions.filter { $0 >= 0 && $0 < playlist.songCount }
                
                // Remove the songs from the playlist
                let removeSongsSql: SQL = """
                    DELETE FROM localPlaylistSong
                    WHERE localPlaylistId = \(localPlaylistId) AND position IN \(validPositions)
                    """
                try db.execute(literal: removeSongsSql)
                
                // Update song positions
                let songRequestSql: SQL = """
                    SELECT serverId, songId
                    FROM localPlaylistSong
                    WHERE localPlaylistId = \(localPlaylistId)
                    ORDER BY position ASC
                    """
                let songTuples = try SQLRequest<Row>(literal: songRequestSql).fetchAll(db).map({ ($0[0] as Int, $0[1] as String) })
                for (index, tuple) in songTuples.enumerated() {
                    let updateSql: SQL = """
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
