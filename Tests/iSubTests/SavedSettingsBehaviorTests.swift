//
//  SavedSettingsBehaviorTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// COV-09: SavedSettings behavior — bitrate mapping, wrapper semantics, per-server
// keys, current-server bookkeeping, isRecover derivation, and the
// createDirectoryIfNotExists guard (BUG-26).
final class SavedSettingsBehaviorTests: StoreTestCase {
    private var settings: SavedSettings!
    private var player: FakePlayer!
    private var network: FakeNetworkStatus!
    private var stateRestorer: StateRestorer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        player = FakePlayer()
        let fakePlayer = player!
        TestContainer.register { fakePlayer as PlayerControlling }
        network = FakeNetworkStatus()
        let fakeNetwork = network!
        let freshSettings = SavedSettings()
        freshSettings.attach(networkStatus: fakeNetwork)
        TestContainer.register { freshSettings }
        settings = freshSettings
        let freshPlayQueue = makeTestPlayQueue()
        TestContainer.register { freshPlayQueue }
        stateRestorer = StateRestorer(settings: freshSettings, player: fakePlayer, playQueue: freshPlayQueue)
    }

    override func tearDownWithError() throws {
        stateRestorer = nil
        settings = nil
        player = nil
        network = nil
        try super.tearDownWithError()
    }

    // MARK: currentMaxBitrate

    func testCurrentMaxBitrateMapping() {
        let expected: [(setting: Int, kiloBitrate: Int)] = [
            (0, 64), (1, 96), (2, 128), (3, 160), (4, 192), (5, 256), (6, 320),
        ]
        for (setting, kiloBitrate) in expected {
            // On wifi only the wifi setting is read
            network.isWifi = true
            settings.maxBitrateWifi = setting
            settings.maxBitrate3G = 7
            XCTAssertEqual(settings.currentMaxBitrate, kiloBitrate, "wifi setting \(setting) should map to \(kiloBitrate) Kbps")

            // On cellular only the 3G setting is read
            network.isWifi = false
            settings.maxBitrateWifi = 7
            settings.maxBitrate3G = setting
            XCTAssertEqual(settings.currentMaxBitrate, kiloBitrate, "3G setting \(setting) should map to \(kiloBitrate) Kbps")
        }
    }

    func testCurrentMaxBitrateOutOfRangeMeansUnlimited() {
        // 7 is the "Unlimited" slider position and maps to 0 (no cap)
        network.isWifi = true
        settings.maxBitrateWifi = 7
        XCTAssertEqual(settings.currentMaxBitrate, 0)
        settings.maxBitrateWifi = 99
        XCTAssertEqual(settings.currentMaxBitrate, 0)

        network.isWifi = false
        settings.maxBitrate3G = 7
        XCTAssertEqual(settings.currentMaxBitrate, 0)
        settings.maxBitrate3G = 99
        XCTAssertEqual(settings.currentMaxBitrate, 0)
    }

    func testCurrentMaxBitrateDefaultIsUnlimited() {
        XCTAssertEqual(settings.maxBitrateWifi, 7)
        XCTAssertEqual(settings.maxBitrate3G, 7)
        XCTAssertEqual(settings.currentMaxBitrate, 0)
    }

    // MARK: currentVideoBitrates

    func testCurrentVideoBitratesArraysOnWifi() {
        network.isWifi = true
        let expectedByLevel: [Int: [String]] = [
            0: ["512"],
            1: ["1024", "512"],
            2: ["1536", "1024", "512"],
            3: ["2048", "1536", "1024", "512"],
            4: ["4096", "2048", "1536", "1024", "512"],
            5: ["8192@1920x1080", "4096", "2048", "1536", "1024", "512"],
        ]

        for (level, expected) in expectedByLevel {
            settings.maxVideoBitrateWifi = level
            XCTAssertEqual(settings.currentVideoBitrates, expected, "wifi video bitrate level \(level)")
        }

        // Out-of-range levels return nil (no bitrate restriction parameter)
        settings.maxVideoBitrateWifi = 9
        XCTAssertNil(settings.currentVideoBitrates)
    }

    func testCurrentVideoBitratesArraysOnCellular() {
        network.isWifi = false
        let expectedByLevel: [Int: [String]] = [
            0: ["192"],
            1: ["512", "192"],
            2: ["1024", "512", "192"],
            3: ["1536", "1024", "512", "192"],
            4: ["2048", "1536", "1024", "512", "192"],
            5: ["4096", "2048", "1536", "1024", "512", "192"],
        ]

        for (level, expected) in expectedByLevel {
            settings.maxVideoBitrate3G = level
            XCTAssertEqual(settings.currentVideoBitrates, expected, "3G video bitrate level \(level)")
        }

        // Out-of-range levels return nil (no bitrate restriction parameter)
        settings.maxVideoBitrate3G = 9
        XCTAssertNil(settings.currentVideoBitrates)
    }

    // MARK: @UserDefault wrapper semantics

    func testWrapperReturnsDefaultUntilPersisted() {
        XCTAssertEqual(settings.recoverSetting, 0)
        XCTAssertEqual(settings.scrobblePercent, 0.5, accuracy: 0.0001)
        XCTAssertTrue(settings.isScreenSleepEnabled)
        XCTAssertFalse(settings.isJukeboxEnabled)
    }

    func testWrapperPersistsToInjectedSuite() {
        settings.recoverSetting = 1
        settings.scrobblePercent = 0.75
        settings.isScreenSleepEnabled = false

        XCTAssertEqual(testDefaults.integer(forKey: SavedSettings.Key.recoverSetting.rawValue), 1)
        XCTAssertEqual(testDefaults.float(forKey: SavedSettings.Key.scrobblePercentSetting.rawValue), 0.75, accuracy: 0.0001)
        XCTAssertFalse(testDefaults.bool(forKey: SavedSettings.Key.isScreenSleepEnabled.rawValue))
    }

    func testWrapperValuesSharedAcrossInstances() {
        settings.recoverSetting = 2
        let otherInstance = SavedSettings()
        XCTAssertEqual(otherInstance.recoverSetting, 2, "all instances read the same backing store")
    }

    // MARK: currentServer

    func testCurrentServerDidSetWritesId() {
        let server = TestData.server(id: 3)
        _ = store.add(server: server)

        settings.currentServer = server

        XCTAssertEqual(testDefaults.object(forKey: SavedSettings.Key.currentServerId.rawValue) as? Int, 3)
        XCTAssertEqual(settings.currentServerId, 3)
    }

    func testCurrentServerIdIsMinusOneWithoutServer() {
        XCTAssertNil(settings.currentServer)
        XCTAssertEqual(settings.currentServerId, -1)
    }

    // MARK: Per-server media folder selection

    func testSelectedFolderIdsAreKeyedPerServer() {
        let serverOne = TestData.server(id: 1)
        let serverTwo = TestData.server(id: 2, urlString: "http://two.example.com")
        _ = store.add(server: serverOne)
        _ = store.add(server: serverTwo)

        settings.currentServer = serverOne
        XCTAssertEqual(settings.rootFoldersSelectedFolderId, MediaFolder.allFoldersId, "defaults to All Media Folders")
        XCTAssertEqual(settings.rootArtistsSelectedFolderId, MediaFolder.allFoldersId)
        settings.rootFoldersSelectedFolderId = 5
        settings.rootArtistsSelectedFolderId = 7

        settings.currentServer = serverTwo
        XCTAssertEqual(settings.rootFoldersSelectedFolderId, MediaFolder.allFoldersId, "server 2 starts fresh")
        XCTAssertEqual(settings.rootArtistsSelectedFolderId, MediaFolder.allFoldersId)
        settings.rootFoldersSelectedFolderId = 9

        settings.currentServer = serverOne
        XCTAssertEqual(settings.rootFoldersSelectedFolderId, 5, "server 1's selection is remembered")
        XCTAssertEqual(settings.rootArtistsSelectedFolderId, 7)

        settings.currentServer = serverTwo
        XCTAssertEqual(settings.rootFoldersSelectedFolderId, 9)
    }

    func testFoldersAndArtistsSelectionsAreIndependent() {
        let server = TestData.server(id: 1)
        _ = store.add(server: server)
        settings.currentServer = server

        settings.rootFoldersSelectedFolderId = 4
        XCTAssertEqual(settings.rootArtistsSelectedFolderId, MediaFolder.allFoldersId, "folders selection must not leak into artists selection")
        settings.rootArtistsSelectedFolderId = 8
        XCTAssertEqual(settings.rootFoldersSelectedFolderId, 4)
    }

    // MARK: isRecover derivation

    func testIsRecoverSetWhenPlayingAndRecoverSettingZero() {
        player.isPlaying = true
        settings.recoverSetting = 0

        stateRestorer.saveState()

        XCTAssertTrue(settings.isRecover)
    }

    func testIsRecoverFalseWhenRecoverSettingIsOne() {
        player.isPlaying = true
        settings.recoverSetting = 1
        // recoverSetting is captured during loadState
        stateRestorer.loadState()

        stateRestorer.saveState()

        XCTAssertFalse(settings.isRecover)
    }

    func testIsRecoverFalseWhenNotPlaying() {
        player.isPlaying = false
        settings.recoverSetting = 0

        stateRestorer.saveState()

        XCTAssertFalse(settings.isRecover)
    }

    // MARK: createDirectoryIfNotExists (BUG-26)

    func testCreateDirectoryIfNotExistsCreatesMissingDirectory_BUG26() {
        let path = sandbox.root.appendingPathComponent("brand-new-directory").path
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))

        settings.createDirectoryIfNotExists(path: path)

        XCTAssertTrue(FileManager.default.fileExists(atPath: path), "the missing directory must be created")
    }

    func testCreateDirectoryIfNotExistsLeavesExistingDirectoryAlone() throws {
        let url = sandbox.root.appendingPathComponent("existing-directory")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let marker = url.appendingPathComponent("marker.txt")
        try Data("content".utf8).write(to: marker)

        settings.createDirectoryIfNotExists(path: url.path)

        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path), "existing contents must be untouched")
    }
}

