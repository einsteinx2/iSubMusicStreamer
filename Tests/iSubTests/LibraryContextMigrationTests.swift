//
//  LibraryContextMigrationTests.swift
//  iSubTests
//
//  Created by Ben Baron on 7/17/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
import GRDB
@testable import iSub_Beta

// The "libraryContexts" migration: per-server basic auth + nickname columns, context
// ownership of local playlists/bookmarks, the per-context queue snapshot tables, and
// the legacy-data assignment chain (stored current server → lowest server id →
// Combined). Legacy rows are seeded with raw SQL against the initialSchema database
// because the model types now include the new columns.
final class LibraryContextMigrationTests: SandboxedTestCase {

    // MARK: Helpers

    private func makeStoreAtInitialSchema() -> Store {
        let store = Store()
        store.setup(location: .memory, upToMigration: "initialSchema")
        return store
    }

    private func insertLegacyServer(_ store: Store, id: Int, urlString: String = "https://legacy.example.com") throws {
        try store.pool.write { db in
            try db.execute(sql: """
                INSERT INTO server (id, type, url, username, password, path, isVideoSupported, isNewSearchSupported, isTagSearchSupported)
                VALUES (?, ?, ?, 'user', 'pass', 'https_legacy.example.com_port', 1, 1, 1)
                """, arguments: [id, ServerType.subsonic.rawValue, urlString])
        }
    }

    private func insertLegacyPlaylist(_ store: Store, id: Int, name: String = "Legacy Playlist", isBookmark: Bool = false) throws {
        try store.pool.write { db in
            try db.execute(sql: "INSERT INTO localPlaylist (id, name, songCount, isBookmark, createdDate) VALUES (?, ?, 0, ?, ?)",
                           arguments: [id, name, isBookmark, Date()])
        }
    }

    private func insertLegacyBookmark(_ store: Store, id: Int, localPlaylistId: Int) throws {
        try store.pool.write { db in
            try db.execute(sql: """
                INSERT INTO bookmark (id, songServerId, songId, localPlaylistId, songIndex, offsetInSeconds, offsetInBytes)
                VALUES (?, 1, '100', ?, 0, 12.5, 4096)
                """, arguments: [id, localPlaylistId])
        }
    }

