//
//  CarPlayPlaylistScreens.swift
//  iSub
//
//  Created by Ben Baron on 7/18/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

// The Playlists tab: Play Queue / Local Playlists / Server Playlists, mirroring
// the phone's Playlists tab (read/play only — editing stays on the phone).

// MARK: Playlists root

final class CarPlayPlaylistsRootScreen: CarPlayListScreen {
    @Injected private var settings: SavedSettings

    override var title: String { "Playlists" }

    override func sections() -> [CarPlaySection] {
        guard settings.currentServer != nil else { return [] }
        let isOfflineMode = settings.isOfflineMode
        let rows = [
            CarPlayRow(title: "Play Queue", showsDisclosure: true, action: .drill(makeScreen: { CarPlayPlayQueueScreen() })),
            CarPlayRow(title: "Local Playlists", showsDisclosure: true, action: .drill(makeScreen: { CarPlayLocalPlaylistsScreen() })),
            CarPlayRow(title: "Server Playlists", isEnabled: !isOfflineMode, showsDisclosure: true, action: .drill(makeScreen: { CarPlayServerPlaylistsScreen() })),
        ]
        return [CarPlaySection(rows: rows)]
    }

    override func emptyState() -> CarPlayEmptyState {
        CarPlayEmptyState(title: "Set Up iSub", subtitle: "Open iSub on your iPhone to add your server")
    }
}

// MARK: Play queue

// The live queue, shared between this tab and Now Playing's "Queue" button. When
// the queue exceeds the car's item limit, shows a window starting just above the
// current song so "what's playing now" is always visible.
final class CarPlayPlayQueueScreen: CarPlayListScreen {
    @Injected private var settings: SavedSettings
    @Injected private var playQueue: PlayQueue

    override var title: String { "Play Queue" }

    override func sections() -> [CarPlaySection] {
        let songs = playQueue.songs()
        guard !songs.isEmpty else { return [] }

        let isOfflineMode = settings.isOfflineMode
        let currentIndex = playQueue.currentIndex
        let currentSong = playQueue.currentSong

        let limit = CarPlayLimits.maximumItemCount
        var start = 0
        if songs.count > limit {
            start = max(0, min(currentIndex - 3, songs.count - limit))
        }
        let window = songs[start..<min(start + limit, songs.count)]

        let rows = window.enumerated().map { offset, song in
            CarPlayRowBuilder.songRow(song: song,
                                      currentSong: currentSong,
                                      isOfflineMode: isOfflineMode,
                                      action: .playQueuePosition(start + offset))
        }
        return [CarPlaySection(rows: rows)]
    }

    override func emptyState() -> CarPlayEmptyState {
        CarPlayEmptyState(title: "No Songs in Queue", subtitle: "Play something from Library, Playlists, or Discover")
    }
}

// MARK: Local playlists

final class CarPlayLocalPlaylistsScreen: CarPlayListScreen {
    @Injected private var store: Store

    override var title: String { "Local Playlists" }

    override func sections() -> [CarPlaySection] {
        let rows = store.localPlaylists().map { playlist in
            CarPlayRow(title: playlist.name,
                       subtitle: playlist.songCount == 1 ? "1 song" : "\(playlist.songCount) songs",
                       showsDisclosure: true,
                       action: .drill(makeScreen: { CarPlayLocalPlaylistScreen(localPlaylist: playlist) }))
        }
        return rows.isEmpty ? [] : [CarPlaySection(rows: rows)]
    }

    override func emptyState() -> CarPlayEmptyState {
        CarPlayEmptyState(title: "No Local Playlists", subtitle: "Save playlists from the play queue on your iPhone")
    }
}

final class CarPlayLocalPlaylistScreen: CarPlayListScreen {
    @Injected private var settings: SavedSettings
    @Injected private var store: Store
    @Injected private var playQueue: PlayQueue

    private let localPlaylist: LocalPlaylist

    override var title: String { localPlaylist.name }

