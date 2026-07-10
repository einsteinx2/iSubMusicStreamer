//
//  ProtocolSeamTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
import Resolver
@testable import iSub_Beta

final class ProtocolSeamTests: SandboxedTestCase {
    // The app's protocol registrations must resolve to the same singleton instances
    // as the concrete registrations, or app components would talk past each other.
    // Resolved from .main directly: the test container shadows these seams with fakes.
    func testProtocolRegistrationsResolveToConcreteSingletons() {
        XCTAssertTrue(Resolver.main.resolve(PlayerControlling.self) === Resolver.main.resolve(BassPlayer.self))
        XCTAssertTrue(Resolver.main.resolve(StreamManaging.self) === Resolver.main.resolve(StreamManager.self))
        XCTAssertTrue(Resolver.main.resolve(DownloadQueueing.self) === Resolver.main.resolve(DownloadQueue.self))
    }

    func testInjectedConsumerReceivesFakePlayer() {
        struct Consumer {
            @Injected var player: PlayerControlling
        }

        let fake = FakePlayer()
        TestContainer.register { fake as PlayerControlling }

        let consumer = Consumer()
        XCTAssertTrue(consumer.player === fake)

        // Interactions land on the fake, not the real BASS engine
        consumer.player.playPause()
        XCTAssertTrue(fake.isPlaying)
        XCTAssertEqual(fake.playPauseCount, 1)
    }

    func testInjectedConsumerReceivesFakeStreamManagerAndDownloadQueue() {
        struct Consumer {
            @Injected var streamManager: StreamManaging
            @Injected var downloadQueue: DownloadQueueing
        }

        let fakeStreamManager = FakeStreamManager()
        let fakeDownloadQueue = FakeDownloadQueue()
        TestContainer.register { fakeStreamManager as StreamManaging }
        TestContainer.register { fakeDownloadQueue as DownloadQueueing }

        let consumer = Consumer()
        consumer.streamManager.fillStreamQueue(startDownload: true)
        consumer.downloadQueue.start()

        XCTAssertEqual(fakeStreamManager.fillStreamQueueCalls, [true])
        XCTAssertEqual(fakeDownloadQueue.startCount, 1)
        XCTAssertTrue(fakeDownloadQueue.isDownloading)
    }

    func testFakesAreScopedToTheTest() {
        // Overrides from other tests must not leak into this one: the seams resolve to
        // this test's own default fakes (registered in SandboxedTestCase), while
        // TestContainer.deactivate() (run in tearDown) leaves the app's .main wiring
        // untouched for the app components themselves
        XCTAssertTrue(Resolver.resolve(PlayerControlling.self) is FakePlayer)
        XCTAssertTrue(Resolver.resolve(StreamManaging.self) is FakeStreamManager)
        XCTAssertTrue(Resolver.resolve(DownloadQueueing.self) is FakeDownloadQueue)
        XCTAssertTrue(Resolver.main.resolve(PlayerControlling.self) is BassPlayer)
        XCTAssertTrue(Resolver.main.resolve(StreamManaging.self) is StreamManager)
        XCTAssertTrue(Resolver.main.resolve(DownloadQueueing.self) is DownloadQueue)
    }
}