// Phase 8.1: ServerSession owns the server-session state directly; SavedSettings
// forwards to it. These cover the session type itself plus the forwarding contract.
final class ServerSessionTests: StoreTestCase {
    func testCurrentServerDidSetWritesId() {
        let session = ServerSession()
        let server = TestData.server(id: 5)
        _ = store.add(server: server)

        session.currentServer = server

        XCTAssertEqual(testDefaults.object(forKey: SavedSettings.Key.currentServerId.rawValue) as? Int, 5)
        XCTAssertEqual(session.currentServerId, 5)
    }

    func testSetupLoadsPersistedServerFromStore() {
        let server = TestData.server(id: 7)
        _ = store.add(server: server)
        testDefaults.set(7, forKey: SavedSettings.Key.currentServerId.rawValue)

        let session = ServerSession()
        session.setup(store: store)

        XCTAssertEqual(session.currentServer?.id, 7)
        XCTAssertEqual(session.currentServerId, 7)
    }

    func testSetupWithoutPersistedIdLeavesServerNil() {
        let session = ServerSession()
        session.setup(store: store)
        XCTAssertNil(session.currentServer)
        XCTAssertEqual(session.currentServerId, -1)
    }

    func testSavedSettingsForwardsToOwnedSession() {
        let session = ServerSession()
        let settings = SavedSettings(session: session)
        let server = TestData.server(id: 9)
        _ = store.add(server: server)

        settings.currentServer = server
        XCTAssertEqual(session.currentServer?.id, 9, "writes through SavedSettings land in the session")
        XCTAssertEqual(settings.currentServerId, 9)

        settings.isOfflineMode = true
        XCTAssertTrue(session.isOfflineMode)
        session.isOfflineMode = false
        XCTAssertFalse(settings.isOfflineMode)
    }

    func testSettingsSetupRoutesThroughSession() {
        let server = TestData.server(id: 11)
        _ = store.add(server: server)
        testDefaults.set(11, forKey: SavedSettings.Key.currentServerId.rawValue)

        let session = ServerSession()
        let settings = SavedSettings(session: session)
        settings.setup(store: store)

        XCTAssertEqual(session.currentServer?.id, 11)
        XCTAssertEqual(settings.currentServerId, 11)
    }
}
