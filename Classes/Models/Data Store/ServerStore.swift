//
//  ServerStore.swift
//  iSub
//
//  Created by Benjamin Baron on 1/8/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjackSwift

extension Server: FetchableRecord, PersistableRecord {
    enum Column: String, ColumnExpression {
        case id, type, url, username, password, path, isVideoSupported, isNewSearchSupported, isTagSearchSupported, name, isBasicAuthEnabled
    }

    static func createInitialSchema(_ db: Database) throws {
        try db.create(table: Server.databaseTableName) { t in
            t.autoIncrementedPrimaryKey(Column.id).notNull()
            t.column(Column.type, .text).notNull()
            t.column(Column.url, .text).notNull()
            t.column(Column.username, .text).notNull()
            t.column(Column.password, .text).notNull()
            t.column(Column.path, .text).notNull()
            t.column(Column.isVideoSupported, .boolean).notNull()
            t.column(Column.isNewSearchSupported, .boolean).notNull()
            t.column(Column.isTagSearchSupported, .boolean).notNull()
        }
    }

    static func createLibraryContextsSchema(_ db: Database, seedBasicAuthFromGlobalSetting: Bool) throws {
        try db.alter(table: Server.databaseTableName) { t in
            t.add(column: Column.isBasicAuthEnabled.rawValue, .boolean).notNull().defaults(to: false)
            t.add(column: Column.name.rawValue, .text)
        }
        // The flag used to be one app-wide setting; carry its value onto the servers
        // that existed when it was on
        if seedBasicAuthFromGlobalSetting {
            try db.execute(sql: "UPDATE server SET isBasicAuthEnabled = 1")
        }
    }
}

extension Store {
    func nextServerId() -> Int {
        do {
            return try pool.read { db in
                let maxId = try SQLRequest<Int>(literal: "SELECT MAX(id) FROM \(Server.self)").fetchOne(db) ?? 0
                return maxId + 1
            }
        } catch {
            DDLogError("Failed to select next server ID: \(error)")
            return -1
        }
    }
    
