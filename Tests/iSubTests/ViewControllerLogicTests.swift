//
//  ViewControllerLogicTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
import UIKit
@testable import iSub_Beta

// COV-13: unit tests for the pure-ish logic living in (or extracted from) view
// controllers — pagination, ArtistsViewModel, play-queue edit mode, EQ point math,
// visualizer cycling, BassEffectDAO preset flows, server-edit validation, and the
// options-screen mappings.

// MARK: - Search pagination

final class SearchSongsPagingTests: LoaderTestCase {
    private func makeSongs(_ range: Range<Int>) -> [Song] {
        range.map { TestData.song(serverId: 1, id: "\($0)", title: "Song \($0)", path: "a/\($0).mp3") }
    }

    private func makeController(songs: [Song]) -> SearchSongsViewController {
        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }
        let freshPlayQueue = PlayQueue()
        TestContainer.register { freshPlayQueue }
        return SearchSongsViewController(serverId: serverId, query: "beck", searchType: .tag, searchItemType: .songs, songs: songs)
    }

    private func searchResponseXML(songs: Range<Int>) -> String {
        let songElements = songs.map { #"<song id="\#($0)" title="Song \#($0)" path="a/\#($0).mp3" suffix="mp3"/>"# }.joined()
        return #"<subsonic-response status="ok" version="1.15.0"><searchResult3>"# + songElements + "</searchResult3></subsonic-response>"
    }

    @discardableResult
    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return condition()
    }

    func testFullFirstPageSeedsMoreResults() {
        // A full page (20 items) means there may be more; the table shows count+1
        // rows and requesting the extra row triggers the next page load
        let controller = makeController(songs: makeSongs(0..<20))
        MockSubsonicServer.stub(.search3, data: Data(searchResponseXML(songs: 20..<40).utf8))

        let table = UITableView()
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 21, "count + 1 loading row")

        _ = controller.tableView(table, cellForRowAt: IndexPath(row: 20, section: 0))

        XCTAssertTrue(waitUntil { controller.songs.count == 40 }, "the next page is appended")
        let received = MockSubsonicServer.receivedRequests(action: .search3)
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?.parameter("songOffset"), "20", "the offset steps by the page size")
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 41)
    }

    func testShortFirstPageMeansNoMoreResults() {
        // A short page (< 20 items) means the results are exhausted: the extra row
        // is an end marker and requesting it must not trigger a load
        let controller = makeController(songs: makeSongs(0..<5))
        let table = UITableView()

        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 6)
        let cell = controller.tableView(table, cellForRowAt: IndexPath(row: 5, section: 0))

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        XCTAssertEqual(MockSubsonicServer.receivedRequests(action: .search3).count, 0, "no load for a short page")
        XCTAssertEqual(cell.textLabel?.text, "No more search results")
    }

    func testEmptyPageFlipsIsMoreResultsToFalse() {
        let controller = makeController(songs: makeSongs(0..<20))
        MockSubsonicServer.stub(.search3, data: Data(searchResponseXML(songs: 20..<20).utf8))

        let table = UITableView()
        _ = controller.tableView(table, cellForRowAt: IndexPath(row: 20, section: 0))
        XCTAssertTrue(waitUntil { MockSubsonicServer.receivedRequests(action: .search3).count == 1 })
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

        // Requesting the extra row again shows the end marker without another request
        let cell = controller.tableView(table, cellForRowAt: IndexPath(row: 20, section: 0))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        XCTAssertEqual(MockSubsonicServer.receivedRequests(action: .search3).count, 1, "an empty page stops further loads")
        XCTAssertEqual(cell.textLabel?.text, "No more search results")
        XCTAssertEqual(controller.songs.count, 20)
    }
}

// MARK: - Quick albums pagination

final class HomeAlbumPagingTests: LoaderTestCase {
    private func makeAlbums(_ range: Range<Int>) -> [FolderAlbum] {
        range.map { number in
            FolderAlbum(serverId: 1, element: try! XMLTestHelpers.element(tag: "child", xml: "<child id=\"\(number)\" title=\"Album \(number)\" parent=\"0\" created=\"2024-02-24T15:31:22.978Z\"/>"))
        }
    }

