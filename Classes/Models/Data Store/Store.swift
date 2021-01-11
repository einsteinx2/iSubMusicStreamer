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
    var pool: DatabasePool!
    
    @objc(setupDatabases) func setup() {
        DDLogVerbose("Database path: \(FileSystem.databaseDirectory)")
        
        // Shared configuration for all databases
        var config = Configuration()
        if debugPrintAllQueries {
            // Print all SQL statements
            config.prepareDatabase { db in
                db.trace { DDLogDebug($0) }
            }
        }
        
        do {
            let dbPath = FileSystem.databaseDirectory.appendingPathComponent("iSub.db").path
            pool = try DatabasePool(path: dbPath, configuration: config)
        } catch {
            DDLogError("Database failed to initialize: \(error)")
        }
        
        // Migrate database schema to latest
        migrate()
    }
    
    // TODO: Remove this as we now share the same DB for all servers and offline mode
    @objc(closeAllDatabases) func close() {
        // Underlying dataabases are closed on deallocation
        pool = nil
    }
    
    private func migrate() {
        guard let pool = pool else { DDLogError("mainDb not initialized"); return }
        
        do {
            var migrator = DatabaseMigrator()
            
            // Initial schema creation
            migrator.registerMigration("initialSchema") { db in
                try Server.createInitialSchema(db)
                try CoverArt.createInitialSchema(db)
                try ArtistArt.createInitialSchema(db)
                try Lyrics.createInitialSchema(db)
                try MediaFolder.createInitialSchema(db)
                try TagArtist.createInitialSchema(db)
                try TagAlbum.createInitialSchema(db)
                try FolderArtist.createInitialSchema(db)
                try FolderAlbum.createInitialSchema(db)
                try FolderMetadata.createInitialSchema(db)
                try Song.createInitialSchema(db)
                try DownloadedSong.createInitialSchema(db)
                try DownloadedSongPathComponent.createInitialSchema(db)
                try LocalPlaylist.createInitialSchema(db)
                try ServerPlaylist.createInitialSchema(db)
            }
            
            // Migrate old data
            // TODO: implement this
            migrator.registerMigration("migrateOldDate") { db in
                // TODO: Move song records from all playlist tables to the new database
                
                // TODO: Move data from old offline databases into offline prefixed tables in the shared db queue

                // TODO: Delete old database files
            }
            
            // Automatically perform all registered migrations in order
            // (will only perform migrations that have not run before)
            try migrator.migrate(pool)
        } catch {
            DDLogError("Failed to migrate mainDb: \(error)")
        }
    }
}

extension TableSection: FetchableRecord, PersistableRecord {
    enum Column: String, ColumnExpression {
        case serverId, mediaFolderId, name, position, itemCount
    }
}

extension RootListMetadata: FetchableRecord, PersistableRecord {
    enum Column: String, ColumnExpression {
        case serverId, mediaFolderId, itemCount, reloadDate
    }
}
