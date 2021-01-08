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
    
    // Main database, contains records for all servers
    var mainDb: DatabasePool!
    
    // Shared downloaded songs database, contains data related to songs downloaded for offline use
    // NOTE: This is a separate database so that it can be excluded from iCloud backups
    var downloadsDb: DatabasePool!
    
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
            // Main DB
            let mainDbPath = FileSystem.databaseDirectory.appendingPathComponent("main.db").path
            mainDb = try DatabasePool(path: mainDbPath, configuration: config)
            
            // Downloads DB
            let downloadsDbPath = FileSystem.databaseDirectory.appendingPathComponent("downloads.db").path
            downloadsDb = try DatabasePool(path: downloadsDbPath, configuration: config)
        } catch {
            DDLogError("Database failed to initialize: \(error)")
        }
        
        // Migrate database schema to latest
        migrate()
    }
    
    // TODO: Remove this as we now share the same DB for all servers and offline mode
    @objc(closeAllDatabases) func close() {
        // Underlying dataabases are closed on deallocation
        mainDb = nil
        downloadsDb = nil
    }
    
    private func migrate() {
        migrateMainDb()
        migrateDownloadsDb()
    }
    
    private func migrateMainDb() {
        guard let mainDb = mainDb else { DDLogError("mainDb not initialized"); return }
        
        do {
            var migrator = DatabaseMigrator()
            
            // Initial schema creation
            migrator.registerMigration("initialSchema") { db in
                try Server.createInitialSchema(db)
                try MediaFolder.createInitialSchema(db)
                try TagArtist.createInitialSchema(db)
                try TagAlbum.createInitialSchema(db)
                try FolderArtist.createInitialSchema(db)
                try FolderAlbum.createInitialSchema(db)
                try FolderMetadata.createInitialSchema(db)
                try NewSong.createInitialSchema(db)
                try CoverArt.createInitialSchema(db)
                try ArtistArt.createInitialSchema(db)
            }
            
            // Automatically perform all registered migrations in order
            // (will only perform migrations that have not run before)
            try migrator.migrate(mainDb)
        } catch {
            DDLogError("Failed to migrate mainDb: \(error)")
        }
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
