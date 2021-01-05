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
            // Prints all SQL statements
            config.prepareDatabase { db in
                db.trace { DDLogDebug($0) }
            }
        }
        
        do {
            // Server DB
            let serverDbPath = FileSystem.databaseDirectory.appendingPathComponent(Settings.shared().serverId + ".db").path
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