    func servers() -> [Server] {
        do {
            return try pool.read { db in
                try Server.fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all servers: \(error)")
            return []
        }
    }

    func server(id: Int) -> Server? {
        do {
            return try pool.read { db in
                try Server.fetchOne(db, key: id)
            }
        } catch {
            DDLogError("Failed to select servers \(id): \(error)")
            return nil
        }
    }
    
    func add(server: Server) -> Bool {
        do {
            return try pool.write { db in
                try server.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to insert server \(server): \(error)")
            return false
        }
    }
    
    // Deletes the server row plus every row scoped to it across all tables — songs,
    // browse caches, downloads, server playlists, local playlist memberships, bookmarks
    // (including their snapshot playlists), media folders, and cover/artist art — then
    // removes its downloaded files from disk.
    @discardableResult
    func deleteServer(id: Int) -> Bool {
        // Capture the server's downloads location before its row is deleted
        let downloadsURL = server(id: id).map { FileSystem.downloadsDirectory.appendingPathComponent($0.path) }

        do {
            try pool.write { db in
                // Everything owned by this server's library CONTEXT first: its user
                // playlists and bookmarks (bookmark snapshots included) — they may
                // hold other servers' songs, so the per-song cascade below must not
                // waste work repacking playlists that are about to disappear
                let contextPlaylistIds = try SQLRequest<Int>(literal: "SELECT id FROM \(LocalPlaylist.self) WHERE contextId = \(id) AND id > \(LocalPlaylist.Default.maxDefaultId)").fetchAll(db)
                for playlistId in contextPlaylistIds {
                    try LocalPlaylist.delete(db, id: playlistId)
                }
                try db.execute(literal: "DELETE FROM \(Bookmark.self) WHERE contextId = \(id)")

                // Other contexts' bookmarks that point at this server's songs, and
                // their snapshot playlists
                let bookmarkPlaylistIds = try SQLRequest<Int>(literal: "SELECT localPlaylistId FROM \(Bookmark.self) WHERE songServerId = \(id)").fetchAll(db)
                for playlistId in bookmarkPlaylistIds {
                    try LocalPlaylist.delete(db, id: playlistId)
                }
                try db.execute(literal: "DELETE FROM \(Bookmark.self) WHERE songServerId = \(id)")

                // Remove this server's songs from the remaining local playlists (including
                // the play queues), then close the position gaps and fix the song counts
                let affectedPlaylistIds = try SQLRequest<Int>(literal: "SELECT DISTINCT localPlaylistId FROM localPlaylistSong WHERE serverId = \(id)").fetchAll(db)
                try db.execute(literal: "DELETE FROM localPlaylistSong WHERE serverId = \(id)")
                for playlistId in affectedPlaylistIds {
                    let repackSql: SQL = """
                        UPDATE localPlaylistSong
                        SET position = (
                            SELECT COUNT(*)
                            FROM localPlaylistSong AS other
                            WHERE other.localPlaylistId = \(playlistId) AND other.position < localPlaylistSong.position
                        )
                        WHERE localPlaylistId = \(playlistId)
                        """
                    try db.execute(literal: repackSql)
                    let countSql: SQL = """
                        UPDATE \(LocalPlaylist.self)
                        SET songCount = (SELECT COUNT(*) FROM localPlaylistSong WHERE localPlaylistId = \(playlistId))
                        WHERE id = \(playlistId)
                        """
                    try db.execute(literal: countSql)
                }

                // Every remaining serverId-scoped table
                let tables = [
                    Song.databaseTableName,
                    TagArtist.databaseTableName,
                    TagArtist.Table.tagArtistList,
                    TagArtist.Table.tagArtistTableSection,
                    TagArtist.Table.tagArtistListMetadata,
                    TagAlbum.databaseTableName,
                    TagAlbum.Table.tagSongList,
                    FolderArtist.databaseTableName,
                    FolderArtist.Table.folderArtistList,
                    FolderArtist.Table.folderArtistTableSection,
                    FolderArtist.Table.folderArtistListMetadata,
                    FolderAlbum.databaseTableName,
                    FolderAlbum.Table.folderAlbumList,
                    FolderAlbum.Table.folderSongList,
                    FolderMetadata.databaseTableName,
                    MediaFolder.databaseTableName,
                    ServerPlaylist.databaseTableName,
                    ServerPlaylist.Table.serverPlaylistSong,
                    CoverArt.databaseTableName,
                    ArtistArt.databaseTableName,
                    DownloadedSong.databaseTableName,
                    DownloadedSong.Table.downloadQueue,
                    DownloadedSongPathComponent.databaseTableName,
                ]
                for table in tables {
                    try db.execute(sql: "DELETE FROM \(table) WHERE serverId = ?", arguments: [id])
                }

                // This server's own queue snapshot
                try db.execute(sql: "DELETE FROM \(ContextQueue.Table.contextQueueState) WHERE contextId = ?", arguments: [id])
                try db.execute(sql: "DELETE FROM \(ContextQueue.Table.contextQueueSong) WHERE contextId = ?", arguments: [id])

                // Other contexts' snapshots holding this server's songs: decrement
                // their saved indexes by the rows about to vanish below them, then
                // remove the rows and repack the positions (mirrors the live-queue
                // repack above)
                try db.execute(sql: """
                    UPDATE \(ContextQueue.Table.contextQueueState) SET
                        normalIndex = MAX(0, normalIndex - (
                            SELECT COUNT(*) FROM \(ContextQueue.Table.contextQueueSong) s
                            WHERE s.contextId = \(ContextQueue.Table.contextQueueState).contextId
                              AND s.queueKind = 0 AND s.serverId = ?
                              AND s.position < \(ContextQueue.Table.contextQueueState).normalIndex)),
                        shuffleIndex = MAX(0, shuffleIndex - (
                            SELECT COUNT(*) FROM \(ContextQueue.Table.contextQueueSong) s
                            WHERE s.contextId = \(ContextQueue.Table.contextQueueState).contextId
                              AND s.queueKind = 1 AND s.serverId = ?
                              AND s.position < \(ContextQueue.Table.contextQueueState).shuffleIndex))
                    """, arguments: [id, id])
                try db.execute(sql: "DELETE FROM \(ContextQueue.Table.contextQueueSong) WHERE serverId = ?", arguments: [id])
                try db.execute(sql: """
                    UPDATE \(ContextQueue.Table.contextQueueSong) SET position = (
                        SELECT COUNT(*) FROM \(ContextQueue.Table.contextQueueSong) other
                        WHERE other.contextId = \(ContextQueue.Table.contextQueueSong).contextId
                          AND other.queueKind = \(ContextQueue.Table.contextQueueSong).queueKind
                          AND other.position < \(ContextQueue.Table.contextQueueSong).position)
                    """)

                // If the marker still points at this context, the follow-up
                // switchContext sets it properly
                try db.execute(sql: "UPDATE \(ContextQueue.Table.activeQueueContext) SET contextId = ? WHERE contextId = ?",
                               arguments: [LibraryContext.noContextId, id])

                try db.execute(literal: "DELETE FROM \(Server.self) WHERE id = \(id)")
            }
        } catch {
            DDLogError("Failed to delete server \(id): \(error)")
            return false
        }

        // Remove the server's downloaded files once the records are gone
        if let downloadsURL, FileManager.default.fileExists(atPath: downloadsURL.path) {
            do {
                try FileManager.default.removeItem(at: downloadsURL)
            } catch {
                DDLogError("Failed to delete the downloaded files for server \(id): \(error)")
            }
        }
        return true
    }
}
