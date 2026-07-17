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
        case id, name, songCount, isBookmark, createdDate, contextId
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

        // Create the default playlists with schema-frozen SQL, not model saves: the
        // model encodes every CURRENT property, and this migration must keep producing
        // the original columns even as later migrations grow the table
        let defaultPlaylists = [(LocalPlaylist.Default.playQueueId, "Play Queue"),
                                (LocalPlaylist.Default.shuffleQueueId, "Shuffle Queue"),
                                (LocalPlaylist.Default.jukeboxPlayQueueId, "Jukebox Play Queue"),
                                (LocalPlaylist.Default.jukeboxShuffleQueueId, "Jukebox Shuffle Queue")]
        for (id, name) in defaultPlaylists {
            try db.execute(sql: "INSERT INTO localPlaylist (id, name, songCount, isBookmark, createdDate) VALUES (?, ?, 0, 0, ?)",
                           arguments: [id, name, Date()])
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
    
    static func createLibraryContextsSchema(_ db: Database, legacyContextId: Int) throws {
        try db.alter(table: LocalPlaylist.databaseTableName) { t in
            t.add(column: Column.contextId.rawValue, .integer).notNull().defaults(to: LibraryContext.noContextId)
        }
        // The reserved queue rows (1-4) stay context-free; user playlists and bookmark
        // snapshots belong to the last active server (or the migration fallback)
        try db.execute(literal: "UPDATE \(LocalPlaylist.self) SET contextId = \(legacyContextId) WHERE id > \(Default.maxDefaultId)")
        try db.create(indexOn: LocalPlaylist.databaseTableName, columns: [Column.contextId, Column.isBookmark])
    }

    static func fetchSongs(_ db: Database, playlistId: Int) throws -> [Song] {
        // ORDER BY position matters: without it rows come back in rowid order, which
        // diverges from the playlist order after any move (Store.move deletes and
        // re-inserts rows) — jukebox mode mirrors this list to the server, where
        // index-based skips would then target the wrong song
        let sql: SQL = """
            SELECT *
            FROM \(Song.self)
            JOIN localPlaylistSong
            ON \(Song.self).serverId = localPlaylistSong.serverId AND \(Song.self).id = localPlaylistSong.songId
            WHERE localPlaylistSong.localPlaylistId = \(playlistId)
            ORDER BY localPlaylistSong.position ASC
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

// Jukebox mode: the queue functions write to the jukebox play queue playlists (see
// queuePlaylistIds). Starting playback lives in PlaybackCoordinator; this store owns
// only the persistence halves (clearAndQueue, fillPlayQueue).
extension Store {
    private var settings: SavedSettings { Resolver.resolve() }
    private var playQueue: PlayQueue { Resolver.resolve() }

    // The library context that display queries scope to by default (0 while the
    // Combined Library is active). In tests with no active context this is -1,
    // matching rows created without an explicit context.
    var activeContextId: Int { settings.activeContextId }

    var nextLocalPlaylistId: Int? {
        do {
            return try pool.read { db in
                try nextLocalPlaylistId(db)
            }
        } catch {
            DDLogError("Failed to select next local playlist ID: \(error)")
            return nil
        }
    }

    // In-transaction variant: database access is not reentrant, so callers already
    // inside pool.write must use this with their transaction's db handle
    func nextLocalPlaylistId(_ db: Database) throws -> Int? {
        if let maxId = try SQLRequest<Int>(literal: "SELECT MAX(id) FROM \(LocalPlaylist.self)").fetchOne(db) {
            return maxId + 1
        }
        return nil
    }
    
    func localPlaylistsCount(isBookmark: Bool = false, contextId: Int? = nil) -> Int? {
        let contextId = contextId ?? activeContextId
        do {
            return try pool.read { db in
                try LocalPlaylist.filter(literal: "id > \(LocalPlaylist.Default.maxDefaultId) AND isBookmark = \(isBookmark) AND contextId = \(contextId)").fetchCount(db)
            }
        } catch {
            DDLogError("Failed to select count of local playlists, isBookmark \(isBookmark): \(error)")
            return nil
        }
    }

    func localPlaylists(isBookmark: Bool = false, contextId: Int? = nil) -> [LocalPlaylist] {
        let contextId = contextId ?? activeContextId
        do {
            return try pool.read { db in
                try LocalPlaylist.filter(literal: "id > \(LocalPlaylist.Default.maxDefaultId) AND isBookmark = \(isBookmark) AND contextId = \(contextId)").fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all local playlists: \(error)")
            return []
        }
    }

    // Name-collision lookup for the save-playlist overwrite check (ignores the
    // default queues, bookmark snapshots, and other contexts' playlists)
    func localPlaylist(name: String, contextId: Int? = nil) -> LocalPlaylist? {
        let contextId = contextId ?? activeContextId
        do {
            return try pool.read { db in
                try LocalPlaylist.filter(literal: "id > \(LocalPlaylist.Default.maxDefaultId) AND isBookmark = false AND name = \(name) AND contextId = \(contextId)").fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select local playlist named \(name): \(error)")
            return nil
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
    
    // Ordered song IDs for one server's songs in a playlist (used to upload to that server)
    func songIds(localPlaylistId: Int, serverId: Int) -> [String] {
        do {
            return try pool.read { db in
                let sql: SQL = """
                    SELECT songId
                    FROM localPlaylistSong
                    WHERE localPlaylistId = \(localPlaylistId) AND serverId = \(serverId)
                    ORDER BY position ASC
                    """
                return try SQLRequest<String>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select songIds in local playlist \(localPlaylistId) for server \(serverId): \(error)")
            return []
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

    /// Queues a song parsed from a server response (e.g. the jukebox playlist),
    /// upserting its metadata into the song table in the same transaction: the song may
    /// never have been browsed locally, and every queue read JOINs the song table, so
    /// queueing only the (serverId, songId) pair would leave unresolvable rows.
    @discardableResult
    func queue(persistingSong song: Song) -> Bool {
        let (playQueueId, shuffleQueueId) = queuePlaylistIds()
        do {
            return try pool.write { db in
                try song.save(db)
                try queue(db: db, song: song, playQueueId: playQueueId, shuffleQueueId: shuffleQueueId)
                return true
            }
        } catch {
            DDLogError("Failed to queue song with metadata: \(error)")
            return false
        }
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
    
    // Copies a local playlist's songs into the live play queue (the jukebox play
    // queue in jukebox mode — the caller passes the live queue's playlist id)
    func fillPlayQueue(fromLocalPlaylistId localPlaylistId: Int, intoPlaylistId playQueueId: Int) -> Bool {
        do {
            try pool.write { db in
                // Add the songs from the playlist to the play queue
                // NOTE: This is NOT an SQL as that string interpolation doesn't work in the SELECT statement.
                //       There is no security risk directly interpolating the values here as they are integers and
                //       there is no posibility of SQL injection. Plus the values come from the code not user input.
                let sql = """
                    INSERT INTO localPlaylistSong (localPlaylistId, position, serverId, songId)
                    SELECT \(playQueueId) AS localPlaylistId, position, serverId, songId
                    FROM localPlaylistSong
                    WHERE localPlaylistId = \(localPlaylistId)
                    ORDER BY position ASC
                    """
                try db.execute(sql: sql)

                // Update the play queue's song count
                let countSql = """
                    UPDATE localPlaylist
                    SET songCount = (SELECT COUNT(*) FROM localPlaylistSong WHERE localPlaylistId = \(playQueueId))
                    WHERE id = \(playQueueId)
                    """
                try db.execute(sql: countSql)
            }
            return true
        } catch {
            DDLogError("Failed to fill the play queue from local playlist \(localPlaylistId): \(error)")
            return false
        }
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
