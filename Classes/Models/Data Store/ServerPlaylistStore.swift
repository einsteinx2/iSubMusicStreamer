//
//  ServerPlaylistStore.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjackSwift

extension ServerPlaylist: FetchableRecord, PersistableRecord {
    struct Table {
        static let serverPlaylistSong = "serverPlaylistSong"
    }
    
    enum Column: String, ColumnExpression {
        case serverId, id, coverArtId, name, comment, songCount, duration, owner, isPublic, createdDate, changedDate, loadedSongCount
    }
    enum RelatedColumn: String, ColumnExpression {
        case serverPlaylistId, songId, position
    }
    
    static func createInitialSchema(_ db: Database) throws {
        try db.create(table: ServerPlaylist.databaseTableName) { t in
            t.column(Column.serverId, .integer).notNull()
            t.column(Column.id, .integer).notNull()
            t.column(Column.coverArtId, .text)
            t.column(Column.name, .text).notNull()
            t.column(Column.comment, .text)
            t.column(Column.songCount, .integer).notNull()
            t.column(Column.duration, .integer).notNull()
            t.column(Column.owner, .text).notNull()
            t.column(Column.isPublic, .boolean).notNull()
            t.column(Column.createdDate, .datetime)
            t.column(Column.changedDate, .datetime)
            t.column(Column.loadedSongCount, .integer).notNull()
            t.primaryKey([Column.serverId, Column.id])
        }
        
        try db.create(table: Table.serverPlaylistSong) { t in
            t.column(Column.serverId, .integer).notNull()
            t.column(RelatedColumn.serverPlaylistId, .integer).notNull()
            t.column(RelatedColumn.position, .integer).notNull()
            t.column(RelatedColumn.songId, .integer).notNull()
        }
        try db.create(indexOn: Table.serverPlaylistSong, columns: [Column.serverId, RelatedColumn.serverPlaylistId, RelatedColumn.position])
    }
    
    static func fetchSong(_ db: Database, serverId: Int, playlistId: Int, position: Int) throws -> Song? {
        let sql: SQLLiteral = """
            SELECT *
            FROM \(Song.self)
            JOIN serverPlaylistSong
            ON \(Song.self).serverId = serverPlaylistSong.serverId
                AND \(Song.self).id = serverPlaylistSong.songId
            WHERE serverPlaylistSong.serverId = \(serverId)
                AND serverPlaylistSong.serverPlaylistId = \(playlistId)
                AND serverPlaylistSong.position = \(position)
            LIMIT 1
            """
        return try SQLRequest<Song>(literal: sql).fetchOne(db)
    }
    
    static func insertSong(_ db: Database, song: Song, position: Int, serverId: Int, playlistId: Int) throws {
        let sql: SQLLiteral = """
            INSERT INTO serverPlaylistSong (serverId, serverPlaylistId, position, songId)
            VALUES (\(serverId), \(playlistId), \(position), \(song.id))
            """
        try db.execute(literal: sql)
    }
}

extension Store {
    // Checks if all songs from the playlist are in the database
    func isServerPlaylistSongsCached(serverId: Int, id: Int) -> Bool {
        do {
            return try pool.read { db in
                // If the server playlist itself isn't cached, then assume it's songs aren't cached
                guard let serverPlaylist = try ServerPlaylist.filter(literal: "serverId = \(serverId) AND id = \(id)").fetchOne(db) else {
                    return false
                }
                
                // Check if the songIds count matches the number of songs this album should have
                let sql: SQLLiteral = """
                    SELECT songId
                    FROM serverPlaylistSong
                    WHERE serverId = \(serverId) AND serverPlaylistId = \(id)
                    """
                let songIdsCount = try SQLRequest<Int>(literal: sql).fetchCount(db)
                return serverPlaylist.songCount == songIdsCount
            }
        } catch {
            DDLogError("Failed to check if songs from tag album \(id) are cached for server \(serverId): \(error)")
            return false
        }
    }
    
    func serverPlaylistsCount() -> Int? {
        do {
            return try pool.read { db in
                try ServerPlaylist.fetchCount(db)
            }
        } catch {
            DDLogError("Failed to select count of server playlists: \(error)")
            return nil
        }
    }
    
    func serverPlaylistsCount(serverId: Int) -> Int? {
        do {
            return try pool.read { db in
                try ServerPlaylist.filter(literal: "serverId = \(serverId)").fetchCount(db)
            }
        } catch {
            DDLogError("Failed to select count of server playlists for server \(serverId): \(error)")
            return nil
        }
    }
    
