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
    // as the concrete registrations, or app components would talk past each other
    func testProtocolRegistrationsResolveToConcreteSingletons() {
        XCTAssertTrue(Resolver.resolve(PlayerControlling.self) === Resolver.resolve(BassPlayer.self))
        XCTAssertTrue(Resolver.resolve(StreamManaging.self) === Resolver.resolve(StreamManager.self))
        XCTAssertTrue(Resolver.resolve(DownloadQueueing.self) === Resolver.resolve(DownloadQueue.self))
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
        // TestContainer.deactivate() (run in tearDown) must restore the app's wiring;
        // this asserts the override from other tests doesn't leak into this one
        XCTAssertTrue(Resolver.resolve(PlayerControlling.self) is BassPlayer)
        XCTAssertTrue(Resolver.resolve(StreamManaging.self) is StreamManager)
        XCTAssertTrue(Resolver.resolve(DownloadQueueing.self) is DownloadQueue)
    }
}