    private func albumListXML(_ range: Range<Int>) -> String {
        let albums = range.map { #"<album id="\#($0)" title="Album \#($0)" created="2024-02-24T15:31:22.978Z"/>"# }.joined()
        return #"<subsonic-response status="ok" version="1.15.0"><albumList>"# + albums + "</albumList></subsonic-response>"
    }

    @discardableResult
    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return condition()
    }

    private func makeController(albums: [FolderAlbum]) -> HomeAlbumViewController {
        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }
        freshSettings.currentServer = store.server(id: 1)
        return HomeAlbumViewController(modifier: .newest, folderAlbums: albums, title: "Newest")
    }

    func testFullPageTriggersLoadMoreWithSteppedOffset() {
        let controller = makeController(albums: makeAlbums(0..<20))
        MockSubsonicServer.stub(.getAlbumList, data: Data(albumListXML(20..<40).utf8))

        let table = UITableView()
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 21, "count + 1 loading row")
        _ = controller.tableView(table, cellForRowAt: IndexPath(row: 20, section: 0))

        XCTAssertTrue(waitUntil { controller.folderAlbums.count == 40 })
        let received = MockSubsonicServer.receivedRequests(action: .getAlbumList)
        XCTAssertEqual(received.first?.parameter("offset"), "20", "the offset steps by 20")
    }

    func testShortInitialListShowsEndMarkerWithoutLoading() {
        let controller = makeController(albums: makeAlbums(0..<3))
        let table = UITableView()

        let cell = controller.tableView(table, cellForRowAt: IndexPath(row: 3, section: 0))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        XCTAssertEqual(cell.textLabel?.text, "No more results")
        XCTAssertEqual(MockSubsonicServer.receivedRequests(action: .getAlbumList).count, 0)
    }

    func testEmptyPageFlipsToNoMoreResults() {
        let controller = makeController(albums: makeAlbums(0..<20))
        MockSubsonicServer.stub(.getAlbumList, data: Data(albumListXML(20..<20).utf8))

        let table = UITableView()
        _ = controller.tableView(table, cellForRowAt: IndexPath(row: 20, section: 0))
        XCTAssertTrue(waitUntil { MockSubsonicServer.receivedRequests(action: .getAlbumList).count == 1 })
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

        let cell = controller.tableView(table, cellForRowAt: IndexPath(row: 20, section: 0))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        XCTAssertEqual(cell.textLabel?.text, "No more results")
        XCTAssertEqual(MockSubsonicServer.receivedRequests(action: .getAlbumList).count, 1, "an empty page stops further loads")
        XCTAssertEqual(controller.folderAlbums.count, 20)
    }
}

// MARK: - ArtistsViewModel

final class ArtistsViewModelTests: LoaderTestCase {
    private final class DelegateSpy: ArtistsViewModelDelegate {
        let finishedExpectation = XCTestExpectation(description: "loadingFinished")
        let failedExpectation = XCTestExpectation(description: "loadingFailed")
        private(set) var errors = [Error?]()

        func loadingFinished() { finishedExpectation.fulfill() }
        func loadingFailed(error: Error?) {
            errors.append(error)
            failedExpectation.fulfill()
        }
    }

    func testStartLoadFoldersBranchUsesGetIndexes() throws {
        try MockSubsonicServer.stub(.getMusicFolders, fixture: "XML/getMusicFolders.xml")
        try MockSubsonicServer.stub(.getIndexes, fixture: "XML/getIndexes.xml")

        let delegateSpy = DelegateSpy()
        let model = ArtistsViewModel(serverId: 1, mediaFolderId: MediaFolder.allFoldersId, type: .folders, delegate: delegateSpy)
        model.startLoad()
        wait(for: [delegateSpy.finishedExpectation], timeout: 10)

        XCTAssertEqual(MockSubsonicServer.receivedRequests(action: .getIndexes).count, 1)
        XCTAssertEqual(MockSubsonicServer.receivedRequests(action: .getArtists).count, 0)
        XCTAssertEqual(model.count, 16, "metadata comes from the loaded fixture")
        XCTAssertEqual(model.artistIds.count, 16)
        XCTAssertEqual(model.tableSections.count, 11)
        XCTAssertTrue(model.isCached)
        XCTAssertEqual(model.itemType, "Folder")
        XCTAssertFalse(model.showCoverArt)
    }

