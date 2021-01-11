//
//  DownloadsStore.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjackSwift

extension DownloadedSong: FetchableRecord, PersistableRecord {
    struct Table {
        static let downloadQueue = "downloadQueue"
    }
    
    enum Column: String, ColumnExpression {
        case serverId, songId, path, isFinished, isPinned, size, cachedDate, playedDate
    }
    
    static func createInitialSchema(_ db: Database) throws {
        try db.create(table: DownloadedSong.databaseTableName) { t in
            t.column(Column.serverId, .integer).notNull()
            t.column(Column.songId, .integer).notNull()
            t.column(Column.path, .integer).notNull()
            t.column(Column.isFinished, .boolean).notNull()
            t.column(Column.isPinned, .boolean).notNull()
            t.column(Column.size, .integer).notNull()
            t.column(Column.cachedDate, .datetime)
            t.column(Column.playedDate, .datetime)
            t.primaryKey([Column.serverId, Column.songId])
        }
        
        try db.create(table: Table.downloadQueue) { t in
            t.autoIncrementedPrimaryKey(GRDB.Column.rowID)
            t.column(Column.serverId, .integer).notNull()
            t.column(Column.songId, .integer).notNull()
            t.uniqueKey([Column.serverId, Column.songId])
        }
    }
    
    static func fetchOne(_ db: Database, serverId: Int, songId: Int) throws -> DownloadedSong? {
        try DownloadedSong.filter(literal: "serverId = \(serverId) AND songId = \(songId)").fetchOne(db)
    }
}

extension DownloadedSongPathComponent: FetchableRecord, PersistableRecord {
    enum Column: String, ColumnExpression {
        case level, maxLevel, pathComponent, parentPathComponent, serverId, songId
    }
    
    static func createInitialSchema(_ db: Database) throws {
        try db.create(table: DownloadedSongPathComponent.databaseTableName) { t in
            t.column(Column.serverId, .integer).notNull()
            t.column(Column.level, .integer).notNull()
            t.column(Column.maxLevel, .integer).notNull()
            t.column(Column.pathComponent, .text).notNull()
            t.column(Column.parentPathComponent, .text)
            t.column(Column.songId, .integer).notNull()
        }
        // TODO: Implement correct indexes
//        try db.create(indexOn: DownloadedSongPathComponent.databaseTableName, columns: [Column.serverId, Column.songId])
//        try db.create(indexOn: DownloadedSongPathComponent.databaseTableName, columns: [Column.serverId, Column.level, Column.pathComponent])
//        try db.create(indexOn: DownloadedSongPathComponent.databaseTableName, columns: [Column.level, Column.pathComponent])
//        try db.create(indexOn: DownloadedSongPathComponent.databaseTableName, columns: [Column.level, Column.maxLevel, Column.pathComponent])
    }
    
    static func addDownloadedSongPathComponents(_ db: Database, downloadedSong: DownloadedSong) throws {
        let serverId = downloadedSong.serverId
        let songId = downloadedSong.songId
        let pathComponents = NSString(string: downloadedSong.path).pathComponents
        let maxLevel = pathComponents.count - 1
        var parentPathComponent: String?
        for (level, pathComponent) in pathComponents.enumerated() {
            let record = DownloadedSongPathComponent(level: level, maxLevel: maxLevel, pathComponent: pathComponent, parentPathComponent: parentPathComponent, serverId: serverId, songId: songId)
            try record.save(db)
            parentPathComponent = record.pathComponent
        }
    }
}

extension DownloadedFolderArtist: FetchableRecord, PersistableRecord {
}

extension DownloadedFolderAlbum: FetchableRecord, PersistableRecord {
}

@objc extension Store {
//    func downloadedFolderArtists() -> [DownloadedFolderArtist] {
//        do {
//            return try pool.read { db in
//                let sql: SQLLiteral = """
//                    SELECT serverId, pathComponent AS name
//                    FROM \(DownloadedSongPathComponent.self)
//                    WHERE level = 0
//                    GROUP BY pathComponent
//                    """
//                return try SQLRequest<DownloadedFolderArtist>(literal: sql).fetchAll(db)
//            }
//        } catch {
//            DDLogError("Failed to select all downloaded folder artists: \(error)")
//            return []
//        }
//    }
    
