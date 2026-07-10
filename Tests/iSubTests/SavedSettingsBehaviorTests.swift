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

    override func setUpWithError() throws {
        try super.setUpWithError()
        player = FakePlayer()
        let fakePlayer = player!
        TestContainer.register { fakePlayer as PlayerControlling }
        let freshPlayQueue = PlayQueue()
        TestContainer.register { freshPlayQueue }
        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }
        settings = freshSettings
    }

    override func tearDownWithError() throws {
        settings = nil
        player = nil
        try super.tearDownWithError()
    }

    // MARK: currentMaxBitrate

    func testCurrentMaxBitrateMapping() {
        // The mapping goes through whichever network branch the simulator reports,
        // so set both settings identically to make the result deterministic
        let expected: [(setting: Int, kiloBitrate: Int)] = [
            (0, 64), (1, 96), (2, 128), (3, 160), (4, 192), (5, 256), (6, 320),
        ]
        for (setting, kiloBitrate) in expected {
            settings.maxBitrateWifi = setting
            settings.maxBitrate3G = setting
            XCTAssertEqual(settings.currentMaxBitrate, kiloBitrate, "setting \(setting) should map to \(kiloBitrate) Kbps")
        }
    }

    func testCurrentMaxBitrateOutOfRangeMeansUnlimited() {
        // 7 is the "Unlimited" slider position and maps to 0 (no cap)
        settings.maxBitrateWifi = 7
        settings.maxBitrate3G = 7
        XCTAssertEqual(settings.currentMaxBitrate, 0)

        settings.maxBitrateWifi = 99
        settings.maxBitrate3G = 99
        XCTAssertEqual(settings.currentMaxBitrate, 0)
    }

    func testCurrentMaxBitrateDefaultIsUnlimited() {
        XCTAssertEqual(settings.maxBitrateWifi, 7)
        XCTAssertEqual(settings.maxBitrate3G, 7)
        XCTAssertEqual(settings.currentMaxBitrate, 0)
    }

    // MARK: currentVideoBitrates

    func testCurrentVideoBitratesArrays() {
        let isWifi = SceneDelegate.shared.isWifi
        let expectedByLevel: [Int: [String]] = isWifi ? [
            0: ["512"],
            1: ["1024", "512"],
            2: ["1536", "1024", "512"],
            3: ["2048", "1536", "1024", "512"],
            4: ["4096", "2048", "1536", "1024", "512"],
            5: ["8192@1920x1080", "4096", "2048", "1536", "1024", "512"],
        ] : [
            0: ["192"],
            1: ["512", "192"],
            2: ["1024", "512", "192"],
            3: ["1536", "1024", "512", "192"],
            4: ["2048", "1536", "1024", "512", "192"],
            5: ["4096", "2048", "1536", "1024", "512", "192"],
        ]

        for (level, expected) in expectedByLevel {
            settings.maxVideoBitrateWifi = level
            settings.maxVideoBitrate3G = level
            XCTAssertEqual(settings.currentVideoBitrates, expected, "video bitrate level \(level)")
        }

        // Out-of-range levels return nil (no bitrate restriction parameter)
        settings.maxVideoBitrateWifi = 9
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

    func testCurrentServerDidSetWritesIdAndClearsRedirect() {
        let server = TestData.server(id: 3)
        _ = store.add(server: server)
        settings.currentServerRedirectUrlString = "https://redirect.example.com"

        settings.currentServer = server

        XCTAssertNil(settings.currentServerRedirectUrlString, "changing servers must clear the redirect URL")
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

        settings.saveState()

        XCTAssertTrue(settings.isRecover)
    }

    func testIsRecoverFalseWhenRecoverSettingIsOne() {
        player.isPlaying = true
        settings.recoverSetting = 1
        // recoverSetting is captured during loadState
        settings.loadState()

        settings.saveState()

        XCTAssertFalse(settings.isRecover)
    }

    func testIsRecoverFalseWhenNotPlaying() {
        player.isPlaying = false
        settings.recoverSetting = 0

        settings.saveState()

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
