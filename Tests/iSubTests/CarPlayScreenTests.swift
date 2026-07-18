//
//  CarPlayScreenTests.swift
//  iSubTests
//
//  Created by Ben Baron on 7/18/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// The CarPlay screens are CP-free section builders over the Store, so their row
// content, tap payloads, offline filtering, and video filtering are all assertable
// without a car session.
final class CarPlayScreenTests: StoreTestCase {
    private var session: ServerSession!
    private var settings: SavedSettings!
    private var playQueue: PlayQueue!

    override func setUpWithError() throws {
        try super.setUpWithError()
        session = ServerSession()
        let settings = SavedSettings(session: session)
        settings.setup(store: store)
        TestContainer.register { settings }
        self.settings = settings

        let playQueue = makeTestPlayQueue()
        TestContainer.register { playQueue }
        self.playQueue = playQueue
    }

    override func tearDownWithError() throws {
        session = nil
        settings = nil
        playQueue = nil
        try super.tearDownWithError()
    }

    private func configureServer() {
        let server = TestData.server(id: 1)
        XCTAssertTrue(store.add(server: server))
        settings.currentServer = server
    }

    private func seedFolder(parentFolderId: String) {
        let albumA = FolderAlbum(serverId: 1, element: try! XMLTestHelpers.element(tag: "child", xml: "<child id=\"100\" title=\"Odelay\" parent=\"\(parentFolderId)\" created=\"2024-02-24T15:31:22.978Z\"/>"))
        let albumB = FolderAlbum(serverId: 1, element: try! XMLTestHelpers.element(tag: "child", xml: "<child id=\"101\" title=\"Midnite Vultures\" parent=\"\(parentFolderId)\" created=\"2024-02-24T15:31:22.978Z\"/>"))
        XCTAssertTrue(store.add(folderAlbum: albumA))
        XCTAssertTrue(store.add(folderAlbum: albumB))

        let song1 = TestData.song(id: "s1", title: "First Song", path: "A/1.mp3", parentFolderId: parentFolderId, track: 1)
        let song2 = TestData.song(id: "s2", title: "Second Song", path: "A/2.mp3", parentFolderId: parentFolderId, track: 2)
        let video = TestData.song(id: "s3", title: "Some Video", path: "A/3.mp4", parentFolderId: parentFolderId, isVideo: true)
        XCTAssertTrue(store.add(folderSong: song1))
        XCTAssertTrue(store.add(folderSong: song2))
        XCTAssertTrue(store.add(folderSong: video))

        XCTAssertTrue(store.add(folderMetadata: FolderMetadata(serverId: 1, parentFolderId: parentFolderId, folderCount: 2, songCount: 3, duration: 720)))
    }

    // MARK: Library root

    func testLibraryRootRequiresServer() {
        let screen = CarPlayLibraryRootScreen()
        XCTAssertTrue(screen.sections().isEmpty)
        XCTAssertEqual(screen.emptyState().title, "Set Up iSub")

        configureServer()
        let rows = screen.sections().flatMap { $0.rows }
        XCTAssertEqual(rows.map { $0.title }, ["Folders", "Artists", "Bookmarks"])
    }

    // MARK: Folder contents

    func testFolderContentsSectionsAndVideoFiltering() {
        configureServer()
        seedFolder(parentFolderId: "10")

        let screen = CarPlayFolderContentsScreen(serverId: 1, parentFolderId: "10", title: "Beck")
        let sections = screen.sections()
        XCTAssertEqual(sections.count, 3, "expected play/shuffle, albums, and songs sections")

        XCTAssertEqual(sections[0].rows.map { $0.title }, ["Play All", "Shuffle"])
        XCTAssertEqual(sections[1].header, "Albums")
        XCTAssertEqual(sections[1].rows.map { $0.title }, ["Odelay", "Midnite Vultures"])
        XCTAssertEqual(sections[2].header, "Songs")
        // The video row must not appear, and the tap payload's id list must be the
        // same filtered list so positions stay aligned
        XCTAssertEqual(sections[2].rows.count, 2)

        guard case .playSongIds(let songIds, let serverId, let position, let shuffled) = sections[2].rows[1].action else {
            return XCTFail("song row should carry a playSongIds action")
        }
        XCTAssertEqual(songIds, ["s1", "s2"])
        XCTAssertEqual(serverId, 1)
        XCTAssertEqual(position, 1)
        XCTAssertFalse(shuffled)

        // Online, play-all uses the recursive gather like the phone's header
        guard case .playAllRecursive(_, let folderId, let idType, _) = sections[0].rows[0].action else {
            return XCTFail("play all should be recursive while online")
        }
        XCTAssertEqual(folderId, "10")
        XCTAssertEqual(idType, .folder)
    }

