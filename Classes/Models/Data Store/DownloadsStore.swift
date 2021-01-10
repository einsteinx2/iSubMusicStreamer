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
}

extension DownloadedSongPathComponent: FetchableRecord, PersistableRecord {
    enum Column: String, ColumnExpression {
        case serverId, songId, level, pathComponent
    }
    
    static func createInitialSchema(_ db: Database) throws {
        try db.create(table: DownloadedSongPathComponent.databaseTableName) { t in
            t.column(Column.serverId, .integer).notNull()
            t.column(Column.songId, .integer).notNull()
            t.column(Column.level, .integer).notNull()
            t.column(Column.pathComponent, .text).notNull()
        }
        try db.create(indexOn: DownloadedSongPathComponent.databaseTableName, columns: [Column.level, Column.pathComponent])
    }
}

@objc extension Store {
    func downloadedSong(serverId: Int, songId: Int) -> DownloadedSong? {
        do {
            return try pool.read { db in
                try DownloadedSong.filter(literal: "serverId = \(serverId) AND songId = \(songId)").fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select downloaded song \(songId) for server \(serverId): \(error)")
            return nil
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
    
    func add(downloadedSongPathComponents downloadedSong: DownloadedSong) -> Bool {
        do {
            return try pool.write { db in
                let serverId = downloadedSong.serverId
                let songId = downloadedSong.songId
                let pathComponents = NSString(string: downloadedSong.path).pathComponents
                for (level, pathComponent) in pathComponents.enumerated() {
                    let record = DownloadedSongPathComponent(serverId: serverId, songId: songId, level: level, pathComponent: pathComponent)
                    try record.save(db)
                }
                return true
            }
        } catch {
            DDLogError("Failed to insert downloaded song path components \(downloadedSong): \(error)")
            return false
        }
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
