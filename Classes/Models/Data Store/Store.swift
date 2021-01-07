//
//  Store.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjackSwift
import Resolver

// Enable this to debug queries
fileprivate let debugPrintAllQueries = false

// Make available to Obj-C
@objc final class Store: NSObject {
    
    // Temporary accessor for Objective-C classes using Resolver under the hood
    @objc static var shared: Store { Resolver.main.resolve() }
    
    // Per server database, contains only records specific to the active server
    private var serverDb: DatabasePool!
    
    // Shared database, contains data shared between all servers like the lyrics cache
    private var sharedDb: DatabasePool!
    
    // Shared downloaded songs database, contains data related to songs downloaded for offline use
    // NOTE: This is a separate database so that it can be excluded from iCloud backups
    private var downloadsDb: DatabasePool!
    
    @objc(setupDatabases) func setup() {
        // Shared configuration for all databases
        var config = Configuration()
        if debugPrintAllQueries {
            // Print all SQL statements
            config.prepareDatabase { db in
                db.trace { DDLogDebug($0) }
            }
        }
        
        do {
            // Server DB
            let serverDbPath = FileSystem.databaseDirectory.appendingPathComponent(Settings.shared().serverId + "_grdb.db").path
            serverDb = try DatabasePool(path: serverDbPath, configuration: config)
            
            // Shared DB
            let sharedDbPath = FileSystem.databaseDirectory.appendingPathComponent("shared.db").path
            sharedDb = try DatabasePool(path: sharedDbPath, configuration: config)
            
            // Downloads DB
            let downloadsDbPath = FileSystem.databaseDirectory.appendingPathComponent("downloads.db").path
            downloadsDb = try DatabasePool(path: downloadsDbPath, configuration: config)
        } catch {
            DDLogError("Database failed to initialize: \(error)")
        }
        
        // Migrate database schema to latest
        migrate()
    }
    
    @objc(closeAllDatabases) func close() {
        // Underlying dataabases are closed on deallocation
        serverDb = nil
        sharedDb = nil
        downloadsDb = nil
    }
    
    private func migrate() {
        migrateServerDb()
        migrateSharedDb()
        migrateDownloadsDb()
    }
    