    func testStartLoadTagsBranchUsesGetArtists() throws {
        try MockSubsonicServer.stub(.getMusicFolders, fixture: "XML/getMusicFolders.xml")
        try MockSubsonicServer.stub(.getArtists, fixture: "XML/getArtists.xml")

        let delegateSpy = DelegateSpy()
        let model = ArtistsViewModel(serverId: 1, mediaFolderId: MediaFolder.allFoldersId, type: .tags, delegate: delegateSpy)
        model.startLoad()
        wait(for: [delegateSpy.finishedExpectation], timeout: 10)

        XCTAssertEqual(MockSubsonicServer.receivedRequests(action: .getArtists).count, 1)
        XCTAssertEqual(model.count, 29)
        XCTAssertEqual(model.itemType, "Artist")
        XCTAssertTrue(model.showCoverArt)
    }

    func testStartLoadFailureNotifiesDelegate() {
        MockSubsonicServer.stubConnectionError(.getMusicFolders)

        let delegateSpy = DelegateSpy()
        let model = ArtistsViewModel(serverId: 1, mediaFolderId: MediaFolder.allFoldersId, type: .folders, delegate: delegateSpy)
        model.startLoad()
        wait(for: [delegateSpy.failedExpectation], timeout: 10)

        XCTAssertFalse(model.isCached)
    }