    func downloadedFolderArtists(serverId: Int) -> [DownloadedFolderArtist] {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT serverId, pathComponent AS name
                    FROM \(DownloadedSongPathComponent.self)
                    WHERE serverId = \(serverId) AND level = 0
                    GROUP BY pathComponent
                    """
                return try SQLRequest<DownloadedFolderArtist>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all downloaded folder artists for server \(serverId): \(error)")
            return []
        }
    }
    
//    func downloadedFolderAlbums(level: Int) -> [DownloadedFolderArtist] {
//        do {
//            return try pool.read { db in
//                let sql: SQLLiteral = """
//                    SELECT serverId, level, pathComponent AS name
//                    FROM \(DownloadedSongPathComponent.self)
//                    WHERE serverId = \(serverId) AND level = \(level)
//                    GROUP BY pathComponent
//                    """
//                return try SQLRequest<DownloadedFolderArtist>(literal: sql).fetchAll(db)
//            }
//        } catch {
//            DDLogError("Failed to select all downloaded folder artists for server \(serverId): \(error)")
//            return []
//        }
//    }
    
    func downloadedFolderAlbums(serverId: Int, level: Int, parentPathComponent: String) -> [DownloadedFolderAlbum] {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT \(DownloadedSongPathComponent.self).serverId,
                        \(DownloadedSongPathComponent.self).level,
                        \(DownloadedSongPathComponent.self).pathComponent AS name,
                        \(Song.self).coverArtId
                    FROM \(DownloadedSongPathComponent.self)
                    JOIN \(Song.self)
                    ON \(DownloadedSongPathComponent.self).serverId = \(Song.self).serverId
                        AND \(DownloadedSongPathComponent.self).songId = \(Song.self).id
                    WHERE \(DownloadedSongPathComponent.self).serverId = \(serverId)
                        AND \(DownloadedSongPathComponent.self).level = \(level)
                        AND \(DownloadedSongPathComponent.self).maxLevel != \(level)
                        AND \(DownloadedSongPathComponent.self).parentPathComponent = \(parentPathComponent)
                    GROUP BY pathComponent
                    """
                return try SQLRequest<DownloadedFolderAlbum>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all downloaded folder albums for server \(serverId) level \(level) parent \(parentPathComponent): \(error)")
            return []
        }
    }
    
    func downloadedSongs(serverId: Int, level: Int, parentPathComponent: String) -> [DownloadedSong] {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM \(DownloadedSong.self)
                    JOIN \(DownloadedSongPathComponent.self)
                    ON \(DownloadedSong.self).serverId = \(DownloadedSongPathComponent.self).serverId
                    AND \(DownloadedSong.self).songID = \(DownloadedSongPathComponent.self).songId
                    WHERE \(DownloadedSongPathComponent.self).serverId = \(serverId)
                    AND \(DownloadedSongPathComponent.self).level = \(level)
                    AND \(DownloadedSongPathComponent.self).maxLevel = \(level)
                    AND \(DownloadedSongPathComponent.self).parentPathComponent = \(parentPathComponent)
                    """
                return try SQLRequest<DownloadedSong>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select downloaded songs at level \(level) for server \(serverId): \(error)")
            return []
        }
    }
    
    func downloadedSong(serverId: Int, songId: Int) -> DownloadedSong? {
        do {
            return try pool.read { db in
                try DownloadedSong.fetchOne(db, serverId: serverId, songId: songId)
            }
        } catch {
            DDLogError("Failed to select downloaded song \(songId) for server \(serverId): \(error)")
            return nil
        }
    }
    
    func deleteDownloadedSong(serverId: Int, songId: Int) -> Bool {
        do {
            return try pool.write { db in
                try db.execute(literal: "DELETE FROM \(DownloadedSong.self) WHERE serverId = \(serverId) AND songId = \(songId)")
                try db.execute(literal: "DELETE FROM \(DownloadedSongPathComponent.self) WHERE serverId = \(serverId) AND songId = \(songId)")
                return true
            }
        } catch {
            DDLogError("Failed to delete downloaded song record for server \(serverId) and song \(songId): \(error)")
            return false
        }
    }
    
