//
//  CarPlayManager.swift
//  iSub
//
//  Created by Ben Baron on 7/18/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import CarPlay
import Resolver
import CocoaLumberjackSwift

// Owns one CarPlay connection: builds the root tab bar, pairs each screen with
// its CPListTemplate, routes row taps to PlaybackCoordinator, and keeps every
// live template in sync with playback/queue/download changes. Created by
// CarPlaySceneDelegate on connect and thrown away on disconnect.
//
// Runs entirely on the main thread. It never writes MPNowPlayingInfoCenter —
// NowPlayingService stays the single writer, and CPNowPlayingTemplate reads
// that surface (plus MPRemoteCommandCenter) on its own.
final class CarPlayManager: NSObject {
    @Injected private var settings: SavedSettings
    @Injected private var store: Store
    @Injected private var playQueue: PlayQueue
    @Injected private var playbackCoordinator: PlaybackCoordinator
    @Injected private var analytics: Analytics

    // Audio apps may show at most 5 templates in a stack (root tab bar included);
    // pushing deeper replaces the top template so unbounded folder trees still browse
    static let maximumTemplateDepth = 5

    private let interface: CarPlayInterfaceControlling
    private var factory: CarPlayItemFactory?
    private var tabBarTemplate: CPTabBarTemplate?
    private var tabEntries = [(screen: CarPlayListScreen, template: CPListTemplate)]()
    private var pushedScreens = [(screen: CarPlayListScreen, template: CPListTemplate)]()
    private var playAllTask: Task<Void, Never>?
    private var serverShuffleTask: Task<Void, Never>?

    init(interface: CarPlayInterfaceControlling) {
        self.interface = interface
        super.init()
    }

    // MARK: Connection lifecycle