    func testIsCachedAndLoadFromCache() throws {
        XCTAssertFalse(ArtistsViewModel(serverId: 1, mediaFolderId: 0, type: .folders).isCached)

        // Seed the cache the way the loader would
        _ = store.add(mediaFolders: [MediaFolder(serverId: 1, id: 0, name: "Music")])
        _ = store.add(folderArtist: FolderArtist(serverId: 1, element: try XMLTestHelpers.element(tag: "artist", xml: #"<artist id="a1" name="Artist"/>"#)), mediaFolderId: 0)
        _ = store.add(folderArtistSection: TableSection(serverId: 1, mediaFolderId: 0, name: "A", position: 0, itemCount: 1))
        _ = store.add(folderArtistListMetadata: RootListMetadata(serverId: 1, mediaFolderId: 0, itemCount: 1, reloadDate: Date()))

        let model = ArtistsViewModel(serverId: 1, mediaFolderId: 0, type: .folders)
        model.reset()

        XCTAssertTrue(model.isCached)
        XCTAssertEqual(model.count, 1)
        XCTAssertEqual(model.artistIds, ["a1"])
        XCTAssertEqual(model.artist(indexPath: IndexPath(row: 0, section: 0))?.name, "Artist")
    }

    func testSectionIndexMapping() throws {
        _ = store.add(mediaFolders: [MediaFolder(serverId: 1, id: 0, name: "Music")])
        // Two sections: A (positions 0-1), B (positions 2-3)
        for (index, name) in ["Alpha", "Apple", "Beta", "Bravo"].enumerated() {
            _ = store.add(folderArtist: FolderArtist(serverId: 1, element: try XMLTestHelpers.element(tag: "artist", xml: "<artist id=\"ar\(index)\" name=\"\(name)\"/>")), mediaFolderId: 0)
        }
        _ = store.add(folderArtistSection: TableSection(serverId: 1, mediaFolderId: 0, name: "A", position: 0, itemCount: 2))
        _ = store.add(folderArtistSection: TableSection(serverId: 1, mediaFolderId: 0, name: "B", position: 2, itemCount: 2))
        _ = store.add(folderArtistListMetadata: RootListMetadata(serverId: 1, mediaFolderId: 0, itemCount: 4, reloadDate: Date()))

        let model = ArtistsViewModel(serverId: 1, mediaFolderId: 0, type: .folders)
        model.reset()

        XCTAssertEqual(model.artist(indexPath: IndexPath(row: 0, section: 0))?.name, "Alpha")
        XCTAssertEqual(model.artist(indexPath: IndexPath(row: 1, section: 0))?.name, "Apple")
        XCTAssertEqual(model.artist(indexPath: IndexPath(row: 0, section: 1))?.name, "Beta", "section positions offset into the flat artist list")
        XCTAssertEqual(model.artist(indexPath: IndexPath(row: 1, section: 1))?.name, "Bravo")
        XCTAssertNil(model.artist(indexPath: IndexPath(row: 5, section: 1)), "out-of-range rows return nil")
    }

    func testMediaFolderIndexFallback() {
        _ = store.add(mediaFolders: [MediaFolder(serverId: 1, id: 0, name: "Music"), MediaFolder(serverId: 1, id: 5, name: "Podcasts")])

        let model = ArtistsViewModel(serverId: 1, mediaFolderId: 5, type: .folders)
        model.reset()
        XCTAssertEqual(model.mediaFolderIndex, 1, "index of the selected media folder in the list")

        model.mediaFolderId = 99
        XCTAssertEqual(model.mediaFolderIndex, MediaFolder.allFoldersId, "unknown folder ids fall back to the All Media Folders sentinel")
    }

    func testFoldersAndArtistsTabsPersistMediaFolderSelectionIndependently_BUG21() throws {
        // BUG-21 regression: ArtistsViewController serves both Library sub-tabs but used
        // to read/write rootFoldersSelectedFolderId for both, cross-contaminating them
        try MockSubsonicServer.stub(.getMusicFolders, fixture: "XML/getMusicFolders.xml")
        try MockSubsonicServer.stub(.getIndexes, fixture: "XML/getIndexes.xml")
        try MockSubsonicServer.stub(.getArtists, fixture: "XML/getArtists.xml")

        let settings = SavedSettings()
        TestContainer.register { settings }

        _ = store.add(mediaFolders: [MediaFolder(serverId: 1, id: 0, name: "Music"),
                                     MediaFolder(serverId: 1, id: 5, name: "Podcasts")])

        let foldersModel = ArtistsViewModel(serverId: 1, mediaFolderId: 0, type: .folders)
        foldersModel.reset()
        let tagsModel = ArtistsViewModel(serverId: 1, mediaFolderId: 0, type: .tags)
        tagsModel.reset()

        let foldersController = ArtistsViewController(dataModel: foldersModel)
        let tagsController = ArtistsViewController(dataModel: tagsModel)
        let menu = DropdownMenu()

        // Pick "Podcasts" on the Folders tab, then "Music" on the Artists tab: the
        // selections must persist independently
        foldersController.dropdownMenu(menu, selectedItemAt: 1)
        XCTAssertEqual(settings.rootFoldersSelectedFolderId, 5)

        tagsController.dropdownMenu(menu, selectedItemAt: 0)
        XCTAssertEqual(settings.rootArtistsSelectedFolderId, 0)
        XCTAssertEqual(settings.rootFoldersSelectedFolderId, 5,
                       "the Artists tab must not overwrite the Folders tab's selection")
    }

    func testIncrementalSearchWithSearchLimit() throws {
        _ = store.add(mediaFolders: [MediaFolder(serverId: 1, id: 0, name: "Music")])
        // 150 artists matching the query: the first page returns the 100-item limit,
        // continueSearch fetches the remaining 50 and then stops
        for number in 0..<150 {
            _ = store.add(folderArtist: FolderArtist(serverId: 1, element: try XMLTestHelpers.element(tag: "artist", xml: "<artist id=\"ar\(number)\" name=\"Match \(number)\"/>")), mediaFolderId: 0)
        }

        let model = ArtistsViewModel(serverId: 1, mediaFolderId: 0, type: .folders)
        model.search(name: "Match")
        XCTAssertEqual(model.searchCount, 100, "the first search page is capped at the search limit")

        model.continueSearch()
        XCTAssertEqual(model.searchCount, 150, "continueSearch appends the next page")
        XCTAssertEqual(model.artistInSearch(indexPath: IndexPath(row: 0, section: 0))?.name, "Match 0")

        // The short second page set shouldContinueSearch = false
        model.continueSearch()
        XCTAssertEqual(model.searchCount, 150, "search stops once a page comes back short")

        model.clearSearch()
        XCTAssertEqual(model.searchCount, 0)
    }
}

// MARK: - Play queue edit mode

final class PlayQueueEditModeTests: StoreTestCase {
    private var controller: PlayQueueViewController!
    private var playQueue: PlayQueue!
    private var table: UITableView!

    override func setUpWithError() throws {
        try super.setUpWithError()
        TestContainer.register { FakePlayer() as PlayerControlling }
        TestContainer.register { FakeStreamManager() as StreamManaging }
        TestContainer.register { FakeDownloadQueue() as DownloadQueueing }
        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }
        let freshPlayQueue = PlayQueue()
        TestContainer.register { freshPlayQueue }
        playQueue = freshPlayQueue

        for number in 1...5 {
            let song = TestData.song(serverId: 1, id: "\(number)", title: "Song \(number)", path: "a/\(number).mp3")
            _ = store.add(song: song)
            _ = store.add(song: song, localPlaylistId: LocalPlaylist.Default.playQueueId)
        }

        controller = PlayQueueViewController()
        table = UITableView()
    }

    override func tearDownWithError() throws {
        controller = nil
        playQueue = nil
        table = nil
        try super.tearDownWithError()
    }

    func testRowCountMatchesQueueAndNumberingIsOneBased() throws {
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 5)

        let firstCell = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? UniversalTableViewCell)
        XCTAssertEqual(firstCell.number, 1, "track numbering is 1-based")
        let lastCell = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 4, section: 0)) as? UniversalTableViewCell)
        XCTAssertEqual(lastCell.number, 5)
    }

    func testMoveRowReordersQueue() {
        playQueue.currentIndex = 0

        controller.tableView(table, moveRowAt: IndexPath(row: 0, section: 0), to: IndexPath(row: 2, section: 0))

        XCTAssertEqual(playQueue.songs().map(\.id), ["2", "3", "1", "4", "5"])
        XCTAssertEqual(playQueue.currentIndex, 2, "the playing song is followed as it moves")
    }

    func testMoveRowInShuffleModeReordersShuffleQueue() {
        // Build the shuffle queue, then reorder within it
        playQueue.normalIndex = 0
        playQueue.shuffleToggle()
        XCTAssertTrue(playQueue.isShuffle)
        let shuffledBefore = playQueue.songs().map(\.id)

        controller.tableView(table, moveRowAt: IndexPath(row: 4, section: 0), to: IndexPath(row: 1, section: 0))

        var expected = shuffledBefore
        let moved = expected.remove(at: 4)
        expected.insert(moved, at: 1)
        XCTAssertEqual(playQueue.songs().map(\.id), expected, "shuffle-mode edits reorder the shuffle queue")

        // The normal queue is untouched
        playQueue.isShuffle = false
        XCTAssertEqual(playQueue.songs().map(\.id), ["1", "2", "3", "4", "5"])
    }

    func testEditingConfiguration() {
        XCTAssertTrue(controller.tableView(table, canEditRowAt: IndexPath(row: 0, section: 0)))
        XCTAssertTrue(controller.tableView(table, canMoveRowAt: IndexPath(row: 0, section: 0)))
        XCTAssertEqual(controller.tableView(table, editingStyleForRowAt: IndexPath(row: 0, section: 0)), .delete)
    }
}

