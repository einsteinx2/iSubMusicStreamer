//
//  Store.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

// -----------------------------
// Data Architecture Explanation
// -----------------------------
//
// Goals:
// 1. All default data accesses should be O(1) when possible
// 2. Any additional time to process or sort data should be done during network loading when possible
// 3. In use cases that are non-default (i.e. optional sorting or searching within a list of items),
//    then it's acceptable to require a small loading delay to provide the functionality
//
// At first, it may seem like the iSub database architecture is convoluted compared to
// standard convention. For example, rather than simple access methods that return
// arrays of objects, all data access is organized to load record-by-record.
//
// While it's true that this is non-standard and less "clean" of an architecture
// than would normally be used, the benefit to this approach is that no matter how
// large the media library is, the access time is always O(1) rather than O(N).
//
// Now O(N) may not seem so bad at first, but with Subsonic media libraries, it's not
// uncommon to have 10s or even 100s of thousands of items to display in a given view.
//
// Take the use case of a user with all of their album folders in the main folder list.
// They may have 100,000 folders, meaning that if it were done in the usual way, every
// time the Folder list is displayed, we would need to load 100,000 records into memory
// before we can display anything. On mobile devices especially, this is non-trivial and
// will cause a delay before the first records are shown which scales with the size of
// the library.
//
// iSub was first designed for the iPhone 3G, so having O(1) load time was especially
// important. Even with the latest iPhone models, there is still a perceivable delay
// when loading large data sets.
//
// One of iSub's main goals is high-performance, specifically providing the same
// performance regardless of whether the server contains 100 songs or a million songs.
// Since the library is server based, the potential size is effectively
// unlimited. If iSub were built to play local files only, or if it were connected to a
// developer controlled library of music like Spotify or Apple Music, it could be
// architected more cleanly, but since the library layout is not known and of potentially
// unlimited size, the decision has been made to intentially complicate the data model
// layer to achieve instant loading times of all views after initially loaded from the network.


import Foundation
import GRDB
import CocoaLumberjackSwift

// Enable this to debug queries
fileprivate let debugPrintAllQueries = false

// Make available to Obj-C
@objc final class Store: NSObject {
    
    // Once the app is 100% Swift, switch to dependency injection with Resolver
    @objc static let shared = Store()
    
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
                // MediaFolder
                try db.create(table: MediaFolder.databaseTableName) { t in
                    t.column("id", .integer).notNull()
                    t.column("name", .text).notNull()
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
                try MediaFolder.selectAll(db)                
            }
        } catch {
            DDLogError("Failed to select all media folders: \(error)")
            return [MediaFolder]()
        }
    }
    
    @objc func deleteMusicFolders() {
        do {
            return try serverDb.write { db in
                try MediaFolder.deleteAll(db)
            }
        } catch {
            DDLogError("Failed to delete all media folders: \(error)")
        }
    }
    
    @objc func add(mediaFolders: [MediaFolder]) {
        do {
            return try serverDb.write { db in
                for mediaFolder in mediaFolders {
                    try mediaFolder.insert(db)
                }
            }
        } catch {
            DDLogError("Failed to insert media folders: \(error)")
        }
    }
    
    // MARK: Tag Artists
    
    
}

extension MediaFolder: FetchableRecord, PersistableRecord {
    static func selectAll(_ db: Database) throws -> [MediaFolder] {
        let request = SQLRequest<MediaFolder>("SELECT * FROM \(self)")
        return try request.fetchAll(db)
    }
    
    static func deleteAll(_ db: Database) throws {
        let query: SQLLiteral = "DELETE FROM \(self)"
        try db.execute(literal: query)
    }
}
