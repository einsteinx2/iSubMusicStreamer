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
                    t.column("id", .integer).notNull().unique()
                    t.column("name", .text).notNull()
                }
                
                //
                // Tag Artist
                //
                
                // Shared table of unique artist records
                try db.create(table: TagArtist.databaseTableName) { t in
                    t.column("id", .text).notNull().primaryKey()
                    t.column("name", .text).notNull().indexed()
                    t.column("coverArtId", .text)
                    t.column("artistImageUrl", .text)
                    t.column("albumCount", .integer).notNull()
                }
                
                // Cache of tag artist IDs for each media folder for display
                try db.create(table: "tagArtistList") { t in
                    t.autoIncrementedPrimaryKey("rowid")
                    t.column("mediaFolderId", .integer).notNull()
                    t.column("tagArtistId", .integer).notNull().indexed()
                }
                
                // Cache of section indexes for display
                try db.create(table: "tagArtistTableSection") { t in
                    t.column("mediaFolderId", .integer).notNull().indexed()
                    t.column("name", .text).notNull()
                    t.column("position", .integer).notNull()
                    t.column("itemCount", .integer).notNull()
                }
                
                // Cache of tag artist loading metadata for display
                try db.create(table: "tagArtistListMetadata") { t in
                    t.column("mediaFolderId", .integer).notNull().unique()
                    t.column("itemCount", .integer).notNull()
                    t.column("reloadDate", .datetime).notNull()
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
    
    // MARK: Tag Artists
    
    @objc func resetTagArtistCache(mediaFolderId: Int) {
        do {
            try serverDb.write { db in
                try db.execute(literal: "DELETE FROM tagArtistList WHERE mediaFolderId = \(mediaFolderId)")
                try db.execute(literal: "DELETE FROM tagArtistTableSection WHERE mediaFolderId = \(mediaFolderId)")
                try db.execute(literal: "DELETE FROM tagArtistListMetadata WHERE mediaFolderId = \(mediaFolderId)")
            }
        } catch {
            DDLogError("Failed to reset tag artist caches: \(error)")
        }
    }
    
    @objc func tagArtistIds(mediaFolderId: Int) -> [String] {
        do {
            return try serverDb.read { db in
                let sql: SQLLiteral = """
                    SELECT tagArtistId
                    FROM tagArtistList
                    WHERE mediaFolderId = \(mediaFolderId)
                    ORDER BY rowid ASC
                    """
                return try SQLRequest<String>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select tag artist IDs for media folder \(mediaFolderId): \(error)")
            return []
        }
    }
    
    @objc func tagArtist(id: String) -> TagArtist? {
        do {
            return try serverDb.read { db in
                try TagArtist.filter(key: id).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select tag artist \(id): \(error)")
            return nil
        }
    }
    
    @objc func add(tagArtist: TagArtist, mediaFolderId: Int) -> Bool {
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
    
    @objc func tagArtistSections(mediaFolderId: Int) -> [TableSection] {
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
    
    @objc func add(tagArtistSection section: TableSection) -> Bool {
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
    
    @objc func tagArtistMetadata(mediaFolderId: Int) -> RootListMetadata? {
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
    
    @objc func add(tagArtistListMetadata metadata: RootListMetadata) -> Bool {
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
    @objc func search(tagArtistName name: String, mediaFolderId: Int, offset: Int, limit: Int) -> [String] {
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
                return try SQLRequest<String>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to search for tag artist \(name) in media folder \(mediaFolderId): \(error)")
            return []
        }
    }
}

extension MediaFolder: FetchableRecord, PersistableRecord { }
extension TableSection: FetchableRecord, PersistableRecord { }
extension RootListMetadata: FetchableRecord, PersistableRecord { }
extension TagArtist: FetchableRecord, PersistableRecord { }