// MARK: - EqualizerPointView math

final class EqualizerPointViewTests: XCTestCase {
    private let parentSize = CGSize(width: 300, height: 200)

    func testFrequencyAndGainFromPosition() {
        // x=0 → 2^5 = 32 Hz; x=1 → 2^14 = 16384 Hz; y=0.5 → 0 gain
        let bottomLeft = EqualizerPointView(point: CGPoint(x: 0, y: 0.5), parentSize: parentSize)
        XCTAssertEqual(bottomLeft.frequency, 32, accuracy: 0.01)
        XCTAssertEqual(bottomLeft.gain, 0, accuracy: 0.001)

        let topRight = EqualizerPointView(point: CGPoint(x: 1, y: 0), parentSize: parentSize)
        XCTAssertEqual(topRight.frequency, 16384, accuracy: 0.5)
        XCTAssertEqual(topRight.gain, 6, accuracy: 0.001, "the top edge is +MAX_GAIN")

        let bottom = EqualizerPointView(point: CGPoint(x: 0.5, y: 1), parentSize: parentSize)
        XCTAssertEqual(bottom.gain, -6, accuracy: 0.001, "the bottom edge is -MAX_GAIN")
    }

    func testPositionFromEqValueRoundTrip() {
        let parameters = BASS_DX8_PARAMEQ(fCenter: 1024, fBandwidth: 18, fGain: 3)
        let view = EqualizerPointView(eqValue: BassParamEqValue(parameters: parameters), parentSize: parentSize)

        // 1024 Hz = 2^10 → x = (10-5)/9; gain 3 → y = 0.5 - 3/12
        XCTAssertEqual(view.position.x, CGFloat((10.0 - 5.0) / 9.0), accuracy: 0.001)
        XCTAssertEqual(view.position.y, 0.25, accuracy: 0.001)

        // And back out through the computed properties
        XCTAssertEqual(view.frequency, 1024, accuracy: 0.5)
        XCTAssertEqual(view.gain, 3, accuracy: 0.01)
        XCTAssertEqual(view.eqValue.frequency, 1024, accuracy: 0.5)
        XCTAssertEqual(view.eqValue.gain, 3, accuracy: 0.01)
        XCTAssertEqual(view.eqValue.bandwidth, 18)
    }