    func serverPlaylists() -> [ServerPlaylist] {
        do {
            return try pool.read { db in
                try ServerPlaylist.fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all server playlists: \(error)")
            return []
        }
    }
    
    func serverPlaylists(serverId: Int) -> [ServerPlaylist] {
        do {
            return try pool.read { db in
                try ServerPlaylist.filter(literal: "serverId = \(serverId)").fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all server playlists for server \(serverId): \(error)")
            return []
        }
    }
    
    func serverPlaylist(serverId: Int, id: Int) -> ServerPlaylist? {
        do {
            return try pool.read { db in
                try ServerPlaylist.filter(literal: "serverId = \(serverId) AND id = \(id)").fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select server playlist \(id) server \(serverId): \(error)")
            return nil
        }
    }
    
    func add(serverPlaylist: ServerPlaylist) -> Bool {
        do {
            return try pool.write { db in
                try serverPlaylist.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to insert server playlist \(serverPlaylist): \(error)")
            return false
        }
    }
    
    func clear(serverId: Int, serverPlaylistId: Int) -> Bool {
        do {
            return try pool.write { db in
                // Select the playlist to get the loaded count as it's O(1) instead of MAX(position) which is O(N)
                guard var playlist = try ServerPlaylist.filter(literal: "serverId = \(serverId) AND id = \(serverPlaylistId)").fetchOne(db) else { return false }
                
                try db.execute(literal: "DELETE FROM serverPlaylistSong WHERE serverId = \(serverId) AND serverPlaylistId = \(serverPlaylistId)")
                
                // Update the playlist count
                playlist.loadedSongCount = 0
                try playlist.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to clear server playlist \(serverPlaylistId) server \(serverId): \(error)")
            return false
        }
    }
    
    func clear(serverPlaylist: ServerPlaylist) -> Bool {
        return clear(serverId: serverPlaylist.serverId, serverPlaylistId: serverPlaylist.id)
    }
    
    func delete(serverId: Int, serverPlaylistId: Int) -> Bool {
        do {
            return try pool.write { db in
                try db.execute(literal: "DELETE FROM \(ServerPlaylist.self) WHERE serverId = \(serverId) AND id = \(serverPlaylistId)")
                try db.execute(literal: "DELETE FROM serverPlaylistSong WHERE serverId = \(serverId) AND serverPlaylistId = \(serverPlaylistId)")
                return true
            }
        } catch {
            DDLogError("Failed to delete server playlist \(serverPlaylistId) server \(serverId): \(error)")
            return false
        }
    }
    
    func delete(serverPlaylist: ServerPlaylist) -> Bool {
        return delete(serverId: serverPlaylist.serverId, serverPlaylistId: serverPlaylist.id)
    }
    
    func song(serverId: Int, serverPlaylistId: Int, position: Int) -> Song? {
        do {
            return try pool.read { db in
                return try ServerPlaylist.fetchSong(db, serverId: serverId, playlistId: serverPlaylistId, position: position)
            }
        } catch {
            DDLogError("Failed to select song at position \(position) in server playlist \(serverPlaylistId) server \(serverId): \(error)")
            return nil
        }
    }
    
    func song(serverPlaylist: ServerPlaylist, position: Int) -> Song? {
        return song(serverId: serverPlaylist.serverId, serverPlaylistId: serverPlaylist.id, position: position)
    }
    
    func add(song: Song, serverId: Int, serverPlaylistId: Int) -> Bool {
        do {
            return try pool.write { db in
                // Select the playlist to get the loaded count as it's O(1) instead of MAX(position) which is O(N)
                guard var playlist = try ServerPlaylist.filter(literal: "serverId = \(serverId) AND id = \(serverPlaylistId)").fetchOne(db) else { return false }
                    
                // Add the song to the playlist
                try ServerPlaylist.insertSong(db, song: song, position: playlist.loadedSongCount, serverId: serverId, playlistId: serverPlaylistId)
                
                // Update the playlist count
                playlist.loadedSongCount += 1
                try playlist.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to add song to end of server playlist \(serverPlaylistId) server \(serverId): \(error)")
            return false
        }
    }
    
    func songIds(serverId: Int, serverPlaylistId: Int) -> [String] {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT songId
                    FROM serverPlaylistSong
                    WHERE serverId = \(serverId) AND serverPlaylistId = \(serverPlaylistId)
                    ORDER BY position ASC
                    """
                return try SQLRequest<String>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select songIds in server playlist \(serverPlaylistId) server \(serverId): \(error)")
            return []
        }
    }
    
    // TODO: Optimize this
    func queueServerPlaylist(serverId: Int, serverPlaylistId: Int) -> Bool {
        let songIds = self.songIds(serverId: serverId, serverPlaylistId: serverPlaylistId)
        return queue(songIds: songIds, serverId: serverId)
    }
    
    // TODO: Optimize this
    func playSongFromServerPlaylist(serverId: Int, serverPlaylistId: Int, position: Int) -> Song? {
        let songIds = self.songIds(serverId: serverId, serverPlaylistId: serverPlaylistId)
        return playSong(position: position, songIds: songIds, serverId: serverId)
    }
}
