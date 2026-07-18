//
//  PlayMediaIntentHandler.swift
//  iSub
//
//  Created by Ben Baron on 7/18/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import Intents
import Resolver
import CocoaLumberjackSwift

// In-app SiriKit media intent handling ("Hey Siri, play <something> in iSub"),
// returned by AppDelegate.application(_:handlerFor:). Voice is the only search
// CarPlay offers audio apps, but this works anywhere Siri does.
//
// Resolution searches the server (search/search2/search3, mirroring the phone's
// ServerSearchViewController) with a local fallback over cached artists, downloaded
// songs/albums, and playlists when offline. The chosen match travels to handle()
// as an INMediaItem identifier of the form "<kind>|<serverId>|<id>".
final class PlayMediaIntentHandler: NSObject, INPlayMediaIntentHandling {
    @Injected private var settings: SavedSettings
    @Injected private var store: Store
    @Injected private var playQueue: PlayQueue
    @Injected private var playbackCoordinator: PlaybackCoordinator

    private enum Kind: String {
        case song, tagAlbum, folderAlbum, tagArtist, folderArtist, localPlaylist, serverPlaylist
    }

    private struct Match {
        let kind: Kind
        let serverId: Int
        let id: String
        let title: String
        let artist: String?
        let mediaType: INMediaItemType

        var identifier: String { "\(kind.rawValue)|\(serverId)|\(id)" }
        var mediaItem: INMediaItem {
            INMediaItem(identifier: identifier, title: title, type: mediaType, artwork: nil, artist: artist)
        }
    }

    // MARK: Resolution

    func resolveMediaItems(for intent: INPlayMediaIntent, with completion: @escaping ([INPlayMediaMediaItemResolutionResult]) -> Void) {
        // Resume requests carry no search; handle() deals with them
        guard let mediaSearch = intent.mediaSearch, searchQuery(for: mediaSearch) != nil else {
            completion([INPlayMediaMediaItemResolutionResult.unsupported()])
            return
        }

        Task {
            let match = await bestMatch(for: mediaSearch)
            if let match {
                completion(INPlayMediaMediaItemResolutionResult.successes(with: [match.mediaItem]))
            } else {
                completion([INPlayMediaMediaItemResolutionResult.unsupported()])
            }
        }
    }