    func testMovingCenterUpdatesPositionAndValues() {
        let view = EqualizerPointView(point: CGPoint(x: 0, y: 0.5), parentSize: parentSize)

        // Drag to the center of the parent
        view.center = CGPoint(x: parentSize.width / 2, y: parentSize.height / 2)

        XCTAssertEqual(view.position.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(view.position.y, 0.5, accuracy: 0.001)
        XCTAssertEqual(view.frequency, exp2f(0.5 * 9 + 5), accuracy: 0.5)
        XCTAssertEqual(view.gain, 0, accuracy: 0.001)
    }
}

// MARK: - Visualizer type cycling

final class VisualizerTypeCyclingTests: XCTestCase {
    func testNextCyclesThroughAllTypesSkippingMaxValue() {
        XCTAssertEqual(VisualizerType.none.next, .line)
        XCTAssertEqual(VisualizerType.line.next, .skinnyBar)
        XCTAssertEqual(VisualizerType.skinnyBar.next, .fatBar)
        XCTAssertEqual(VisualizerType.fatBar.next, .aphexFace)
        XCTAssertEqual(VisualizerType.aphexFace.next, .none, "cycles back to the start instead of hitting maxValue")
    }

    func testPreviousCyclesBackwardsWrappingToLastRealType() {
        XCTAssertEqual(VisualizerType.aphexFace.previous, .fatBar)
        XCTAssertEqual(VisualizerType.line.previous, .none)
        XCTAssertEqual(VisualizerType.none.previous, .aphexFace, "wraps to the last real type, not maxValue")
    }