    init(localPlaylist: LocalPlaylist) {
        self.localPlaylist = localPlaylist
        super.init()
    }

    override func sections() -> [CarPlaySection] {
        let isOfflineMode = settings.isOfflineMode
        let songs = store.songs(localPlaylistId: localPlaylist.id)
        guard !songs.isEmpty else { return [] }

        let currentSong = playQueue.currentSong
        let rows = songs.enumerated().map { index, song in
            CarPlayRowBuilder.songRow(song: song,
                                      currentSong: currentSong,
                                      isOfflineMode: isOfflineMode,
                                      action: .playLocalPlaylist(localPlaylistId: localPlaylist.id, position: index))
        }
        return [CarPlaySection(rows: rows)]
    }

    override func emptyState() -> CarPlayEmptyState {
        CarPlayEmptyState(title: "No Songs", subtitle: "This playlist is empty")
    }
}

// MARK: Server playlists

final class CarPlayServerPlaylistsScreen: CarPlayListScreen {
    @Injected private var settings: SavedSettings
    @Injected private var store: Store

    override var title: String { "Server Playlists" }

    override func sections() -> [CarPlaySection] {
        let isOfflineMode = settings.isOfflineMode
        let rows = store.serverPlaylists(serverId: settings.currentServerId).map { playlist in
            CarPlayRow(title: playlist.name,
                       subtitle: "\(playlist.songCount) \("Song".pluralize(amount: playlist.songCount))",
                       artId: CarPlayRowBuilder.artId(serverId: playlist.serverId, coverArtId: playlist.coverArtId),
                       showsDefaultArt: true,
                       isEnabled: !isOfflineMode || playlist.isAvailableOffline,
                       showsDisclosure: true,
                       action: .drill(makeScreen: { CarPlayServerPlaylistScreen(serverPlaylist: playlist) }))
        }
        return rows.isEmpty ? [] : [CarPlaySection(rows: rows)]
    }

    override func loadIfNeeded() {
        guard !settings.isOfflineMode else { return }
        let serverId = settings.currentServerId
        runLoad {
            _ = try await AsyncServerPlaylistsLoader(serverId: serverId).load()
        }
    }

    override func emptyState() -> CarPlayEmptyState {
        CarPlayEmptyState(title: "No Server Playlists")
    }
}

final class CarPlayServerPlaylistScreen: CarPlayListScreen {
    @Injected private var settings: SavedSettings
    @Injected private var store: Store
    @Injected private var playQueue: PlayQueue

    private let serverPlaylist: ServerPlaylist

    override var title: String { serverPlaylist.name }

    init(serverPlaylist: ServerPlaylist) {
        self.serverPlaylist = serverPlaylist
        super.init()
    }

    override func sections() -> [CarPlaySection] {
        let isOfflineMode = settings.isOfflineMode
        let songs = store.songIds(serverId: serverPlaylist.serverId, serverPlaylistId: serverPlaylist.id)
            .compactMap { store.song(serverId: serverPlaylist.serverId, id: $0) }
        guard !songs.isEmpty else { return [] }

        let currentSong = playQueue.currentSong
        let rows = songs.enumerated().map { index, song in
            CarPlayRowBuilder.songRow(song: song,
                                      currentSong: currentSong,
                                      isOfflineMode: isOfflineMode,
                                      action: .playServerPlaylist(serverId: serverPlaylist.serverId, serverPlaylistId: serverPlaylist.id, position: index))
        }
        return [CarPlaySection(rows: rows)]
    }

    override func loadIfNeeded() {
        guard !store.isServerPlaylistSongsCached(serverId: serverPlaylist.serverId, id: serverPlaylist.id), !settings.isOfflineMode else { return }
        let serverPlaylist = serverPlaylist
        runLoad {
            _ = try await AsyncServerPlaylistLoader(serverPlaylist: serverPlaylist).load()
        }
    }

    override func emptyState() -> CarPlayEmptyState {
        CarPlayEmptyState(title: "No Songs", subtitle: "This playlist is empty")
    }
}
