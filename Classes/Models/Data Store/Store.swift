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

// TODO: implement this - replace some complex joins with views

// Enable this to debug queries
fileprivate let debugPrintAllQueries = false

final class Store {
    // Where the database lives. Production uses a DatabasePool at the standard path;
    // tests can use an in-memory queue or a pool at a temporary file path.
    enum Location {
        case production
        case memory
        case file(URL)
    }

    // Main database, contains records for all servers
    // (typed as DatabaseWriter so tests can substitute an in-memory DatabaseQueue for the production DatabasePool)
    var pool: DatabaseWriter!

    // upToMigration stops after the named migration (migration tests build a database
    // frozen at an old schema, seed legacy rows, then call migrateToLatest())
    func setup(location: Location = .production, upToMigration: String? = nil) {
        // Shared configuration for all databases
        var config = Configuration()
        if debugPrintAllQueries {
            // Print all SQL statements
            config.prepareDatabase { db in
                db.trace { DDLogDebug("\($0)") }
            }
        }

        do {
            switch location {
            case .production:
                print("Database path: \(FileSystem.databaseDirectory.path)")
                let dbPath = FileSystem.databaseDirectory.appendingPathComponent("iSub.db").path
                pool = try DatabasePool(path: dbPath, configuration: config)
            case .memory:
                pool = try DatabaseQueue(configuration: config)
            case .file(let url):
                pool = try DatabasePool(path: url.path, configuration: config)
            }
        } catch {
            DDLogError("Database failed to initialize: \(error)")
        }

        // Migrate database schema to latest
        migrate(upTo: upToMigration)
    }

    // Runs any migrations not yet applied to the current pool (test hook — see setup)
    func migrateToLatest() {
        migrate()
    }

    private func migrate(upTo migrationName: String? = nil) {
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
                try Bookmark.createInitialSchema(db)
            }
            
            // Library contexts: per-server basic auth + nickname columns, context
            // ownership of local playlists/bookmarks, and the per-context play queue
            // snapshot tables. Legacy rows belong to the last active server
            // (fallbacks: the lowest server id, then the Combined context for
            // empty/orphaned installs).
            migrator.registerMigration("libraryContexts") { db in
                let defaults = SavedSettings.defaults
                let storedServerId = defaults.object(forKey: SavedSettings.Key.currentServerId.rawValue) as? Int
                let legacyContextId: Int
                if let id = storedServerId, id > 0, try Server.exists(db, key: id) {
                    legacyContextId = id
                } else if let minId = try Int.fetchOne(db, sql: "SELECT MIN(id) FROM server") {
                    legacyContextId = minId
                } else {
                    legacyContextId = LibraryContext.combinedContextId
                }

                try Server.createLibraryContextsSchema(db, seedBasicAuthFromGlobalSetting: defaults.bool(forKey: SavedSettings.Key.isBasicAuthEnabled.rawValue))
                try LocalPlaylist.createLibraryContextsSchema(db, legacyContextId: legacyContextId)
                try Bookmark.createLibraryContextsSchema(db, legacyContextId: legacyContextId)
                try ContextQueue.createLibraryContextsSchema(db, legacyContextId: legacyContextId)
            }

            migrator.registerMigration("jsonSupport") { db in
                try Server.createJsonSupportSchema(db)
            }

            // Migrate old data
            // TODO: implement this
//            migrator.registerMigration("migrateOldData") { db in
                // TODO: Move song records from all playlist tables to the new database

                // TODO: Move data from old offline databases into offline prefixed tables in the shared db queue

                // TODO: Delete old database files
//            }

            // Automatically perform all registered migrations in order
            // (will only perform migrations that have not run before)
            if let migrationName {
                try migrator.migrate(pool, upTo: migrationName)
            } else {
                try migrator.migrate(pool)
            }
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