    private func migrateServerDb() {
        guard let serverDb = serverDb else { DDLogError("serverDb not initialized"); return }
        
        do {
            var migrator = DatabaseMigrator()
            
            // Initial schema creation
            migrator.registerMigration("initialSchema") { db in
                //
                // MediaFolder
                //
                
                try db.create(table: MediaFolder.databaseTableName) { t in
                    t.column(MediaFolder.Column.id, .integer).notNull().primaryKey()
                    t.column(MediaFolder.Column.name, .text).notNull()
                }
                
                //
                // TagArtist
                //
                
                // Shared table of unique artist records
                try db.create(table: TagArtist.databaseTableName) { t in
                    t.column(TagArtist.Column.id, .integer).notNull().primaryKey()
                    t.column(TagArtist.Column.name, .text).notNull().indexed()
                    t.column(TagArtist.Column.coverArtId, .text)
                    t.column(TagArtist.Column.artistImageUrl, .text)
                    t.column(TagArtist.Column.albumCount, .integer).notNull()
                }
                
                // Cache of tag artist IDs for each media folder for display
                try db.create(table: TagArtist.Table.tagArtistList) { t in
                    t.autoIncrementedPrimaryKey(Column.rowID).notNull()
                    t.column(TagArtist.RelatedColumn.mediaFolderId, .integer).notNull().indexed()
                    t.column(TagArtist.RelatedColumn.tagArtistId, .integer).notNull()
                }
                
                // Cache of section indexes for display
                try db.create(table: TagArtist.Table.tagArtistTableSection) { t in
                    t.column(TableSection.Column.mediaFolderId, .integer).notNull().indexed()
                    t.column(TableSection.Column.name, .text).notNull()
                    t.column(TableSection.Column.position, .integer).notNull()
                    t.column(TableSection.Column.itemCount, .integer).notNull()
                }
                
                // Cache of tag artist loading metadata for display
                try db.create(table: TagArtist.Table.tagArtistListMetadata) { t in
                    t.column(RootListMetadata.Column.mediaFolderId, .integer).notNull().primaryKey()
                    t.column(RootListMetadata.Column.itemCount, .integer).notNull()
                    t.column(RootListMetadata.Column.reloadDate, .datetime).notNull()
                }
                
                //
                // TagAlbum
                //
                
                // Shared table of unique album records
                try db.create(table: TagAlbum.databaseTableName) { t in
                    t.column(TagAlbum.Column.id, .integer).notNull().primaryKey()
                    t.column(TagAlbum.Column.name, .text).notNull()
                    t.column(TagAlbum.Column.coverArtId, .text)
                    t.column(TagAlbum.Column.tagArtistId, .integer).indexed()
                    t.column(TagAlbum.Column.tagArtistName, .text)
                    t.column(TagAlbum.Column.songCount, .integer).notNull()
                    t.column(TagAlbum.Column.duration, .integer).notNull()
                    t.column(TagAlbum.Column.playCount, .integer).notNull()
                    t.column(TagAlbum.Column.year, .integer).notNull()
                    t.column(TagAlbum.Column.genre, .text)
                }
                
                // Cache of song IDs for each tag album for display
                try db.create(table: TagAlbum.Table.tagSongList) { t in
                    t.autoIncrementedPrimaryKey(Column.rowID).notNull()
                    t.column(TagAlbum.RelatedColumn.tagAlbumId, .integer).notNull().indexed()
                    t.column(TagAlbum.RelatedColumn.songId, .integer).notNull()
                }
                
                //
                // Song
                //
                
                // Shared table of unique song records
                try db.create(table: NewSong.databaseTableName) { t in
                    t.column(NewSong.Column.id, .integer).notNull().primaryKey()
                    t.column(NewSong.Column.title, .text).notNull()
                    t.column(NewSong.Column.coverArtId, .text)
                    t.column(NewSong.Column.parentFolderId, .integer)
                    t.column(NewSong.Column.tagArtistName, .text)
                    t.column(NewSong.Column.tagAlbumName, .text)
                    t.column(NewSong.Column.playCount, .integer)
                    t.column(NewSong.Column.year, .integer)
                    t.column(NewSong.Column.tagArtistId, .integer)
                    t.column(NewSong.Column.tagAlbumId, .integer)
                    t.column(NewSong.Column.genre, .text)
                    t.column(NewSong.Column.path, .text).notNull()
                    t.column(NewSong.Column.suffix, .text).notNull()
                    t.column(NewSong.Column.transcodedSuffix, .text)
                    t.column(NewSong.Column.duration, .integer).notNull()
                    t.column(NewSong.Column.bitrate, .integer).notNull()
                    t.column(NewSong.Column.track, .integer).notNull()
                    t.column(NewSong.Column.discNumber, .integer)
                    t.column(NewSong.Column.size, .integer).notNull()
                    t.column(NewSong.Column.isVideo, .boolean).notNull()
                }
            }
            
            // Automatically perform all registered migrations in order
            // (will only perform migrations that have not run before)
            try migrator.migrate(serverDb)
        } catch {
            DDLogError("Failed to migrate database: \(error)")
        }
    }
    
    private func migrateSharedDb() {
//        guard let sharedDb = sharedDb else { DDLogError("sharedDb not initialized"); return }
//
//        do {
//            var migrator = DatabaseMigrator()
//
//            // Initial schema creation
//            migrator.registerMigration("initialSchema") { db in
//
//            }
//
//            // Automatically perform all registered migrations in order
//            // (will only perform migrations that have not run before)
//            try migrator.migrate(sharedDb)
//        } catch {
//            DDLogError("Failed to migrate database: \(error)")
//        }
    }
    
    private func migrateDownloadsDb() {
//        guard let downloadsDb = downloadsDb else { DDLogError("downloadsDb not initialized"); return }
//
//        do {
//            var migrator = DatabaseMigrator()
//
//            // Initial schema creation
//            migrator.registerMigration("initialSchema") { db in
//
//            }
//
//            // Automatically perform all registered migrations in order
//            // (will only perform migrations that have not run before)
//            try migrator.migrate(downloadsDb)
//        } catch {
//            DDLogError("Failed to migrate database: \(error)")
//        }
    }
    
