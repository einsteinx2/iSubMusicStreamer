//
//  DependencyInjection.swift
//  iSub
//
//  Created by Benjamin Baron on 1/6/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

// Ambient services for value-model conveniences (Song.download(), Song.localPath,
// LocalPlaylist.queue(), ...). Value types can't be constructor-injected without
// threading a store through every model at every creation site, so this is the one
// deliberate, greppable swap point for the model layer. Set once by AppServices at
// launch; tests point `store` at their in-memory store (StoreTestCase) and the
// jukebox/settings pair at their fakes when a test exercises the jukebox sync path.
enum ModelServices {
    static var store: Store!
    static var settings: SavedSettings?
    static var jukebox: Jukebox?
}

// The application's service graph, built eagerly in dependency order with every
// back-edge (communication cycle) wired in one visible place. Constructor-converted
// services take their dependencies here; the rest still resolve ambiently through
// the container (their @LazyInjected bridges fire after registration) until their
// phase converts them.
final class AppServices {
    let store: Store
    let session: ServerSession
    let settings: SavedSettings
    let networkMonitor: NetworkMonitor
    let analytics: Analytics
    let scrobbleService: ScrobbleService
    let downloadsManager: DownloadsManager
    let player: BassPlayer
    let downloadQueue: DownloadQueue
    let streamManager: StreamManager
    let jukebox: Jukebox
    let playQueue: PlayQueue
    let stateRestorer: StateRestorer

    init() {
        // Construction order follows the dependency direction: every service is built
        // after everything it owns a reference to
        store = Store()
        session = ServerSession()
        settings = SavedSettings(session: session)
        networkMonitor = NetworkMonitor(settings: settings)
        analytics = Analytics()
        downloadsManager = DownloadsManager(settings: settings, store: store)
        player = BassPlayer(store: store, settings: settings)
        scrobbleService = ScrobbleService(settings: settings, session: session, player: player)
        jukebox = Jukebox(settings: settings, store: store)
        streamManager = StreamManager(store: store, settings: settings, player: player, downloadsManager: downloadsManager, networkStatus: networkMonitor, metadataDownloader: SongMetadataDownloader())
        downloadQueue = DownloadQueue(store: store, settings: settings, downloadsManager: downloadsManager, player: player, networkStatus: networkMonitor, streamManager: streamManager, metadataDownloader: SongMetadataDownloader())
        playQueue = PlayQueue(store: store, settings: settings, player: player, jukebox: jukebox, streamManager: streamManager, downloadQueue: downloadQueue)
        stateRestorer = StateRestorer(settings: settings, player: player, playQueue: playQueue)

        // Back-edges are weak references attached explicitly, never resolved ambiently
        settings.attach(networkStatus: networkMonitor)
        streamManager.attach(downloadQueue: downloadQueue)
        streamManager.attach(playQueue: playQueue)
        jukebox.attach(playQueue: playQueue)
        player.attach(playQueue: playQueue)
        player.attach(streamManager: streamManager)
        player.attach(downloadQueue: downloadQueue)
        downloadsManager.attach(player: player, playQueue: playQueue)

        // Ambient services for the value-model layer
        ModelServices.store = store
        ModelServices.settings = settings
        ModelServices.jukebox = jukebox
    }
}

struct DependencyInjection {
    static func setupRegistrations() {
        let services = AppServices()
        let main = Resolver.main

        // Register the eagerly built instances (tests shadow them via TestContainer)
        main.register(factory: { services.store })
        main.register(factory: { services.session })
        main.register(factory: { services.settings })
        main.register(factory: { services.networkMonitor })
        main.register(factory: { services.analytics })
        main.register(factory: { services.scrobbleService })
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
        main.register(factory: { SongMetadataDownloader() as SongMetadataDownloading })

        // Transient request builder; resolves store/settings at build time so tests'
        // container overrides are honored
        main.register(factory: { SubsonicRequestBuilder(store: Resolver.resolve(), settings: Resolver.resolve()) })

        // The cover art manager keeps its `.shared` default-argument convenience for
        // views, but is also resolvable so new code can inject it
        main.register(factory: { AsyncCoverArtLoaderManager.shared })
    }
}
