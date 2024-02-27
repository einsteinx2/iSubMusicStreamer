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
        case serverId, songId, path, isFinished, isPinned, size, downloadedDate, playedDate
    }
    enum RelatedColumn: String, ColumnExpression {
        case queuedDate
    }
    
    static func createInitialSchema(_ db: Database) throws {
        try db.create(table: DownloadedSong.databaseTableName) { t in
            t.column(Column.serverId, .integer).notNull()
            t.column(Column.songId, .text).notNull()
            t.column(Column.path, .integer).notNull()
            t.column(Column.isFinished, .boolean).notNull()
            t.column(Column.isPinned, .boolean).notNull()
            t.column(Column.size, .integer).notNull()
            t.column(Column.downloadedDate, .datetime)
            t.column(Column.playedDate, .datetime)
            t.primaryKey([Column.serverId, Column.songId])
        }
        
        try db.create(table: Table.downloadQueue) { t in
            t.autoIncrementedPrimaryKey(GRDB.Column.rowID)
            t.column(Column.serverId, .integer).notNull()
            t.column(Column.songId, .text).notNull()
            t.column(RelatedColumn.queuedDate, .datetime).notNull()
            t.uniqueKey([Column.serverId, Column.songId])
        }
    }
    
    static func fetchOne(_ db: Database, serverId: Int, songId: String) throws -> DownloadedSong? {
        try DownloadedSong.filter(literal: "serverId = \(serverId) AND songId = \(songId)").fetchOne(db)
    }
    
    static func downloadedSongs(serverId: Int, level: Int, parentPathComponent: String) -> SQLRequest<DownloadedSong> {
        let sql: SQLLiteral = """
            SELECT *
            FROM \(DownloadedSong.self)
            JOIN \(DownloadedSongPathComponent.self)
            ON \(DownloadedSong.self).serverId = \(DownloadedSongPathComponent.self).serverId
                AND \(DownloadedSong.self).songId = \(DownloadedSongPathComponent.self).songId
            WHERE \(DownloadedSongPathComponent.self).serverId = \(serverId)
                AND \(DownloadedSongPathComponent.self).level = \(level)
                AND \(DownloadedSongPathComponent.self).maxLevel = \(level)
                AND \(DownloadedSongPathComponent.self).parentPathComponent = \(parentPathComponent)
            ORDER BY \(DownloadedSongPathComponent.self).pathComponent COLLATE NOCASE
            """
        return SQLRequest<DownloadedSong>(literal: sql)
    }
    
    static func downloadedSongs(downloadedTagArtist: DownloadedTagArtist) -> SQLRequest<DownloadedSong> {
        let sql: SQLLiteral = """
            SELECT *
            FROM \(DownloadedSong.self)
            JOIN \(Song.self)
            ON \(DownloadedSong.self).serverId = \(Song.self).serverId
                AND \(DownloadedSong.self).songId = \(Song.self).id
            WHERE \(Song.self).serverId = \(downloadedTagArtist.serverId)
                AND \(Song.self).tagArtistId = \(downloadedTagArtist.id)
            ORDER BY \(Song.self).discNumber, \(Song.self).track, \(Song.self).title COLLATE NOCASE
            """
        return SQLRequest<DownloadedSong>(literal: sql)
    }
    
    static func downloadedSongs(downloadedTagAlbum: DownloadedTagAlbum) -> SQLRequest<DownloadedSong> {
        let sql: SQLLiteral = """
            SELECT *
            FROM \(DownloadedSong.self)
            JOIN \(Song.self)
            ON \(DownloadedSong.self).serverId = \(Song.self).serverId
                AND \(DownloadedSong.self).songId = \(Song.self).id
            WHERE \(Song.self).serverId = \(downloadedTagAlbum.serverId)
                AND \(Song.self).tagAlbumId = \(downloadedTagAlbum.id)
            ORDER BY \(Song.self).discNumber, \(Song.self).track, \(Song.self).title COLLATE NOCASE
            """
        return SQLRequest<DownloadedSong>(literal: sql)
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
    static func downloadedFolderAlbums(serverId: Int, level: Int, parentPathComponent: String) -> SQLRequest<DownloadedFolderAlbum> {
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
            GROUP BY \(DownloadedSongPathComponent.self).pathComponent
            ORDER BY \(DownloadedSongPathComponent.self).pathComponent COLLATE NOCASE
            """
        return SQLRequest<DownloadedFolderAlbum>(literal: sql)
    }
}

extension DownloadedTagArtist: FetchableRecord, PersistableRecord {
}

extension DownloadedTagAlbum: FetchableRecord, PersistableRecord {
    // TODO: Check query plan and try different join orders and group by tables to see which is fastest (i.e. TagAlbum.id vs Song.tagAlbumId)
    static func downloadedTagAlbums(downloadedTagArtist: DownloadedTagArtist) -> SQLRequest<DownloadedTagAlbum> {
        let sql: SQLLiteral = """
            SELECT \(TagAlbum.self).*
            FROM \(DownloadedSong.self)
            JOIN \(Song.self)
            ON \(DownloadedSong.self).serverId = \(Song.self).serverId
                AND \(DownloadedSong.self).songId = \(Song.self).id
            JOIN \(TagAlbum.self)
            ON \(DownloadedSong.self).serverId = \(TagAlbum.self).serverId
                AND \(Song.self).tagAlbumId = \(TagAlbum.self).id
            WHERE \(DownloadedSong.self).serverId = \(downloadedTagArtist.serverId)
                AND \(TagAlbum.self).tagArtistId = \(downloadedTagArtist.id)
            GROUP BY \(TagAlbum.self).id
            ORDER BY \(TagAlbum.self).name COLLATE NOCASE ASC
            """
        return SQLRequest<DownloadedTagAlbum>(literal: sql)
    }
}

extension Store {
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
                    ORDER BY pathComponent COLLATE NOCASE
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
                return try DownloadedFolderAlbum.downloadedFolderAlbums(serverId: serverId, level: level, parentPathComponent: parentPathComponent).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all downloaded folder albums for server \(serverId) level \(level) parent \(parentPathComponent): \(error)")
            return []
        }
    }
    
    func downloadedFolderAlbumsCount(serverId: Int, level: Int, parentPathComponent: String) -> Int? {
        do {
            return try pool.read { db in
                return try DownloadedFolderAlbum.downloadedFolderAlbums(serverId: serverId, level: level, parentPathComponent: parentPathComponent).fetchCount(db)
            }
        } catch {
            DDLogError("Failed to count all downloaded folder albums for server \(serverId) level \(level) parent \(parentPathComponent): \(error)")
            return nil
        }
    }
    
    func downloadedFolderAlbumsCount(downloadedFolderArtist: DownloadedFolderArtist) -> Int? {
        do {
            return try pool.read { db in
                try DownloadedFolderAlbum.downloadedFolderAlbums(serverId: downloadedFolderArtist.serverId, level: 1, parentPathComponent: downloadedFolderArtist.name).fetchCount(db)
            }
        } catch {
            DDLogError("Failed to count all downloaded folder albums for downloadedFolderArtist \(downloadedFolderArtist): \(error)")
            return nil
        }
    }

    func downloadedFolderAlbumsCount(downloadedFolderAlbum: DownloadedFolderAlbum) -> Int? {
        do {
            return try pool.read { db in
                try DownloadedFolderAlbum.downloadedFolderAlbums(serverId: downloadedFolderAlbum.serverId, level: downloadedFolderAlbum.level + 1, parentPathComponent: downloadedFolderAlbum.name).fetchCount(db)
            }
        } catch {
            DDLogError("Failed to count all downloaded folder albums for downloadedFolderAlbum \(downloadedFolderAlbum): \(error)")
            return nil
        }
    }
    
    // TODO: Check query plan and try different join orders and group by tables to see which is fastest (i.e. TagArtist.id vs Song.tagArtistId)
    func downloadedTagArtists(serverId: Int) -> [DownloadedTagArtist] {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT \(TagArtist.self).*
                    FROM \(DownloadedSong.self)
                    JOIN \(Song.self)
                    ON \(DownloadedSong.self).serverId = \(Song.self).serverId
                        AND \(DownloadedSong.self).songId = \(Song.self).id
                    JOIN \(TagArtist.self)
                    ON \(DownloadedSong.self).serverId = \(TagArtist.self).serverId
                        AND \(Song.self).tagArtistId = \(TagArtist.self).id
                    WHERE \(DownloadedSong.self).serverId = \(serverId)
                    GROUP BY \(TagArtist.self).id
                    ORDER BY \(TagArtist.self).name COLLATE NOCASE ASC
                    """
                return try SQLRequest<DownloadedTagArtist>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all downloaded tag artists for server \(serverId): \(error)")
            return []
        }
    }
    
    // TODO: Check query plan and try different join orders and group by tables to see which is fastest (i.e. TagAlbum.id vs Song.tagAlbumId)
    func downloadedTagAlbums(serverId: Int) -> [DownloadedTagAlbum] {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT \(TagAlbum.self).*
                    FROM \(DownloadedSong.self)
                    JOIN \(Song.self)
                    ON \(DownloadedSong.self).serverId = \(Song.self).serverId
                        AND \(DownloadedSong.self).songId = \(Song.self).id
                    JOIN \(TagAlbum.self)
                    ON \(DownloadedSong.self).serverId = \(TagAlbum.self).serverId
                        AND \(Song.self).tagAlbumId = \(TagAlbum.self).id
                    WHERE \(DownloadedSong.self).serverId = \(serverId)
                    GROUP BY \(TagAlbum.self).id
                    ORDER BY \(TagAlbum.self).name COLLATE NOCASE ASC
                    """
                return try SQLRequest<DownloadedTagAlbum>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all downloaded tag albums for server \(serverId): \(error)")
            return []
        }
    }
    
    func downloadedTagAlbums(downloadedTagArtist: DownloadedTagArtist) -> [DownloadedTagAlbum] {
        do {
            return try pool.read { db in
                return try DownloadedTagAlbum.downloadedTagAlbums(downloadedTagArtist: downloadedTagArtist).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all downloaded tag albums for artist \(downloadedTagArtist): \(error)")
            return []
        }
    }
    
    func downloadedTagAlbumsCount(downloadedTagArtist: DownloadedTagArtist) -> Int? {
        do {
            return try pool.read { db in
                return try DownloadedTagAlbum.downloadedTagAlbums(downloadedTagArtist: downloadedTagArtist).fetchCount(db)
            }
        } catch {
            DDLogError("Failed to count all downloaded tag albums for artist \(downloadedTagArtist): \(error)")
            return nil
        }
    }
    
    func song(downloadedSong: DownloadedSong) -> Song? {
        return song(serverId: downloadedSong.serverId, id: downloadedSong.songId)
    }
    
    func songsRecursive(serverId: Int, level: Int, parentPathComponent: String) -> [Song] {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM \(Song.self)
                    JOIN \(DownloadedSongPathComponent.self)
                    ON \(DownloadedSongPathComponent.self).serverId = \(Song.self).serverId
                        AND \(DownloadedSongPathComponent.self).songId = \(Song.self).id
                    WHERE \(DownloadedSongPathComponent.self).serverId = \(serverId)
                        AND  \(DownloadedSongPathComponent.self).level >= \(level)
                    GROUP BY \(Song.self).serverId, \(Song.self).id
                    """
                return try SQLRequest<Song>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all songs recursively for server \(serverId) level \(level) parent \(parentPathComponent): \(error)")
            return []
        }
    }
    
    func songsRecursive(downloadedFolderArtist: DownloadedFolderArtist) -> [Song] {
        return songsRecursive(serverId: downloadedFolderArtist.serverId, level: 0, parentPathComponent: downloadedFolderArtist.name)
    }
    
    func songsRecursive(downloadedFolderAlbum: DownloadedFolderAlbum) -> [Song] {
        return songsRecursive(serverId: downloadedFolderAlbum.serverId, level: downloadedFolderAlbum.level, parentPathComponent: downloadedFolderAlbum.name)
    }
    
    func songsRecursive(downloadedTagArtist: DownloadedTagArtist) -> [Song] {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM \(Song.self)
                    JOIN \(DownloadedSong.self)
                    ON \(DownloadedSong.self).serverId = \(Song.self).serverId
                        AND \(DownloadedSong.self).songId = \(Song.self).id
                    WHERE \(Song.self).serverId = \(downloadedTagArtist.serverId)
                        AND \(Song.self).tagArtistId = \(downloadedTagArtist.id)
                    ORDER BY \(Song.self).discNumber, \(Song.self).track, \(Song.self).title COLLATE NOCASE
                    """
                return try SQLRequest<Song>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all songs recursively for downloaded tag artist \(downloadedTagArtist): \(error)")
            return []
        }
    }
    
    func songsRecursive(downloadedTagAlbum: DownloadedTagAlbum) -> [Song] {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM \(Song.self)
                    JOIN \(DownloadedSong.self)
                    ON \(DownloadedSong.self).serverId = \(Song.self).serverId
                        AND \(DownloadedSong.self).songId = \(Song.self).id
                    WHERE \(Song.self).serverId = \(downloadedTagAlbum.serverId)
                        AND \(Song.self).tagAlbumId = \(downloadedTagAlbum.id)
                    ORDER BY \(Song.self).discNumber, \(Song.self).track, \(Song.self).title COLLATE NOCASE
                    """
                return try SQLRequest<Song>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all songs recursively for downloaded tag album \(downloadedTagAlbum): \(error)")
            return []
        }
    }
    
    func downloadedSongsCount() -> Int? {
        do {
            return try pool.read { db in
                try DownloadedSong.filter(literal: "isFinished = 1").fetchCount(db)
            }
        } catch {
            DDLogError("Failed to select downloaded songs count: \(error)")
            return nil
        }
    }
    
    func downloadedSongsCount(serverId: Int) -> Int? {
        do {
            return try pool.read { db in
                try DownloadedSong.filter(literal:"serverId = \(serverId) AND isFinished = 1").fetchCount(db)
            }
        } catch {
            DDLogError("Failed to select downloaded songs count for server \(serverId): \(error)")
            return nil
        }
    }
    
    func downloadedSongs(serverId: Int, level: Int, parentPathComponent: String) -> [DownloadedSong] {
        do {
            return try pool.read { db in
                return try DownloadedSong.downloadedSongs(serverId: serverId, level: level, parentPathComponent: parentPathComponent).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select downloaded songs at level \(level) for server \(serverId): \(error)")
            return []
        }
    }
    
    func downloadedSongsCount(serverId: Int, level: Int, parentPathComponent: String) -> Int? {
        do {
            return try pool.read { db in
                try DownloadedSong.downloadedSongs(serverId: serverId, level: level, parentPathComponent: parentPathComponent).fetchCount(db)
            }
        } catch {
            DDLogError("Failed to select downloaded songs count at level \(level) for server \(serverId): \(error)")
            return nil
        }
    }
    
    func downloadedSongsCount(downloadedFolderArtist: DownloadedFolderArtist) -> Int? {
        do {
            return try pool.read { db in
                try DownloadedSong.downloadedSongs(serverId: downloadedFolderArtist.serverId, level: 1, parentPathComponent: downloadedFolderArtist.name).fetchCount(db)
            }
        } catch {
            DDLogError("Failed to select downloaded songs count for downloaded folder artist \(downloadedFolderArtist): \(error)")
            return nil
        }
    }
    
    func downloadedSongsCount(downloadedFolderAlbum: DownloadedFolderAlbum) -> Int? {
        do {
            return try pool.read { db in
                try DownloadedSong.downloadedSongs(serverId: downloadedFolderAlbum.serverId, level: downloadedFolderAlbum.level + 1, parentPathComponent: downloadedFolderAlbum.name).fetchCount(db)
            }
        } catch {
            DDLogError("Failed to select downloaded songs count for downloaded folder album \(downloadedFolderAlbum): \(error)")
            return nil
        }
    }
    
    func downloadedSongs(downloadedTagArtist: DownloadedTagArtist) -> [DownloadedSong] {
        do {
            return try pool.read { db in
                try DownloadedSong.downloadedSongs(downloadedTagArtist: downloadedTagArtist).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select downloaded songs for downloaded tag artist \(downloadedTagArtist): \(error)")
            return []
        }
    }
    
    func downloadedSongsCount(downloadedTagArtist: DownloadedTagArtist) -> Int? {
        do {
            return try pool.read { db in
                try DownloadedSong.downloadedSongs(downloadedTagArtist: downloadedTagArtist).fetchCount(db)
            }
        } catch {
            DDLogError("Failed to count downloaded songs for downloaded tag artist \(downloadedTagArtist): \(error)")
            return nil
        }
    }
    
    func downloadedSongs(downloadedTagAlbum: DownloadedTagAlbum) -> [DownloadedSong] {
        do {
            return try pool.read { db in
                try DownloadedSong.downloadedSongs(downloadedTagAlbum: downloadedTagAlbum).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select downloaded songs for downloaded tag album \(downloadedTagAlbum): \(error)")
            return []
        }
    }
    
    func downloadedSongsCount(downloadedTagAlbum: DownloadedTagAlbum) -> Int? {
        do {
            return try pool.read { db in
                try DownloadedSong.downloadedSongs(downloadedTagAlbum: downloadedTagAlbum).fetchCount(db)
            }
        } catch {
            DDLogError("Failed to count downloaded songs for downloaded tag album \(downloadedTagAlbum): \(error)")
            return nil
        }
    }
    
    func downloadedSongs(serverId: Int) -> [DownloadedSong] {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM \(DownloadedSong.self)
                    ORDER BY \(DownloadedSong.self).downloadedDate COLLATE NOCASE DESC
                    """
                return try SQLRequest<DownloadedSong>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all downloaded songs for server \(serverId): \(error)")
            return []
        }
    }
    
    func downloadedSong(serverId: Int, songId: String) -> DownloadedSong? {
        do {
            return try pool.read { db in
                try DownloadedSong.fetchOne(db, serverId: serverId, songId: songId)
            }
        } catch {
            DDLogError("Failed to select downloaded song \(songId) for server \(serverId): \(error)")
            return nil
        }
    }
    
    // TODO: Confirm if LIMIT 1 makes any performance difference when using fetchOne()
    // NOTE: Excludes pinned songs
    func oldestDownloadedSongByDownloadedDate() -> DownloadedSong? {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM \(DownloadedSong.self)
                    WHERE isFinished = 1 AND isPinned = 0
                    ORDER BY downloadedDate ASC
                    LIMIT 1
                    """
                return try SQLRequest<DownloadedSong>(literal: sql).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select oldest downloaded song by downloaded date: \(error)")
            return nil
        }
    }
    
    // NOTE: Excludes pinned songs
    func oldestDownloadedSongByPlayedDate() -> DownloadedSong? {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM \(DownloadedSong.self)
                    WHERE isFinished = 1 AND isPinned = 0
                    ORDER BY playedDate ASC
                    LIMIT 1
                    """
                return try SQLRequest<DownloadedSong>(literal: sql).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select oldest downloaded song by played date: \(error)")
            return nil
        }
    }
    
    @discardableResult
    func deleteDownloadedSong(serverId: Int, songId: String) -> Bool {
        do {
            if let song = self.song(serverId: serverId, id: songId), FileManager.default.fileExists(atPath: song.localPath) {
                try FileManager.default.removeItem(atPath: song.localPath)
            }
            
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
    
    @discardableResult
    func deleteDownloadedSong(song: Song) -> Bool {
        return deleteDownloadedSong(serverId: song.serverId, songId: song.id)
    }
    
    @discardableResult
    func delete(downloadedSong: DownloadedSong) -> Bool {
        return deleteDownloadedSong(serverId: downloadedSong.serverId, songId: downloadedSong.songId);
    }
    
    @discardableResult
    func deleteDownloadedSongs(serverId: Int, level: Int) -> Bool {
        do {
            return try pool.write { db in
                let songIdsSql: SQLLiteral = """
                    SELECT songId
                    FROM \(DownloadedSongPathComponent.self)
                    WHERE serverId = \(serverId) AND level = \(level)
                    GROUP BY serverId, songId
                    """
                let songIds = try SQLRequest<String>(literal: songIdsSql).fetchAll(db)
                for songId in songIds {
                    // Remove song file
                    if let song = self.song(serverId: serverId, id: songId), FileManager.default.fileExists(atPath: song.localPath) {
                        try FileManager.default.removeItem(atPath: song.localPath)
                    }
                    
                    try db.execute(literal: "DELETE FROM \(DownloadedSong.self) WHERE serverId = \(serverId) AND songId = \(songId)")
                    try db.execute(literal: "DELETE FROM \(DownloadedSongPathComponent.self) WHERE serverId = \(serverId) AND songId = \(songId)")
                }
                return true
            }
        } catch {
            DDLogError("Failed to delete downloaded songs for server \(serverId) and level \(level): \(error)")
            return false
        }
    }
    
    @discardableResult
    func deleteDownloadedSongs(downloadedFolderArtist: DownloadedFolderArtist) -> Bool {
        return deleteDownloadedSongs(serverId: downloadedFolderArtist.serverId, level: 0)
    }
    
    @discardableResult
    func deleteDownloadedSongs(downloadedFolderAlbum: DownloadedFolderAlbum) -> Bool {
        return deleteDownloadedSongs(serverId: downloadedFolderAlbum.serverId, level: downloadedFolderAlbum.level)
    }
    
    @discardableResult
    func deleteDownloadedSongs(downloadedTagArtist: DownloadedTagArtist) -> Bool {
        do {
            return try pool.write { db in
                let downloadedSongs = try DownloadedSong.downloadedSongs(downloadedTagArtist: downloadedTagArtist).fetchAll(db)
                for downloadedSong in downloadedSongs {
                    // Remove song file
                    if let song = self.song(serverId: downloadedSong.serverId, id: downloadedSong.songId), FileManager.default.fileExists(atPath: song.localPath) {
                        try FileManager.default.removeItem(atPath: song.localPath)
                    }
                    
                    try db.execute(literal: "DELETE FROM \(DownloadedSong.self) WHERE serverId = \(downloadedSong.serverId) AND songId = \(downloadedSong.songId)")
                    try db.execute(literal: "DELETE FROM \(DownloadedSongPathComponent.self) WHERE serverId = \(downloadedSong.serverId) AND songId = \(downloadedSong.songId)")
                }
                return true
            }
        } catch {
            DDLogError("Failed to delete downloaded songs for downloaded tag artist \(downloadedTagArtist): \(error)")
            return false
        }
    }
    
    @discardableResult
    func deleteDownloadedSongs(downloadedTagAlbum: DownloadedTagAlbum) -> Bool {
        do {
            return try pool.write { db in
                let downloadedSongs = try DownloadedSong.downloadedSongs(downloadedTagAlbum: downloadedTagAlbum).fetchAll(db)
                for downloadedSong in downloadedSongs {
                    // Remove song file
                    if let song = self.song(serverId: downloadedSong.serverId, id: downloadedSong.songId), FileManager.default.fileExists(atPath: song.localPath) {
                        try FileManager.default.removeItem(atPath: song.localPath)
                    }
                    
                    try db.execute(literal: "DELETE FROM \(DownloadedSong.self) WHERE serverId = \(downloadedSong.serverId) AND songId = \(downloadedSong.songId)")
                    try db.execute(literal: "DELETE FROM \(DownloadedSongPathComponent.self) WHERE serverId = \(downloadedSong.serverId) AND songId = \(downloadedSong.songId)")
                }
                return true
            }
        } catch {
            DDLogError("Failed to delete downloaded songs for downloaded tag album \(downloadedTagAlbum): \(error)")
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
    
    func update(playedDate: Date, serverId: Int, songId: String) -> Bool {
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
    
    func update(downloadFinished: Bool, serverId: Int, songId: String) -> Bool {
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
    
    func update(isPinned: Bool, serverId: Int, songId: String) -> Bool {
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
    
    func isDownloadFinished(serverId: Int, songId: String) -> Bool {
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
    
    func addToDownloadQueue(serverId: Int, songId: String) -> Bool {
        do {
            return try pool.write { db in
                let sql: SQLLiteral = """
                    INSERT OR IGNORE INTO downloadQueue (serverId, songId, queuedDate)
                    VALUES (\(serverId), \(songId), \(Date()))
                    """
                try db.execute(literal: sql)
                NotificationCenter.postOnMainThread(name: Notifications.downloadQueueSongAdded)
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
    
    func addToDownloadQueue(serverId: Int, songIds: [String]) -> Bool {
        do {
            return try pool.write { db in
                for songId in songIds {
                    let sql: SQLLiteral = """
                        INSERT OR IGNORE INTO downloadQueue (serverId, songId)
                        VALUES (\(serverId), \(songId)
                        """
                    try db.execute(literal: sql)
                }
                NotificationCenter.postOnMainThread(name: Notifications.downloadQueueSongAdded)
                return true
            }
        } catch {
            DDLogError("Failed to add songIds \(songIds) server \(serverId) to download queue: \(error)")
            return false
        }
    }
    
    @discardableResult
    func clearDownloadQueue() -> Bool {
        do {
            return try pool.write { db in
                try db.execute(literal: "DELETE FROM downloadQueue")
                NotificationCenter.postOnMainThread(name: Notifications.downloadQueueSongRemoved)
                return true
            }
        } catch {
            DDLogError("Failed to clear download queue: \(error)")
            return false
        }
    }
    
    @discardableResult
    func removeFromDownloadQueue(serverId: Int, songId: String) -> Bool {
        do {
            return try pool.write { db in
                let sql: SQLLiteral = """
                    DELETE FROM downloadQueue
                    WHERE serverId = (\(serverId) AND songId = \(songId))
                    """
                try db.execute(literal: sql)
                NotificationCenter.postOnMainThread(name: Notifications.downloadQueueSongRemoved)
                return true
            }
        } catch {
            DDLogError("Failed to remove song \(songId) server \(serverId) from download queue: \(error)")
            return false
        }
    }
    
    @discardableResult
    func removeFromDownloadQueue(song: Song) -> Bool {
        return removeFromDownloadQueue(serverId: song.serverId, songId: song.id)
    }
        
    func songFromDownloadQueue(position: Int) -> Song? {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM \(Song.self)
                    JOIN downloadQueue
                    ON \(Song.self).serverId = downloadQueue.serverId AND \(Song.self).id = downloadQueue.songId
                    ORDER BY downloadQueue.rowid ASC
                    LIMIT 1 OFFSET \(position)
                    """
                return try SQLRequest<Song>(literal: sql).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select song download queue at position \(position): \(error)")
            return nil
        }
    }
    
    func queuedDateForSongFromDownloadQueue(position: Int) -> Date? {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT queuedDate
                    FROM downloadQueue
                    ORDER BY downloadQueue.rowid ASC
                    LIMIT 1 OFFSET \(position)
                    """
                return try SQLRequest<Date>(literal: sql).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select song download queued date at position \(position): \(error)")
            return nil
        }
    }
    
    func isSongInDownloadQueue(song: Song) -> Bool {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT songId
                    FROM downloadQueue
                    WHERE downloadQueue.serverId = \(song.serverId) AND downloadQueue.songId = \(song.id)
                    """
                return try SQLRequest<Int>(literal: sql).fetchCount(db) > 0
            }
        } catch {
            DDLogError("Failed to check if song \(song) is in download queue: \(error)")
            return false
        }
    }
    
    func firstSongInDownloadQueue() -> Song? {
        return songFromDownloadQueue(position: 0)
    }
    
    func downloadQueueCount() -> Int? {
        do {
            return try pool.read { db in
                return try SQLRequest<Int>(literal: "SELECT COUNT(*) FROM downloadQueue").fetchOne(db) ?? 0
            }
        } catch {
            DDLogError("Failed to select download queue count: \(error)")
            return nil
        }
    }
}
