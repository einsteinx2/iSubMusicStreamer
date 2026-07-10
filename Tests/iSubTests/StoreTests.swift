//
//  StoreTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
import GRDB
@testable import iSub_Beta

final class StoreTests: SandboxedTestCase {
    // Every table created by the initialSchema migration
    private let expectedTables = [
        Server.databaseTableName,
        CoverArt.databaseTableName,
        ArtistArt.databaseTableName,
        Lyrics.databaseTableName,
        MediaFolder.databaseTableName,
        TagArtist.databaseTableName,
        TagAlbum.databaseTableName,
        FolderArtist.databaseTableName,
        FolderAlbum.databaseTableName,
        FolderMetadata.databaseTableName,
        Song.databaseTableName,
        DownloadedSong.databaseTableName,
        DownloadedSongPathComponent.databaseTableName,
        LocalPlaylist.databaseTableName,
        ServerPlaylist.databaseTableName,
        Bookmark.databaseTableName,
    ]

    private func assertSchemaExists(in store: Store, file: StaticString = #filePath, line: UInt = #line) throws {
        let pool = try XCTUnwrap(store.pool, "database not initialized", file: file, line: line)
        try pool.read { db in
            for table in expectedTables {
                XCTAssertTrue(try db.tableExists(table), "missing table \(table)", file: file, line: line)
            }
        }
    }

    func testInMemoryStoreMigratesSchema() throws {
        let store = Store()
        store.setup(location: .memory)
        XCTAssertTrue(store.pool is DatabaseQueue)
        try assertSchemaExists(in: store)
    }

    func testTempFileStoreMigratesSchema() throws {
        let url = sandbox.root.appendingPathComponent("test.db")
        let store = Store()
        store.setup(location: .file(url))
        XCTAssertTrue(store.pool is DatabasePool)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        try assertSchemaExists(in: store)
    }

    func testProductionLocationUsesDatabaseDirectory() throws {
        // FileSystem is sandboxed by SandboxedTestCase, so .production writes into the sandbox
        let store = Store()
        store.setup(location: .production)
        let dbPath = FileSystem.databaseDirectory.appendingPathComponent("iSub.db").path
        XCTAssertTrue(dbPath.hasPrefix(sandbox.root.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dbPath))
        try assertSchemaExists(in: store)
    }

    func testMigrateIsIdempotentAcrossReopens() throws {
        let url = sandbox.root.appendingPathComponent("reopen.db")
        let first = Store()
        first.setup(location: .file(url))
        try assertSchemaExists(in: first)

        // Reopening the same file re-runs the migrator, which must skip completed migrations
        let second = Store()
        second.setup(location: .file(url))
        try assertSchemaExists(in: second)
    }
}