    func add(downloadedSong: DownloadedSong) -> Bool {
        do {
            return try pool.write { db in
                try downloadedSong.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to insert downloaded song \(downloadedSong): \(error)")
            return false
        }
    }
    
    func update(playedDate: Date, serverId: Int, songId: Int) -> Bool {
        do {
            return try pool.write { db in
                let sql: SQLLiteral = """
                    UPDATE \(DownloadedSong.self)
                    SET playedDate = \(playedDate)
                    WHERE serverId = \(serverId) AND songId = \(songId)
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to update played date \(playedDate) for song \(songId) server \(serverId): \(error)")
            return false
        }
    }
    
    func update(playedDate: Date, song: Song) -> Bool {
        return update(playedDate: playedDate, serverId: song.serverId, songId: song.id)
    }
    
    func update(downloadFinished: Bool, serverId: Int, songId: Int) -> Bool {
        do {
            return try pool.write { db in
                let sql: SQLLiteral = """
                    UPDATE \(DownloadedSong.self)
                    SET isFinished = \(downloadFinished)
                    WHERE serverId = \(serverId) AND songId = \(songId)
                    """
                try db.execute(literal: sql)
                
                // If the download finished, add the path components
                if downloadFinished, let downloadedSong = try DownloadedSong.fetchOne(db, serverId: serverId, songId: songId) {
                    try DownloadedSongPathComponent.addDownloadedSongPathComponents(db, downloadedSong: downloadedSong)
                }
                return true
            }
        } catch {
            DDLogError("Failed to update download finished \(downloadFinished) for song \(songId) server \(serverId): \(error)")
            return false
        }
    }
    
    func update(downloadFinished: Bool, song: Song) -> Bool {
        return update(downloadFinished: downloadFinished, serverId: song.serverId, songId: song.id)
    }
    
    func update(isPinned: Bool, serverId: Int, songId: Int) -> Bool {
        do {
            return try pool.write { db in
                let sql: SQLLiteral = """
                    UPDATE \(DownloadedSong.self)
                    SET isPinned = \(isPinned)
                    WHERE serverId = \(serverId) AND songId = \(songId)
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to update download is pinned \(isPinned) for song \(songId) server \(serverId): \(error)")
            return false
        }
    }
    
    func update(isPinned: Bool, song: Song) -> Bool {
        return update(isPinned: isPinned, serverId: song.serverId, songId: song.id)
    }
    
    func isDownloadFinished(serverId: Int, songId: Int) -> Bool {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT isFinished
                    FROM \(DownloadedSong.self)
                    WHERE serverId = \(serverId) AND songId = \(songId)
                    """
                return try SQLRequest<Bool>(literal: sql).fetchOne(db) ?? false
            }
        } catch {
            DDLogError("Failed to select download finished for song \(songId) server \(serverId): \(error)")
            return false
        }
    }
    
    func isDownloadFinished(song: Song) -> Bool {
        return isDownloadFinished(serverId: song.serverId, songId: song.id)
    }
    
    func addToDownloadQueue(serverId: Int, songId: Int) -> Bool {
        do {
            return try pool.write { db in
                let sql: SQLLiteral = """
                    INSERT OR IGNORE INTO downloadQueue (serverId, songId)
                    VALUES (\(serverId), \(songId)
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to add song \(songId) server \(serverId) to download queue: \(error)")
            return false
        }
    }
    
    func addToDownloadQueue(song: Song) -> Bool {
        return addToDownloadQueue(serverId: song.serverId, songId: song.id)
    }
    
    func addToDownloadQueue(serverId: Int, songIds: [Int]) -> Bool {
        do {
            return try pool.write { db in
                for songId in songIds {
                    let sql: SQLLiteral = """
                        INSERT OR IGNORE INTO downloadQueue (serverId, songId)
                        VALUES (\(serverId), \(songId)
                        """
                    try db.execute(literal: sql)
                }
                return true
            }
        } catch {
            DDLogError("Failed to add songIds \(songIds) server \(serverId) to download queue: \(error)")
            return false
        }
    }
    
    func removeFromDownloadQueue(serverId: Int, songId: Int) -> Bool {
        do {
            return try pool.write { db in
                let sql: SQLLiteral = """
                    DELETE FROM downloadQueue
                    WHERE serverId = (\(serverId) AND songId = \(songId)
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to remove song \(songId) server \(serverId) from download queue: \(error)")
            return false
        }
    }
    
    func removeFromDownloadQueue(song: Song) -> Bool {
        return removeFromDownloadQueue(serverId: song.serverId, songId: song.id)
    }
    
    func firstSongInDownloadQueue() -> Song? {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM \(Song.self)
                    JOIN downloadQueue
                    ON \(Song.self).serverId = downloadQueue.serverId AND \(Song.self).id = downloadQueue.songId
                    ORDER BY downloadQueue.rowid ASC
                    LIMIT 1
                    """
                return try SQLRequest<Song>(literal: sql).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select first song in download queue: \(error)")
            return nil
        }
    }
}
