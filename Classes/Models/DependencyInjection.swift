//
//  DependencyInjection.swift
//  iSub
//
//  Created by Benjamin Baron on 1/6/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

// The application's service graph, built eagerly in dependency order with every
// back-edge (communication cycle) wired in one visible place. Constructor-converted
// services take their dependencies here; the rest still resolve ambiently through
// the container (their @LazyInjected bridges fire after registration) until their
// phase converts them.
final class AppServices {
    let store: Store
    let settings: SavedSettings
    let networkMonitor: NetworkMonitor
    let analytics: Analytics
    let social: Social
    let downloadsManager: DownloadsManager
    let player: BassPlayer
    let downloadQueue: DownloadQueue
    let streamManager: StreamManager
    let jukebox: Jukebox
    let playQueue: PlayQueue
    let stateRestorer: StateRestorer

    init() {
        // Leaves first (fully constructor-injected)
        store = Store()
        settings = SavedSettings()
        networkMonitor = NetworkMonitor(settings: settings)
        analytics = Analytics()
        social = Social(settings: settings)
        downloadsManager = DownloadsManager(settings: settings, store: store)

        // Not yet constructor-converted; nothing here resolves from the container
        // during init
        player = BassPlayer()
        jukebox = Jukebox()

        streamManager = StreamManager(store: store, settings: settings, player: player, downloadsManager: downloadsManager, networkStatus: networkMonitor, metadataDownloader: SongMetadataDownloader())
        downloadQueue = DownloadQueue(store: store, settings: settings, downloadsManager: downloadsManager, player: player, networkStatus: networkMonitor, streamManager: streamManager, metadataDownloader: SongMetadataDownloader())
        playQueue = PlayQueue()

        stateRestorer = StateRestorer(settings: settings, player: player, playQueue: playQueue)

        // Back-edges are weak references attached explicitly, never resolved ambiently
        settings.attach(networkStatus: networkMonitor)
        streamManager.attach(downloadQueue: downloadQueue)
        streamManager.attach(playQueue: playQueue)
    }
}

struct DependencyInjection {
    static func setupRegistrations() {
        let services = AppServices()
        let main = Resolver.main

        // Register the eagerly built instances (tests shadow them via TestContainer)
        main.register(factory: { services.store })
        main.register(factory: { services.settings })
        main.register(factory: { services.networkMonitor })
        main.register(factory: { services.analytics })
        main.register(factory: { services.social })
        main.register(factory: { services.downloadsManager })
        main.register(factory: { services.player })
        main.register(factory: { services.downloadQueue })
        main.register(factory: { services.streamManager })
        main.register(factory: { services.jukebox })
        main.register(factory: { services.playQueue })
        main.register(factory: { services.stateRestorer })

        // Protocol seams resolving to the same singleton instances (tests override these with fakes)
        main.register(factory: { services.player as PlayerControlling })
        main.register(factory: { services.streamManager as StreamManaging })
        main.register(factory: { services.downloadQueue as DownloadQueueing })
        main.register(factory: { services.networkMonitor as NetworkStatus })
        main.register(factory: { services.social as SocialScrobbling })
        main.register(factory: { SongMetadataDownloader() as SongMetadataDownloading })
    }
}