    // MARK: Media Folders
    
    @objc func mediaFolders() -> [MediaFolder] {
        do {
            return try serverDb.read { db in
                try MediaFolder.all().fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all media folders: \(error)")
            return [MediaFolder]()
        }
    }
    
    @objc func deleteMediaFolders() -> Bool {
        do {
            return try serverDb.write { db in
                try MediaFolder.deleteAll(db)
                return true
            }
        } catch {
            DDLogError("Failed to delete all media folders: \(error)")
            return false
        }
    }
    
    @objc func add(mediaFolders: [MediaFolder]) -> Bool {
        do {
            return try serverDb.write { db in
                for mediaFolder in mediaFolders {
                    try mediaFolder.insert(db)
                }
                return true
            }
        } catch {
            DDLogError("Failed to insert media folders: \(error)")
            return false
        }
    }
    
    // MARK: TagArtist
    
    func deleteTagArtists(mediaFolderId: Int) -> Bool {
        do {
            return try serverDb.write { db in
                try db.execute(literal: "DELETE FROM tagArtistList WHERE mediaFolderId = \(mediaFolderId)")
                try db.execute(literal: "DELETE FROM tagArtistTableSection WHERE mediaFolderId = \(mediaFolderId)")
                try db.execute(literal: "DELETE FROM tagArtistListMetadata WHERE mediaFolderId = \(mediaFolderId)")
                return true
            }
        } catch {
            DDLogError("Failed to reset tag artist caches: \(error)")
            return false
        }
    }
    
    func tagArtistIds(mediaFolderId: Int) -> [Int] {
        do {
            return try serverDb.read { db in
                let sql: SQLLiteral = """
                    SELECT tagArtistId
                    FROM tagArtistList
                    WHERE mediaFolderId = \(mediaFolderId)
                    ORDER BY \(Column.rowID) ASC
                    """
                return try SQLRequest<Int>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select tag artist IDs for media folder \(mediaFolderId): \(error)")
            return []
        }
    }
    
    func tagArtist(id: Int) -> TagArtist? {
        do {
            return try serverDb.read { db in
                try TagArtist.filter(key: id).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select tag artist \(id): \(error)")
            return nil
        }
    }
    
    func add(tagArtist: TagArtist, mediaFolderId: Int) -> Bool {
        do {
            return try serverDb.write { db in
                // Insert or update shared artist record
                try tagArtist.save(db)
                
                // Insert artist id into list cache
                let sql: SQLLiteral = """
                    INSERT INTO tagArtistList
                    (mediaFolderId, tagArtistId)
                    VALUES (\(mediaFolderId), \(tagArtist.id))
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to insert tag artist \(tagArtist) in media folder \(mediaFolderId): \(error)")
            return false
        }
    }
    
    func tagArtistSections(mediaFolderId: Int) -> [TableSection] {
        do {
            return try serverDb.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM tagArtistTableSection
                    WHERE mediaFolderId = \(mediaFolderId)
                    """
                return try SQLRequest<TableSection>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select tag artist table sections for media folder \(mediaFolderId): \(error)")
            return [TableSection]()
        }
    }
    
    func add(tagArtistSection section: TableSection) -> Bool {
        do {
            return try serverDb.write { db in
                // Insert artist id into list cache
                let sql: SQLLiteral = """
                    INSERT INTO tagArtistTableSection
                    (mediaFolderId, name, position, itemCount)
                    VALUES (\(section.mediaFolderId), \(section.name), \(section.position), \(section.itemCount))
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to insert tag artist section \(section) in media folder \(section.mediaFolderId): \(error)")
            return false
        }
    }
    
    func tagArtistMetadata(mediaFolderId: Int) -> RootListMetadata? {
        do {
            return try serverDb.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM tagArtistListMetadata
                    WHERE mediaFolderId = \(mediaFolderId)
                    """
                return try SQLRequest<RootListMetadata>(literal: sql).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select tag artist metadata for media folder \(mediaFolderId): \(error)")
            return nil
        }
    }
    
    func add(tagArtistListMetadata metadata: RootListMetadata) -> Bool {
        do {
            return try serverDb.write { db in
                let sql: SQLLiteral = """
                    INSERT INTO tagArtistListMetadata
                    (mediaFolderId, itemCount, reloadDate)
                    VALUES (\(metadata.mediaFolderId), \(metadata.itemCount), \(metadata.reloadDate))
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to insert tag artist list metadata in media folder \(metadata.mediaFolderId): \(error)")
            return false
        }
    }
    
    // Returns a list of matching tag artist IDs
    func search(tagArtistName name: String, mediaFolderId: Int, offset: Int, limit: Int) -> [Int] {
        do {
            return try serverDb.read { db in
                let searchTerm = "%\(name)%"
                let sql: SQLLiteral = """
                    SELECT tagArtistId
                    FROM tagArtistList
                    JOIN \(TagArtist.self)
                    ON tagArtistList.tagArtistId = \(TagArtist.self).id
                    WHERE tagArtistList.mediaFolderId = \(mediaFolderId)
                    AND \(TagArtist.self).name LIKE \(searchTerm)
                    LIMIT \(limit) OFFSET \(offset)
                    """
                DDLogVerbose("TEST ARTIST SEARCH QUERY:\n\(sql)\n")
                return try SQLRequest<Int>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to search for tag artist \(name) in media folder \(mediaFolderId): \(error)")
            return []
        }
    }
    
    // MARK: TagAlbum
    
    func deleteTagAlbums(tagArtistId: Int) -> Bool {
        do {
            return try serverDb.write { db in
                try db.execute(literal: "DELETE FROM \(TagAlbum.self) WHERE tagArtistId = \(tagArtistId)")
                return true
            }
        } catch {
            DDLogError("Failed to reset tag artist caches: \(error)")
            return false
        }
    }
    
    // TODO: Complete this query when needed for UI
//    func tagAlbumIds(mediaFolderId: Int, orderBy: TagAlbum.Column = .name) -> [String] {
//        do {
//            return try serverDb.read { db in
//                let sql: SQLLiteral = """
//                    SELECT id
//                    FROM \(TagAlbum.self)
//                    JOIN
//                    WHERE mediaFolderId = \(mediaFolderId)
//                    ORDER BY \(orderBy) ASC
//                    """
//                return try SQLRequest<String>(literal: sql).fetchAll(db)
//            }
//        } catch {
//            DDLogError("Failed to select tag album IDs for media folder \(mediaFolderId) ordered by \(orderBy): \(error)")
//            return []
//        }
//    }
    
    func tagAlbumIds(tagArtistId: Int, orderBy: TagAlbum.Column = .name) -> [Int] {
        do {
            return try serverDb.read { db in
                let sql: SQLLiteral = """
                    SELECT id
                    FROM \(TagAlbum.self)
                    WHERE tagArtistId = \(tagArtistId)
                    ORDER BY \(orderBy) ASC
                    """
                return try SQLRequest<Int>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select tag album IDs for tag artist ID \(tagArtistId) ordered by \(orderBy): \(error)")
            return []
        }
    }
    
    func tagAlbum(id: Int) -> TagAlbum? {
        do {
            return try serverDb.read { db in
                try TagAlbum.filter(key: id).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select tag album \(id): \(error)")
            return nil
        }
    }
    
    func add(tagAlbum: TagAlbum) -> Bool {
        do {
            return try serverDb.write { db in
                // Insert or update shared album record
                try tagAlbum.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to insert tag album \(tagAlbum): \(error)")
            return false
        }
    }
    
    func songIds(tagAlbumId: Int) -> [Int] {
        do {
            return try serverDb.read { db in
                let sql: SQLLiteral = """
                    SELECT songId
                    FROM tagSongList
                    WHERE tagAlbumId = \(tagAlbumId)
                    ORDER BY \(Column.rowID) ASC
                    """
                return try SQLRequest<Int>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select song IDs for tag album ID \(tagAlbumId): \(error)")
            return []
        }
    }
    
    func deleteTagSongs(tagAlbumId: Int) -> Bool {
        do {
            return try serverDb.write { db in
                try db.execute(literal: "DELETE FROM tagSongList WHERE tagAlbumId = \(tagAlbumId)")
                return true
            }
        } catch {
            DDLogError("Failed to reset tag album song cache: \(error)")
            return false
        }
    }
    
    func add(tagSong song: NewSong) -> Bool {
        do {
            return try serverDb.write { db in
                // Insert or update shared artist record
                try song.save(db)
                
                // Insert artist id into list cache
                let sql: SQLLiteral = """
                    INSERT INTO tagSongList
                    (tagAlbumId, songId)
                    VALUES (\(song.tagAlbumId), \(song.id))
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to insert tag song \(song) in tag album \(song.tagAlbumId): \(error)")
            return false
        }
    }
    
    // MARK: Song
    
    func song(id: Int) -> NewSong? {
        do {
            return try serverDb.read { db in
                try NewSong.filter(key: id).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select song \(id): \(error)")
            return nil
        }
    }
    
    func add(song: NewSong) -> Bool {
        do {
            return try serverDb.write { db in
                // Insert or update shared song record
                try song.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to insert song \(song): \(error)")
            return false
        }
    }
}

extension TableDefinition {
    @discardableResult
    func column(_ columnExpression: ColumnExpression, _ type: Database.ColumnType? = nil) -> ColumnDefinition {
        self.column(columnExpression.name, type)
    }
    
    @discardableResult
    func column(_ column: Column, _ type: Database.ColumnType? = nil) -> ColumnDefinition {
        self.column(column.name, type)
    }
    
    @discardableResult
    public func autoIncrementedPrimaryKey(_ columnExpression: ColumnExpression, onConflict conflictResolution: Database.ConflictResolution? = nil) -> ColumnDefinition {
        self.autoIncrementedPrimaryKey(columnExpression.name, onConflict: conflictResolution)
    }
    
    @discardableResult
    public func autoIncrementedPrimaryKey(_ column: Column, onConflict conflictResolution: Database.ConflictResolution? = nil) -> ColumnDefinition {
        self.autoIncrementedPrimaryKey(column.name, onConflict: conflictResolution)
    }
}

extension MediaFolder: FetchableRecord, PersistableRecord {
    enum Column: String, ColumnExpression {
        case id, name
    }
}

extension TableSection: FetchableRecord, PersistableRecord {
    enum Column: String, ColumnExpression {
        case mediaFolderId, name, position, itemCount
    }
}

extension RootListMetadata: FetchableRecord, PersistableRecord {
    enum Column: String, ColumnExpression {
        case mediaFolderId, itemCount, reloadDate
    }
}

extension TagArtist: FetchableRecord, PersistableRecord {
    struct Table {
        static let tagArtistList = "tagArtistList"
        static let tagArtistTableSection = "tagArtistTableSection"
        static let tagArtistListMetadata = "tagArtistListMetadata"
    }
    enum Column: String, ColumnExpression {
        case id, name, coverArtId, artistImageUrl, albumCount
    }
    enum RelatedColumn: String, ColumnExpression {
        case mediaFolderId, tagArtistId
    }
}

extension TagAlbum: FetchableRecord, PersistableRecord {
    struct Table {
        static let tagSongList = "tagSongList"
    }
    enum Column: String, ColumnExpression {
        case id, name, coverArtId, tagArtistId, tagArtistName, songCount, duration, playCount, year, genre
    }
    enum RelatedColumn: String, ColumnExpression {
        case tagAlbumId, songId
    }
}

extension NewSong: FetchableRecord, PersistableRecord {
    static var databaseTableName: String = "song"
    
    enum Column: String, ColumnExpression {
        case id, title, coverArtId, parentFolderId, tagArtistName, tagAlbumName, playCount, year, tagArtistId, tagAlbumId, genre, path, suffix, transcodedSuffix, duration, bitrate, track, discNumber, size, isVideo
    }
}