    private func contextId(_ store: Store, table: String, rowId: Int) throws -> Int? {
        try store.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT contextId FROM \(table) WHERE id = ?", arguments: [rowId])
        }
    }

    private func markerContextId(_ store: Store) throws -> Int? {
        try store.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT contextId FROM activeQueueContext WHERE id = 0")
        }
    }

    // MARK: Legacy assignment chain

    func testLegacyRowsAssignedToStoredCurrentServer() throws {
        let store = makeStoreAtInitialSchema()
        try insertLegacyServer(store, id: 3)
        try insertLegacyServer(store, id: 7)
        try insertLegacyPlaylist(store, id: 5)
        try insertLegacyPlaylist(store, id: 6, isBookmark: true)
        try insertLegacyBookmark(store, id: 1, localPlaylistId: 6)
        testDefaults.set(7, forKey: SavedSettings.Key.currentServerId.rawValue)

        store.migrateToLatest()

        XCTAssertEqual(try contextId(store, table: "localPlaylist", rowId: 5), 7)
        XCTAssertEqual(try contextId(store, table: "localPlaylist", rowId: 6), 7)
        XCTAssertEqual(try contextId(store, table: "bookmark", rowId: 1), 7)
        XCTAssertEqual(try markerContextId(store), 7)
    }

    func testReservedQueueRowsStayContextFree() throws {
        let store = makeStoreAtInitialSchema()
        try insertLegacyServer(store, id: 3)
        testDefaults.set(3, forKey: SavedSettings.Key.currentServerId.rawValue)

        store.migrateToLatest()

        for reservedId in 1...LocalPlaylist.Default.maxDefaultId {
            XCTAssertEqual(try contextId(store, table: "localPlaylist", rowId: reservedId), LibraryContext.noContextId,
                           "reserved queue row \(reservedId) must keep contextId -1")
        }
    }

    func testLegacyAssignmentFallsBackToLowestServerId() throws {
        let store = makeStoreAtInitialSchema()
        try insertLegacyServer(store, id: 3)
        try insertLegacyServer(store, id: 7)
        try insertLegacyPlaylist(store, id: 5)
        // The stored id points at a server that no longer exists
        testDefaults.set(99, forKey: SavedSettings.Key.currentServerId.rawValue)

        store.migrateToLatest()

        XCTAssertEqual(try contextId(store, table: "localPlaylist", rowId: 5), 3)
        XCTAssertEqual(try markerContextId(store), 3)
    }

    func testLegacyAssignmentFallsBackToCombinedWithNoServers() throws {
        let store = makeStoreAtInitialSchema()
        try insertLegacyPlaylist(store, id: 5)

        store.migrateToLatest()

        XCTAssertEqual(try contextId(store, table: "localPlaylist", rowId: 5), LibraryContext.combinedContextId)
        XCTAssertEqual(try markerContextId(store), LibraryContext.combinedContextId)
    }

    // MARK: Per-server basic auth + nickname

    func testBasicAuthSeededFromGlobalSettingWhenOn() throws {
        let store = makeStoreAtInitialSchema()
        try insertLegacyServer(store, id: 1)
        testDefaults.set(true, forKey: SavedSettings.Key.isBasicAuthEnabled.rawValue)

        store.migrateToLatest()

        let server = try XCTUnwrap(store.server(id: 1))
        XCTAssertTrue(server.isBasicAuthEnabled)
        XCTAssertNil(server.name, "the nickname column starts empty")
    }

    func testBasicAuthDefaultsToOffWithoutGlobalSetting() throws {
        let store = makeStoreAtInitialSchema()
        try insertLegacyServer(store, id: 1)

        store.migrateToLatest()

        let server = try XCTUnwrap(store.server(id: 1))
        XCTAssertFalse(server.isBasicAuthEnabled)
    }

    func testServerNameRoundTripsAfterMigration() throws {
        let store = Store()
        store.setup(location: .memory)
        _ = store.add(server: Server(id: 1, type: .subsonic, url: URL(string: "https://a.example.com")!,
                                     username: "u", password: "p", name: "Home NAS", isBasicAuthEnabled: true))

        let server = try XCTUnwrap(store.server(id: 1))
        XCTAssertEqual(server.name, "Home NAS")
        XCTAssertTrue(server.isBasicAuthEnabled)
    }

    // MARK: Fresh installs

    func testFreshInstallSeedsCombinedMarkerAndContextFreeQueues() throws {
        let store = Store()
        store.setup(location: .memory)

        XCTAssertEqual(try markerContextId(store), LibraryContext.combinedContextId)
        for reservedId in 1...LocalPlaylist.Default.maxDefaultId {
            XCTAssertEqual(try contextId(store, table: "localPlaylist", rowId: reservedId), LibraryContext.noContextId)
        }
    }

    // MARK: Context-scoped display queries

    func testLocalPlaylistQueriesFilterByContext() throws {
        let store = Store()
        store.setup(location: .memory)
        XCTAssertTrue(store.add(localPlaylist: LocalPlaylist(id: 10, name: "Server One Mix", contextId: 1)))
        XCTAssertTrue(store.add(localPlaylist: LocalPlaylist(id: 11, name: "Server Two Mix", contextId: 2)))
        XCTAssertTrue(store.add(localPlaylist: LocalPlaylist(id: 12, name: "Combined Mix", contextId: LibraryContext.combinedContextId)))

        XCTAssertEqual(store.localPlaylists(contextId: 1).map(\.id), [10])
        XCTAssertEqual(store.localPlaylists(contextId: 2).map(\.id), [11])
        XCTAssertEqual(store.localPlaylists(contextId: LibraryContext.combinedContextId).map(\.id), [12])
        XCTAssertEqual(store.localPlaylistsCount(contextId: 1), 1)

        XCTAssertEqual(store.localPlaylist(name: "Server One Mix", contextId: 1)?.id, 10)
        XCTAssertNil(store.localPlaylist(name: "Server One Mix", contextId: 2),
                     "name-collision lookup must not cross contexts")
    }

    func testLocalPlaylistDefaultQueryResolvesActiveContext() throws {
        let store = Store()
        store.setup(location: .memory)
        let injectedStore: Store = store
        TestContainer.register { injectedStore }

        // A fresh settings/session pair registered over the app's so the default
        // context resolution is deterministic in this test
        let session = ServerSession()
        let settings = SavedSettings(session: session)
        TestContainer.register { settings }
        let server = TestData.server(id: 2)
        _ = store.add(server: server)
        session.currentServer = server

        XCTAssertTrue(store.add(localPlaylist: LocalPlaylist(id: 10, name: "Mine", contextId: 2)))
        XCTAssertTrue(store.add(localPlaylist: LocalPlaylist(id: 11, name: "Other", contextId: 3)))

        XCTAssertEqual(store.localPlaylists().map(\.id), [10], "the default query scopes to the active context")
    }

    func testBookmarkQueriesFilterByContext() throws {
        let store = Store()
        store.setup(location: .memory)
        let song = TestData.song(serverId: 1, id: "100")
        let playlistOne = LocalPlaylist(id: 10, name: "Snap One", isBookmark: true, contextId: 1)
        let playlistTwo = LocalPlaylist(id: 11, name: "Snap Two", isBookmark: true, contextId: 2)
        XCTAssertTrue(store.add(localPlaylist: playlistOne))
        XCTAssertTrue(store.add(localPlaylist: playlistTwo))
        try store.pool.write { db in
            try Bookmark(id: 1, song: song, localPlaylist: playlistOne, songIndex: 0, offsetInSeconds: 10, offsetInBytes: 1024).save(db)
            try Bookmark(id: 2, song: song, localPlaylist: playlistTwo, songIndex: 0, offsetInSeconds: 20, offsetInBytes: 2048).save(db)
        }

        XCTAssertEqual(store.bookmarks(contextId: 1).map(\.id), [1])
        XCTAssertEqual(store.bookmarks(contextId: 2).map(\.id), [2])
        XCTAssertEqual(store.bookmarksCount(song: song, contextId: 1), 1)
        XCTAssertEqual(store.bookmarksCount(song: song, contextId: 2), 1)
    }
}