    func testCyclingFromTheMaxValueSentinelDoesNotCrash_BUG27() {
        // A bad persisted setting can land on the maxValue sentinel; cycling from it
        // used to force-unwrap VisualizerType(rawValue: 5+1) and crash
        XCTAssertEqual(VisualizerType.maxValue.next, .none, "out-of-range values normalize to .none")
        XCTAssertEqual(VisualizerType.maxValue.previous, .aphexFace, "previous from the sentinel lands on the last real type")
    }
}

// MARK: - BassEffectDAO preset flows

final class BassEffectDAOPresetFlowTests: SandboxedTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        UserDefaults.standard.removeObject(forKey: "BassEffectSelectedPresetId")
        UserDefaults.standard.removeObject(forKey: "BassEffectUserPresets")
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.removeObject(forKey: "BassEffectSelectedPresetId")
        UserDefaults.standard.removeObject(forKey: "BassEffectUserPresets")
        try super.tearDownWithError()
    }

    func testSaveCustomPresetAllocatesUserPresetIdAndSelects() {
        let dao = BassEffectDAO(type: .parametricEQ)
        let defaultCount = dao.presets.count

        dao.saveCustomPreset(name: "My Preset", points: [CGPoint(x: 0.25, y: 0.4), CGPoint(x: 0.75, y: 0.6)])

        XCTAssertEqual(dao.presets.count, defaultCount + 1)
        XCTAssertEqual(dao.selectedPresetId, BassEffectDAO.bassEffectUserPresetStartId, "the first user preset gets the start id")
        XCTAssertEqual(dao.selectedPreset?.name, "My Preset")
        XCTAssertEqual(dao.selectedPreset?.values.count, 2)
        XCTAssertEqual(dao.userPresets.count, 1)
        XCTAssertEqual(dao.userPresetsMinusCustom.count, 1)

        // A second preset gets the next id
        dao.saveCustomPreset(name: "Another", points: [CGPoint(x: 0.5, y: 0.5)])
        XCTAssertEqual(dao.selectedPresetId, BassEffectDAO.bassEffectUserPresetStartId + 1)
    }

    func testSaveTempCustomPresetUsesReservedIdAndName() {
        let dao = BassEffectDAO(type: .parametricEQ)

        dao.saveTempCustomPreset(points: [CGPoint(x: 0.1, y: 0.9)])

        XCTAssertEqual(dao.selectedPresetId, BassEffectDAO.bassEffectTempCustomPresetId)
        XCTAssertEqual(dao.selectedPreset?.name, "Custom")
        XCTAssertEqual(dao.userPresets.count, 1)
        XCTAssertEqual(dao.userPresetsMinusCustom.count, 0, "the temp custom preset is excluded from the named user presets")

        dao.deleteTempCustomPreset()
        XCTAssertEqual(dao.userPresets.count, 0)
        XCTAssertEqual(dao.selectedPresetId, 0, "deleting the selected preset falls back to preset 0")
    }

    func testDeleteCustomPreset() {
        let dao = BassEffectDAO(type: .parametricEQ)
        dao.saveCustomPreset(name: "Keep", points: [CGPoint(x: 0.5, y: 0.5)])
        dao.saveCustomPreset(name: "Delete Me", points: [CGPoint(x: 0.5, y: 0.5)])
        let deleteId = dao.selectedPresetId

        dao.deleteCustomPreset(id: deleteId)

        XCTAssertEqual(dao.userPresets.count, 1)
        XCTAssertEqual(dao.userPresets.first?.name, "Keep")
        XCTAssertEqual(dao.selectedPresetId, 0, "deleting the selected preset resets the selection")
    }

    func testPresetsPersistAcrossInstances() {
        BassEffectDAO(type: .parametricEQ).saveCustomPreset(name: "Persisted", points: [CGPoint(x: 0.3, y: 0.3)])

        let rehydrated = BassEffectDAO(type: .parametricEQ)
        XCTAssertEqual(rehydrated.userPresets.first?.name, "Persisted")
        XCTAssertEqual(rehydrated.selectedPreset?.name, "Persisted")
        XCTAssertEqual(rehydrated.userPresets.first?.values.first, CGPoint(x: 0.3, y: 0.3))
    }
}

// MARK: - Server edit validation

final class ServerEditValidationTests: SandboxedTestCase {
    private var controller: ServerEditViewController!

    override func setUpWithError() throws {
        try super.setUpWithError()
        controller = ServerEditViewController()
    }

    override func tearDownWithError() throws {
        controller = nil
        try super.tearDownWithError()
    }

    func testCheckURLRejectsEmpty() {
        controller.urlField.text = ""
        XCTAssertFalse(controller.checkURL())
        controller.urlField.text = nil
        XCTAssertFalse(controller.checkURL())
    }

    func testCheckURLAddsHTTPSchemeWhenMissing() {
        controller.urlField.text = "music.example.com"
        XCTAssertTrue(controller.checkURL())
        XCTAssertEqual(controller.urlField.text, "http://music.example.com")
    }

    func testCheckURLKeepsExistingScheme() {
        controller.urlField.text = "https://music.example.com"
        XCTAssertTrue(controller.checkURL())
        XCTAssertEqual(controller.urlField.text, "https://music.example.com")

        controller.urlField.text = "http://music.example.com:4040/subsonic"
        XCTAssertTrue(controller.checkURL())
        XCTAssertEqual(controller.urlField.text, "http://music.example.com:4040/subsonic")
    }

    func testCheckURLStripsTrailingSlash() {
        controller.urlField.text = "https://music.example.com/"
        XCTAssertTrue(controller.checkURL())
        XCTAssertEqual(controller.urlField.text, "https://music.example.com")
    }