    func testFolderContentsOfflineDisablesUncachedRows() {
        configureServer()
        seedFolder(parentFolderId: "10")
        settings.isOfflineMode = true

        let screen = CarPlayFolderContentsScreen(serverId: 1, parentFolderId: "10", title: "Beck")
        let sections = screen.sections()

        // Albums aren't cached (no folderMetadata for 100/101) and songs aren't
        // downloaded, so every row is disabled offline
        XCTAssertTrue(sections[1].rows.allSatisfy { !$0.isEnabled })
        XCTAssertTrue(sections[2].rows.allSatisfy { !$0.isEnabled })

        // Offline play-all only plays this folder's songs instead of recursing
        guard case .playSongIds = sections[0].rows[0].action else {
            return XCTFail("play all should not be recursive while offline")
        }
    }

    // MARK: Play queue

    func testPlayQueueScreenRowsAndCurrentSong() {
        configureServer()
        for number in 1...3 {
            let song = TestData.song(id: "\(number)", title: "Song \(number)", path: "A/\(number).mp3")
            XCTAssertTrue(store.add(song: song))
            XCTAssertTrue(store.add(song: song, localPlaylistId: LocalPlaylist.Default.playQueueId))
        }
        playQueue.currentIndex = 1

        let screen = CarPlayPlayQueueScreen()
        let rows = screen.sections().flatMap { $0.rows }
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows.map { $0.isPlaying }, [false, true, false])

        guard case .playQueuePosition(let position) = rows[2].action else {
            return XCTFail("queue row should carry a playQueuePosition action")
        }
        XCTAssertEqual(position, 2)
    }

    // MARK: Playlists

    func testLocalPlaylistsExcludeInternalQueues() {
        configureServer()
        XCTAssertTrue(store.add(localPlaylist: LocalPlaylist(id: 5, name: "Road Trip")))

        let screen = CarPlayLocalPlaylistsScreen()
        let rows = screen.sections().flatMap { $0.rows }
        XCTAssertEqual(rows.map { $0.title }, ["Road Trip"],
                       "the internal play/shuffle/jukebox queues (ids 1-4) must not appear")
    }

    // MARK: Downloads

    func testDownloadsRootEmptyWithoutDownloads() {
        configureServer()
        let screen = CarPlayDownloadsRootScreen()
        XCTAssertTrue(screen.sections().isEmpty)
        XCTAssertEqual(screen.emptyState().title, "No Downloaded Songs")
    }

    func testDownloadsRootShowsBranchesWithDownloads() {
        configureServer()
        let song = TestData.song(id: "d1", title: "Kept Song", path: "Artist/Album/1.mp3")
        XCTAssertTrue(store.add(song: song))
        var downloaded = DownloadedSong(song: song)
        downloaded.isFinished = true
        XCTAssertTrue(store.add(downloadedSong: downloaded))
        XCTAssertTrue(store.update(downloadFinished: true, song: song))

        let rows = CarPlayDownloadsRootScreen().sections().flatMap { $0.rows }
        XCTAssertEqual(rows.map { $0.title }, ["Folders", "Artists", "Albums", "Songs"])
    }

    // MARK: Clamping

    func testClampedSectionsTruncateToBudget() {
        let sections = [
            CarPlaySection(rows: (0..<20).map { CarPlayRow(title: "Row \($0)", action: .custom(handler: { $0() })) }),
            CarPlaySection(rows: (20..<30).map { CarPlayRow(title: "Row \($0)", action: .custom(handler: { $0() })) }),
        ]

        let (clamped, truncated) = CarPlayItemFactory.clamped(sections: sections, maxSections: 2, maxItems: 10)
        // One item and one section are reserved for the "Showing first N" note
        XCTAssertEqual(clamped.count, 1)
        XCTAssertEqual(clamped[0].rows.count, 9)
        XCTAssertEqual(truncated, 21)
    }

    func testClampedSectionsPassThroughWhenUnderLimits() {
        let sections = [CarPlaySection(rows: (0..<5).map { CarPlayRow(title: "Row \($0)", action: .custom(handler: { $0() })) })]
        let (clamped, truncated) = CarPlayItemFactory.clamped(sections: sections, maxSections: 10, maxItems: 100)
        XCTAssertEqual(clamped[0].rows.count, 5)
        XCTAssertEqual(truncated, 0)
    }
}