    func handle(intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {
        let shuffled = intent.playShuffled == true

        guard let identifier = intent.mediaItems?.first?.identifier else {
            // "Hey Siri, resume iSub" and similar transport-only requests
            DispatchQueue.mainSyncSafe {
                if self.playQueue.currentSong != nil, self.playbackCoordinator.play() {
                    completion(INPlayMediaIntentResponse(code: .success, userActivity: nil))
                } else {
                    completion(INPlayMediaIntentResponse(code: .failure, userActivity: nil))
                }
            }
            return
        }

        Task {
            let started = await play(identifier: identifier, shuffled: shuffled)
            completion(INPlayMediaIntentResponse(code: started ? .success : .failure, userActivity: nil))
        }
    }

    // MARK: Search

    private func searchQuery(for mediaSearch: INMediaSearch) -> String? {
        let candidates = [mediaSearch.mediaName, mediaSearch.albumName, mediaSearch.artistName]
        return candidates.compactMap { $0 }.first { !$0.isEmpty }
    }

    // Kinds to try, most-specific first, based on what Siri understood
    private func preferredKinds(for mediaSearch: INMediaSearch) -> [INMediaItemType] {
        if mediaSearch.mediaName == nil || mediaSearch.mediaName?.isEmpty == true {
            if mediaSearch.albumName?.isEmpty == false { return [.album, .artist, .song] }
            if mediaSearch.artistName?.isEmpty == false { return [.artist, .album, .song] }
        }
        switch mediaSearch.mediaType {
        case .song, .music: return [.song, .album, .artist, .playlist]
        case .album: return [.album, .artist, .song]
        case .artist: return [.artist, .album, .song]
        case .playlist: return [.playlist]
        default: return [.song, .album, .artist, .playlist]
        }
    }

    private func bestMatch(for mediaSearch: INMediaSearch) async -> Match? {
        guard settings.currentServer != nil, let query = searchQuery(for: mediaSearch) else { return nil }
        let priorities = preferredKinds(for: mediaSearch)

        if !settings.isOfflineMode {
            if let match = await serverMatch(query: query, priorities: priorities) {
                return match
            }
        }
        return localMatch(query: query, priorities: priorities)
    }

    private func serverMatch(query: String, priorities: [INMediaItemType]) async -> Match? {
        let serverId = settings.currentServerId
        guard let server = settings.currentServer else { return nil }

        // Same capability-based search selection as ServerSearchViewController
        let searchType: AsyncSearchLoader.SearchType
        if server.isTagSearchSupported {
            searchType = .tag
        } else if server.isNewSearchSupported {
            searchType = .folder
        } else {
            searchType = .old
        }

        do {
            let data = try await AsyncSearchLoader(serverId: serverId, searchType: searchType, searchItemType: .all, query: query).load()
            for priority in priorities {
                switch priority {
                case .song:
                    if let song = data.songs.first(where: { !$0.isVideo }) {
                        // Search results are not persisted by the loader, but the play
                        // queue JOINs the song table, so persist the match now
                        _ = store.add(song: song)
                        return Match(kind: .song, serverId: song.serverId, id: song.id, title: song.title, artist: song.tagArtistName, mediaType: .song)
                    }
                case .album:
                    if let album = data.tagAlbums.first {
                        return Match(kind: .tagAlbum, serverId: album.serverId, id: album.id, title: album.name, artist: album.tagArtistName, mediaType: .album)
                    }
                    if let album = data.folderAlbums.first {
                        return Match(kind: .folderAlbum, serverId: album.serverId, id: album.id, title: album.name, artist: album.tagArtistName, mediaType: .album)
                    }
                case .artist:
                    if let artist = data.tagArtists.first {
                        return Match(kind: .tagArtist, serverId: artist.serverId, id: artist.id, title: artist.name, artist: nil, mediaType: .artist)
                    }
                    if let artist = data.folderArtists.first {
                        return Match(kind: .folderArtist, serverId: artist.serverId, id: artist.id, title: artist.name, artist: nil, mediaType: .artist)
                    }
                case .playlist:
                    if let match = playlistMatch(query: query) {
                        return match
                    }
                default:
                    break
                }
            }
        } catch {
            if !error.isCanceled {
                DDLogError("[PlayMediaIntentHandler] Server search for '\(query)' failed: \(error)")
            }
        }
        return nil
    }

    // Cached artists, downloaded songs/albums, and playlists — the offline fallback
    private func localMatch(query: String, priorities: [INMediaItemType]) -> Match? {
        let serverId = settings.currentServerId
        for priority in priorities {
            switch priority {
            case .song:
                let downloaded = store.downloadedSongs(serverId: serverId)
                    .compactMap { store.song(downloadedSong: $0) }
                    .filter { !$0.isVideo }
                if let song = downloaded.first(where: { $0.title.localizedCaseInsensitiveContains(query) }) {
                    return Match(kind: .song, serverId: song.serverId, id: song.id, title: song.title, artist: song.tagArtistName, mediaType: .song)
                }
            case .album:
                if let album = store.downloadedTagAlbums(serverId: serverId).first(where: { $0.name.localizedCaseInsensitiveContains(query) }) {
                    return Match(kind: .tagAlbum, serverId: album.serverId, id: album.id, title: album.name, artist: album.tagArtistName, mediaType: .album)
                }
            case .artist:
                if let artist = store.downloadedTagArtists(serverId: serverId).first(where: { $0.name.localizedCaseInsensitiveContains(query) }) {
                    return Match(kind: .tagArtist, serverId: artist.serverId, id: artist.id, title: artist.name, artist: nil, mediaType: .artist)
                }
                // Cached tag artist list (online metadata) still resolves offline if
                // the artist's albums/songs were cached
                if let artistId = store.search(tagArtistName: query, serverId: serverId, mediaFolderId: MediaFolder.allFoldersId, offset: 0, limit: 1).first,
                   let artist = store.tagArtist(serverId: serverId, id: artistId) {
                    return Match(kind: .tagArtist, serverId: artist.serverId, id: artist.id, title: artist.name, artist: nil, mediaType: .artist)
                }
            case .playlist:
                if let match = playlistMatch(query: query) {
                    return match
                }
            default:
                break
            }
        }
        return nil
    }

    private func playlistMatch(query: String) -> Match? {
        if let playlist = store.localPlaylists().first(where: { $0.name.localizedCaseInsensitiveContains(query) }) {
            return Match(kind: .localPlaylist, serverId: 0, id: "\(playlist.id)", title: playlist.name, artist: nil, mediaType: .playlist)
        }
        let serverId = settings.currentServerId
        if let playlist = store.serverPlaylists(serverId: serverId).first(where: { $0.name.localizedCaseInsensitiveContains(query) }) {
            return Match(kind: .serverPlaylist, serverId: playlist.serverId, id: "\(playlist.id)", title: playlist.name, artist: nil, mediaType: .playlist)
        }
        return nil
    }

    // MARK: Playback

    private func play(identifier: String, shuffled: Bool) async -> Bool {
        let parts = identifier.components(separatedBy: "|")
        guard parts.count == 3, let kind = Kind(rawValue: parts[0]), let serverId = Int(parts[1]) else { return false }
        let id = parts[2]

        switch kind {
        case .song:
            guard let song = store.song(serverId: serverId, id: id) else { return false }
            return await MainActor.run {
                let started = playbackCoordinator.play(songs: [song], position: 0) != nil
                if started && shuffled {
                    // A single song has nothing to shuffle, but honor the request shape
                    playbackCoordinator.shuffleToggle()
                }
                return started
            }

        case .tagAlbum:
            if store.songIds(serverId: serverId, tagAlbumId: id).isEmpty {
                guard (try? await AsyncTagAlbumLoader(serverId: serverId, tagAlbumId: id).load()) != nil else { return false }
            }
            let songIds = store.songIds(serverId: serverId, tagAlbumId: id)
            guard !songIds.isEmpty else { return false }
            return await MainActor.run { playSongIds(songIds, serverId: serverId, shuffled: shuffled) }

        case .folderAlbum, .folderArtist:
            return await playRecursive(serverId: serverId, id: id, idType: .folder, shuffled: shuffled)

        case .tagArtist:
            return await playRecursive(serverId: serverId, id: id, idType: .tagArtist, shuffled: shuffled)

        case .localPlaylist:
            guard let localPlaylistId = Int(id) else { return false }
            return await MainActor.run {
                let started = playbackCoordinator.play(localPlaylistId: localPlaylistId, position: 0) != nil
                if started && shuffled {
                    playbackCoordinator.shuffleToggle()
                }
                return started
            }

        case .serverPlaylist:
            guard let serverPlaylistId = Int(id) else { return false }
            if !store.isServerPlaylistSongsCached(serverId: serverId, id: serverPlaylistId) {
                guard (try? await AsyncServerPlaylistLoader(serverId: serverId, serverPlaylistId: serverPlaylistId).load()) != nil else { return false }
            }
            return await MainActor.run {
                let started = playbackCoordinator.playServerPlaylist(serverId: serverId, serverPlaylistId: serverPlaylistId, position: 0) != nil
                if started && shuffled {
                    playbackCoordinator.shuffleToggle()
                }
                return started
            }
        }
    }

    // Mirrors AsyncSongsHelper.finishPlay/finishShuffle for an id list already on hand
    private func playSongIds(_ songIds: [String], serverId: Int, shuffled: Bool) -> Bool {
        playbackCoordinator.prepareForPlayAll()
        guard store.clearAndQueue(songIds: songIds, serverId: serverId) else { return false }
        if shuffled {
            playbackCoordinator.shuffleToggle()
        }
        playbackCoordinator.queueDidChange()
        let started = playbackCoordinator.play(position: 0) != nil
        NotificationCenter.postOnMainThread(name: Notifications.currentPlaylistSongsQueued)
        return started
    }

    // Mirrors AsyncSongsHelper.loadRecursive for playAll/shuffleAll
    private func playRecursive(serverId: Int, id: String, idType: RecursiveSongLoaderIdType, shuffled: Bool) async -> Bool {
        await MainActor.run {
            playbackCoordinator.prepareForPlayAll()
        }
        do {
            try await AsyncRecursiveSongLoader.load(serverId: serverId, id: id, idType: idType, action: shuffled ? .shuffleAll : .playAll)
        } catch {
            if !error.isCanceled {
                DDLogError("[PlayMediaIntentHandler] Recursive load of \(idType) id \(id) failed: \(error)")
            }
            return false
        }
        return await MainActor.run {
            if shuffled {
                playbackCoordinator.shuffleToggle()
            }
            playbackCoordinator.queueDidChange()
            let started = playbackCoordinator.play(position: 0) != nil
            NotificationCenter.postOnMainThread(name: Notifications.currentPlaylistSongsQueued)
            return started
        }
    }
}