    func connect() {
        analytics.log(event: .carPlayConnected)

        // Jukebox mode renders audio on the remote server — the car would be
        // silent. Always play locally while connected; the user can re-enable
        // jukebox from the phone after disconnecting.
        if settings.isJukeboxEnabled {
            playbackCoordinator.setJukeboxEnabled(false)
            analytics.log(event: .jukeboxDisabled)
            HUD.banner("Jukebox mode was turned off for CarPlay", nil)
        }

        factory = CarPlayItemFactory(traitCollection: interface.carTraitCollection) { [weak self] action, completion in
            guard let self else {
                completion()
                return
            }
            self.handleRowAction(action, completion: completion)
        }

        buildTabs(freshScreens: true)
        configureNowPlayingTemplate()

        interface.onStackChanged = { [weak self] in
            self?.pruneScreens()
        }

        NotificationCenter.addObserverOnMainThread(self, selector: #selector(refreshVisibleScreens), name: Notifications.currentPlaylistIndexChanged)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(refreshVisibleScreens), name: Notifications.songPlaybackStarted)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(refreshVisibleScreens), name: Notifications.currentPlaylistSongsQueued)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(refreshVisibleScreens), name: Notifications.currentPlaylistOrderChanged)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(refreshVisibleScreens), name: Notifications.currentPlaylistShuffleToggled)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(refreshVisibleScreens), name: Notifications.downloadQueueSongDownloaded)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(refreshVisibleScreens), name: Notifications.downloadedSongDeleted)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(handleServerSwitched), name: Notifications.serverSwitched)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(handleOnlineOfflineChanged), name: Notifications.didEnterOfflineMode)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(handleOnlineOfflineChanged), name: Notifications.didEnterOnlineMode)
    }

    func disconnect() {
        NotificationCenter.removeObserverOnMainThread(self)
        interface.onStackChanged = nil

        let nowPlaying = CPNowPlayingTemplate.shared
        nowPlaying.remove(self)
        nowPlaying.updateNowPlayingButtons([])
        nowPlaying.isUpNextButtonEnabled = false
        nowPlaying.isAlbumArtistButtonEnabled = false

        playAllTask?.cancel()
        playAllTask = nil
        serverShuffleTask?.cancel()
        serverShuffleTask = nil

        for entry in tabEntries + pushedScreens {
            entry.screen.cancelLoad()
        }
        tabEntries.removeAll()
        pushedScreens.removeAll()
        tabBarTemplate = nil
        factory = nil
    }

    // MARK: Tab building

    private func makeTabScreens() -> [CarPlayListScreen] {
        let library = CarPlayLibraryRootScreen()
        let playlists = CarPlayPlaylistsRootScreen()
        let downloads = CarPlayDownloadsRootScreen()
        let discover = CarPlayDiscoverScreen()
        // Downloads-first when offline: it's the tab guaranteed to be playable
        return settings.isOfflineMode ? [downloads, playlists, library, discover] : [library, playlists, downloads, discover]
    }

    private func tabImage(for screen: CarPlayListScreen) -> UIImage? {
        switch screen {
        case is CarPlayLibraryRootScreen: return UIImage(systemName: "music.note.list")
        case is CarPlayPlaylistsRootScreen: return UIImage(systemName: "list.star")
        case is CarPlayDownloadsRootScreen: return UIImage(systemName: "arrow.down.circle")
        case is CarPlayDiscoverScreen: return UIImage(systemName: "sparkles")
        default: return nil
        }
    }

    private func buildTabs(freshScreens: Bool) {
        if freshScreens {
            for entry in tabEntries {
                entry.screen.cancelLoad()
            }
            let screens = Array(makeTabScreens().prefix(CPTabBarTemplate.maximumTabCount))
            tabEntries = screens.map { screen in
                let template = makeTemplate(for: screen)
                template.tabTitle = screen.title
                template.tabImage = tabImage(for: screen)
                return (screen, template)
            }
        } else {
            // Same screens, new order (offline/online flips)
            let orderedTitles = makeTabScreens().map { $0.title }
            tabEntries.sort { a, b in
                let aIndex = orderedTitles.firstIndex(of: a.screen.title) ?? Int.max
                let bIndex = orderedTitles.firstIndex(of: b.screen.title) ?? Int.max
                return aIndex < bIndex
            }
        }

        let templates = tabEntries.map { $0.template }
        if let tabBarTemplate {
            tabBarTemplate.updateTemplates(templates)
        } else {
            let tabBar = CPTabBarTemplate(templates: templates)
            tabBarTemplate = tabBar
            interface.setRootTemplate(tabBar, animated: false)
        }
    }

    // MARK: Template rendering

    private func makeTemplate(for screen: CarPlayListScreen) -> CPListTemplate {
        let template = CPListTemplate(title: screen.title, sections: [])
        render(screen: screen, template: template)
        screen.startLoadIfNeeded { [weak self, weak screen, weak template] in
            guard let self, let screen, let template else { return }
            self.render(screen: screen, template: template)
        }
        return template
    }

    private func render(screen: CarPlayListScreen, template: CPListTemplate) {
        guard let factory else { return }
        template.updateSections(factory.listSections(screen.displaySections()))
        let empty = screen.emptyState()
        template.emptyViewTitleVariants = [empty.title]
        template.emptyViewSubtitleVariants = empty.subtitle.map { [$0] } ?? []
    }

    @objc private func refreshVisibleScreens() {
        for entry in tabEntries + pushedScreens {
            render(screen: entry.screen, template: entry.template)
        }
    }

    @objc private func handleServerSwitched() {
        // Old screens captured the old serverId; start over from fresh roots
        interface.popToRootTemplate(animated: false)
        for entry in pushedScreens {
            entry.screen.cancelLoad()
        }
        pushedScreens.removeAll()
        buildTabs(freshScreens: true)
    }

    @objc private func handleOnlineOfflineChanged() {
        buildTabs(freshScreens: false)
        refreshVisibleScreens()
    }

    private func pruneScreens() {
        let liveTemplates = interface.templates
        let removed = pushedScreens.filter { entry in !liveTemplates.contains { $0 === entry.template } }
        guard !removed.isEmpty else { return }
        for entry in removed {
            entry.screen.cancelLoad()
        }
        pushedScreens.removeAll { entry in !liveTemplates.contains { $0 === entry.template } }
    }

    // MARK: Navigation

    func push(screen: CarPlayListScreen) {
        let template = makeTemplate(for: screen)
        pushedScreens.append((screen, template))
        if interface.templates.count >= Self.maximumTemplateDepth {
            // At the depth limit: replace the top template instead of failing
            interface.popTemplate(animated: false)
        }
        interface.pushTemplate(template, animated: true)
    }

    private func showNowPlaying() {
        let nowPlaying = CPNowPlayingTemplate.shared
        if interface.topTemplate === nowPlaying {
            return
        }
        if interface.templates.contains(where: { $0 === nowPlaying }) {
            // The queue screen from the Up Next button sits directly above Now
            // Playing; popping returns to it
            interface.popTemplate(animated: true)
            return
        }
        if interface.templates.count >= Self.maximumTemplateDepth {
            interface.popTemplate(animated: false)
        }
        interface.pushTemplate(nowPlaying, animated: true)
    }

    // MARK: Row actions

    func handleRowAction(_ action: CarPlayRowAction, completion: @escaping () -> Void) {
        switch action {
        case .drill(let makeScreen):
            push(screen: makeScreen())
            completion()

        case .playSongIds(let songIds, let serverId, let position, let shuffled):
            if shuffled {
                playShuffled {
                    _ = self.store.clearAndQueue(songIds: songIds, serverId: serverId)
                }
            } else {
                _ = playbackCoordinator.play(songIds: songIds, serverId: serverId, position: position)
                showNowPlaying()
            }
            completion()

        case .playSongs(let songs, let position):
            _ = playbackCoordinator.play(songs: songs, position: position)
            showNowPlaying()
            completion()

        case .playSongsProvider(let provider, let shuffled):
            let songs = provider()
            guard !songs.isEmpty else {
                completion()
                return
            }
            if shuffled {
                playShuffled {
                    _ = self.store.clearAndQueue(songs: songs)
                }
            } else {
                _ = playbackCoordinator.play(songs: songs, position: 0)
                showNowPlaying()
            }
            completion()

        case .playDownloadedSongs(let songs, let position):
            if let song = playbackCoordinator.play(downloadedSongs: songs, position: position), !song.isVideo {
                showNowPlaying()
            }
            completion()

        case .playLocalPlaylist(let localPlaylistId, let position):
            _ = playbackCoordinator.play(localPlaylistId: localPlaylistId, position: position)
            showNowPlaying()
            completion()

        case .playServerPlaylist(let serverId, let serverPlaylistId, let position):
            _ = playbackCoordinator.playServerPlaylist(serverId: serverId, serverPlaylistId: serverPlaylistId, position: position)
            showNowPlaying()
            completion()

        case .playBookmark(let bookmark):
            if playbackCoordinator.play(bookmark: bookmark) != nil {
                showNowPlaying()
            }
            completion()

        case .playQueuePosition(let position):
            _ = playbackCoordinator.play(position: position)
            showNowPlaying()
            completion()

        case .playAllRecursive(let serverId, let id, let idType, let shuffled):
            playAllRecursive(serverId: serverId, id: id, idType: idType, shuffled: shuffled, completion: completion)

        case .serverShuffle(let serverId, let mediaFolderId):
            serverShuffle(serverId: serverId, mediaFolderId: mediaFolderId, completion: completion)

        case .selectMediaFolder(let type, let mediaFolderId):
            if type == .folders {
                settings.rootFoldersSelectedFolderId = mediaFolderId
            } else {
                settings.rootArtistsSelectedFolderId = mediaFolderId
            }
            interface.popTemplate(animated: true)
            for entry in tabEntries + pushedScreens {
                if let artistsScreen = entry.screen as? CarPlayArtistsScreen, artistsScreen.type == type {
                    artistsScreen.mediaFolderChanged(mediaFolderId: mediaFolderId)
                }
            }
            completion()

        case .custom(let handler):
            handler(completion)
        }
    }

    // MARK: Play helpers

    // Mirrors AsyncSongsHelper.finishShuffle: clear, queue, toggle shuffle, play
    // from the top (minus the phone-only HUD and showPlayer tab switch)
    private func playShuffled(queueBody: () -> Void) {
        playbackCoordinator.prepareForPlayAll()
        queueBody()
        playbackCoordinator.shuffleToggle()
        playbackCoordinator.queueDidChange()
        _ = playbackCoordinator.play(position: 0)
        NotificationCenter.postOnMainThread(name: Notifications.currentPlaylistSongsQueued)
        showNowPlaying()
    }

    // Mirrors AsyncSongsHelper.loadRecursive for playAll/shuffleAll: the loader
    // queues songs into the (pre-cleared) play queue as it walks the folder tree
    private func playAllRecursive(serverId: Int, id: String, idType: RecursiveSongLoaderIdType, shuffled: Bool, completion: @escaping () -> Void) {
        playbackCoordinator.prepareForPlayAll()
        playAllTask?.cancel()
        playAllTask = Task {
            do {
                try await AsyncRecursiveSongLoader.load(serverId: serverId, id: id, idType: idType, action: shuffled ? .shuffleAll : .playAll)
                await MainActor.run {
                    if shuffled {
                        self.playbackCoordinator.shuffleToggle()
                    }
                    self.playbackCoordinator.queueDidChange()
                    _ = self.playbackCoordinator.play(position: 0)
                    NotificationCenter.postOnMainThread(name: Notifications.currentPlaylistSongsQueued)
                    self.showNowPlaying()
                    completion()
                }
            } catch {
                if !error.isCanceled {
                    DDLogError("[CarPlayManager] Recursive play-all of \(idType) id \(id) failed: \(error)")
                }
                await MainActor.run {
                    completion()
                }
            }
        }
    }

    // Mirrors BrowseViewController.performServerShuffle minus the HUD
    private func serverShuffle(serverId: Int, mediaFolderId: Int, completion: @escaping () -> Void) {
        serverShuffleTask?.cancel()
        serverShuffleTask = Task {
            do {
                let songs = try await AsyncServerShuffleLoader(serverId: serverId, mediaFolderId: mediaFolderId).load()
                await MainActor.run {
                    _ = self.playbackCoordinator.play(songs: songs, position: 0)
                    self.showNowPlaying()
                    completion()
                }
            } catch {
                if !error.isCanceled {
                    DDLogError("[CarPlayManager] Server shuffle failed: \(error)")
                }
                await MainActor.run {
                    completion()
                }
            }
        }
    }

    // MARK: Now Playing template

    private func configureNowPlayingTemplate() {
        let nowPlaying = CPNowPlayingTemplate.shared
        nowPlaying.updateNowPlayingButtons([
            CPNowPlayingRepeatButton { [weak self] _ in
                self?.cycleRepeatMode()
            },
            CPNowPlayingShuffleButton { [weak self] _ in
                self?.playbackCoordinator.shuffleToggle()
            },
        ])
        nowPlaying.isUpNextButtonEnabled = true
        nowPlaying.upNextTitle = "Queue"
        nowPlaying.isAlbumArtistButtonEnabled = true
        nowPlaying.add(self)
    }

    // none → all → one → none, matching the phone player's repeat button cycle
    private func cycleRepeatMode() {
        switch playQueue.repeatMode {
        case .none: playQueue.repeatMode = .all
        case .all: playQueue.repeatMode = .one
        case .one: playQueue.repeatMode = .none
        }
    }
}

// MARK: CPNowPlayingTemplateObserver

extension CarPlayManager: CPNowPlayingTemplateObserver {
    func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
        push(screen: CarPlayPlayQueueScreen())
    }

    func nowPlayingTemplateAlbumArtistButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
        guard let song = playQueue.currentSong,
              let tagAlbumId = song.tagAlbumId,
              let tagAlbum = store.tagAlbum(serverId: song.serverId, id: tagAlbumId) else { return }
        push(screen: CarPlayTagAlbumScreen(tagAlbum: tagAlbum))
    }
}