    func testCheckUsernameAndPasswordRequireText() {
        controller.usernameField.text = ""
        XCTAssertFalse(controller.checkUsername())
        controller.usernameField.text = "bbaron"
        XCTAssertTrue(controller.checkUsername())

        controller.passwordField.text = nil
        XCTAssertFalse(controller.checkPassword())
        controller.passwordField.text = "secret"
        XCTAssertTrue(controller.checkPassword())
    }
}

// MARK: - Options screen mappings

final class OptionsMappingTests: XCTestCase {
    func testQuickSkipSecondsToSegmentMapping() {
        let expected = [5, 15, 30, 45, 60, 120, 300, 600, 1200]
        for (index, seconds) in expected.enumerated() {
            XCTAssertEqual(QuickSkipMapping.segmentIndex(seconds: seconds), index)
            XCTAssertEqual(QuickSkipMapping.seconds(segmentIndex: index), seconds)
        }
        XCTAssertNil(QuickSkipMapping.segmentIndex(seconds: 999), "unknown values leave the control unchanged")
        XCTAssertNil(QuickSkipMapping.seconds(segmentIndex: 9))
        XCTAssertNil(QuickSkipMapping.seconds(segmentIndex: -1))
    }

    func testCacheSliderMidRangePassesThrough() {
        let totalSpace = 1_000_000_000
        let freeSpace = 500_000_000
        let result = CacheSpaceSliderMath.spaceSetting(sliderValue: 0.2, totalSpace: totalSpace, freeSpace: freeSpace)
        XCTAssertEqual(result.bytes, Int(0.2 * Float(totalSpace)))
        XCTAssertNil(result.clampedSliderValue, "in-range values don't move the slider")
    }

    func testCacheSliderClampsToFreeSpaceMinusReserve() {
        let totalSpace = 1_000_000_000
        let freeSpace = 300_000_000
        let result = CacheSpaceSliderMath.spaceSetting(sliderValue: 0.9, totalSpace: totalSpace, freeSpace: freeSpace)
        XCTAssertEqual(result.bytes, freeSpace - CacheSpaceSliderMath.reservedBytes, "can't reserve more than the free space minus 50MB")
        XCTAssertEqual(result.clampedSliderValue ?? -1, Float(result.bytes) / Float(totalSpace), accuracy: 0.0001)
    }

    func testCacheSliderClampsUpToFiftyMegabytes() {
        let totalSpace = 1_000_000_000
        let freeSpace = 500_000_000
        let result = CacheSpaceSliderMath.spaceSetting(sliderValue: 0.001, totalSpace: totalSpace, freeSpace: freeSpace)
        XCTAssertEqual(result.bytes, CacheSpaceSliderMath.reservedBytes, "the floor is 50MB")
        XCTAssertNotNil(result.clampedSliderValue)
    }
}

// MARK: - Download queue tab appearance

final class DownloadQueueViewControllerTests: StoreTestCase {
    func testViewWillAppearReloadsTableAndShowsEditHeader_BUG22() {
        // BUG-22 regression: viewWillAppear never called super, skipping the base
        // class's registerForNotifications()/reloadTable(), so the queue tab neither
        // refreshed nor showed its edit header on appear
        TestContainer.register { FakeDownloadQueue() as DownloadQueueing }
        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }

        let song = TestData.song(serverId: 1, id: "1", title: "Queued", path: "a/1.mp3")
        _ = store.add(song: song)
        XCTAssertTrue(store.addToDownloadQueue(song: song))

        let controller = DownloadQueueViewController()
        controller.loadViewIfNeeded()
        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()

        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 0), 1, "the queue loads on appear")
        XCTAssertNotNil(controller.saveEditHeader.superview, "the edit header appears when the queue has items")

        // The base class's notification registrations must be live: finishing a download
        // elsewhere reloads this table (observed through the download-deleted path)
        _ = store.removeFromDownloadQueue(song: song)
        NotificationCenter.postOnMainThread(name: Notifications.downloadQueueSongRemoved)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 0), 0)
        XCTAssertNil(controller.saveEditHeader.superview, "the edit header hides when the queue empties")
    }
}
