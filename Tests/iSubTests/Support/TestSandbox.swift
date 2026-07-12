//
//  TestSandbox.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import XCTest
@testable import iSub_Beta

// Redirects all FileSystem directories (database, downloads, temp downloads, etc)
// into a unique temporary directory for the duration of a test, then deletes it
final class TestSandbox {
    let root: URL

    init(name: String = UUID().uuidString) {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("iSubTests", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
    }

    func activate() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        FileSystem.rootOverride = root
    }

    func deactivate() throws {
        if FileSystem.rootOverride == root {
            FileSystem.rootOverride = nil
        }
        if FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
    }
}

// Base class for unit/integration tests that need an isolated file system, an isolated
// UserDefaults suite, and a fresh dependency injection container per test
class SandboxedTestCase: XCTestCase {
    private(set) var sandbox: TestSandbox!
    private(set) var testDefaults: UserDefaults!
    private var testDefaultsSuiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sandbox = TestSandbox()
        try sandbox.activate()
        TestContainer.activate()
        // Default fakes for every protocol seam, so no test reaches the app's REAL
        // singletons through the main-container fallback. Those singletons live for the
        // whole test process, capture the first test's Store, and the real
        // StreamManager/DownloadQueue start real (failing) network work whose
        // retry storms and background Tasks outlive the test that spawned them —
        // burning CPU across the rest of the suite and racing later tests' DI setup.
        // Tests that want a real instance re-register it over these.
        TestContainer.register { FakeSongMetadataDownloader() as SongMetadataDownloading }
        TestContainer.register { FakePlayer() as PlayerControlling }
        TestContainer.register { FakeStreamManager() as StreamManaging }
        TestContainer.register { FakeDownloadQueue() as DownloadQueueing }
        // The value-model layer reads these statics ambiently (song.localPath's server
        // lookup, LocalPlaylist.queue()'s coordinator); without interposing them here a
        // plain SandboxedTestCase test reaches the app's REAL database and playback
        // coordinator. TestContainer.deactivate() restores the app's instances in
        // tearDown; StoreTestCase re-points `store` at its own in-memory store.
        let modelStore = Store()
        modelStore.setup(location: .memory)
        ModelServices.store = modelStore
        ModelServices.settings = nil
        ModelServices.playbackCoordinator = nil
        testDefaultsSuiteName = "iSubTests-\(UUID().uuidString)"
        testDefaults = try XCTUnwrap(UserDefaults(suiteName: testDefaultsSuiteName))
        SavedSettings.defaults = testDefaults
    }

    override func tearDownWithError() throws {
        SavedSettings.defaults = .standard
        testDefaults.removePersistentDomain(forName: testDefaultsSuiteName)
        testDefaults = nil
        testDefaultsSuiteName = nil
        TestContainer.deactivate()
        try sandbox.deactivate()
        sandbox = nil
        try super.tearDownWithError()
    }
}
