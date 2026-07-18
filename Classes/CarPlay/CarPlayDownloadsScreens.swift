//
//  CarPlayDownloadsScreens.swift
//  iSub
//
//  Created by Ben Baron on 7/18/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

// The Downloads tab: browse downloaded songs by folder hierarchy, tag artist,
// tag album, or flat song list — everything works offline by definition. Mirrors
// the phone's Downloads tab minus the download queue (managed on the phone).

// MARK: Downloads root

final class CarPlayDownloadsRootScreen: CarPlayListScreen {
    @Injected private var settings: SavedSettings
    @Injected private var store: Store

    override var title: String { "Downloads" }

    override func sections() -> [CarPlaySection] {
        guard settings.currentServer != nil else { return [] }
        let serverId = settings.currentServerId
        guard let songCount = store.downloadedSongsCount(serverId: serverId), songCount > 0 else { return [] }
        let songsSubtitle = "\(songCount) \("Song".pluralize(amount: songCount))"
        let rows = [
            CarPlayRow(title: "Folders", showsDisclosure: true, action: .drill(makeScreen: { CarPlayDownloadedFolderArtistsScreen() })),
            CarPlayRow(title: "Artists", showsDisclosure: true, action: .drill(makeScreen: { CarPlayDownloadedTagArtistsScreen() })),
            CarPlayRow(title: "Albums", showsDisclosure: true, action: .drill(makeScreen: { CarPlayDownloadedTagAlbumsScreen() })),
            CarPlayRow(title: "Songs", subtitle: songsSubtitle, showsDisclosure: true, action: .drill(makeScreen: { CarPlayDownloadedSongsScreen() })),
        ]
        return [CarPlaySection(rows: rows)]
    }

    override func emptyState() -> CarPlayEmptyState {
        if settings.currentServer == nil {
            return CarPlayEmptyState(title: "Set Up iSub", subtitle: "Open iSub on your iPhone to add your server")
        }
        return CarPlayEmptyState(title: "No Downloaded Songs", subtitle: "Download songs on your iPhone to play them offline")
    }
}

// MARK: Downloaded folder hierarchy

final class CarPlayDownloadedFolderArtistsScreen: CarPlayListScreen {
    @Injected private var settings: SavedSettings
    @Injected private var store: Store

    override var title: String { "Folders" }

    override func sections() -> [CarPlaySection] {
        let rows = store.downloadedFolderArtists(serverId: settings.currentServerId).map { artist in
            CarPlayRow(title: artist.name,
                       showsDisclosure: true,
                       action: .drill(makeScreen: {
                           // Children of a folder artist live at level 1 under its name
                           // (DownloadedFolderAlbumViewController's level math)
                           CarPlayDownloadedFolderContentsScreen(serverId: artist.serverId, level: 1, parentPathComponent: artist.name, recursiveLevel: 0)
                       }))
        }
        return rows.isEmpty ? [] : [CarPlaySection(rows: rows)]
    }

    override func emptyState() -> CarPlayEmptyState {
        CarPlayEmptyState(title: "No Downloaded Folders")
    }
}

// One level of the downloaded folder tree: subfolders + songs at (level, parent).
// recursiveLevel is the level passed to songsRecursive for Play All — the phone
// models use 0 for artists (their name is the level-0 path component) and the
// album's own level for albums.
final class CarPlayDownloadedFolderContentsScreen: CarPlayListScreen {
    @Injected private var settings: SavedSettings
    @Injected private var store: Store
    @Injected private var playQueue: PlayQueue

    private let serverId: Int
    private let level: Int
    private let parentPathComponent: String
    private let recursiveLevel: Int

    override var title: String { parentPathComponent }

    init(serverId: Int, level: Int, parentPathComponent: String, recursiveLevel: Int) {
        self.serverId = serverId
        self.level = level
        self.parentPathComponent = parentPathComponent
        self.recursiveLevel = recursiveLevel
        super.init()
    }

    override func sections() -> [CarPlaySection] {
        let albums = store.downloadedFolderAlbums(serverId: serverId, level: level, parentPathComponent: parentPathComponent)
        let downloadedSongs = store.downloadedSongs(serverId: serverId, level: level, parentPathComponent: parentPathComponent)
        guard !albums.isEmpty || !downloadedSongs.isEmpty else { return [] }

        var sections = [CarPlaySection]()

        let store = self.store
        let serverId = self.serverId
        let recursiveLevel = self.recursiveLevel
        let parentPathComponent = self.parentPathComponent
        let recursiveSongs = {
            store.songsRecursive(serverId: serverId, level: recursiveLevel, parentPathComponent: parentPathComponent).filter { !$0.isVideo }
        }
        sections.append(CarPlaySection(rows: [
            CarPlayRow(title: "Play All", action: .playSongsProvider(provider: recursiveSongs, shuffled: false)),
            CarPlayRow(title: "Shuffle", action: .playSongsProvider(provider: recursiveSongs, shuffled: true)),
        ]))

        if !albums.isEmpty {
            let albumRows = albums.map { album in
                CarPlayRow(title: album.name,
                           artId: CarPlayRowBuilder.artId(serverId: album.serverId, coverArtId: album.coverArtId),
                           showsDefaultArt: true,
                           showsDisclosure: true,
                           action: .drill(makeScreen: {
                               CarPlayDownloadedFolderContentsScreen(serverId: album.serverId, level: album.level + 1, parentPathComponent: album.name, recursiveLevel: album.level)
                           }))
            }
            sections.append(CarPlaySection(header: "Folders", rows: albumRows))
        }

        if !downloadedSongs.isEmpty {
            let currentSong = playQueue.currentSong
            let songRows = downloadedSongs.enumerated().compactMap { index, downloadedSong -> CarPlayRow? in
                guard let song = store.song(downloadedSong: downloadedSong) else { return nil }
                return CarPlayRowBuilder.songRow(song: song,
                                                 currentSong: currentSong,
                                                 isOfflineMode: false, // downloaded songs are always playable
                                                 action: .playDownloadedSongs(songs: downloadedSongs, position: index))
            }
            sections.append(CarPlaySection(header: "Songs", rows: songRows))
        }

        return sections
    }
}

// MARK: Downloaded tag artists

final class CarPlayDownloadedTagArtistsScreen: CarPlayListScreen {
    @Injected private var settings: SavedSettings
    @Injected private var store: Store

    override var title: String { "Artists" }

    override func sections() -> [CarPlaySection] {
        let rows = store.downloadedTagArtists(serverId: settings.currentServerId).map { artist in
            CarPlayRow(title: artist.name,
                       artId: CarPlayRowBuilder.artId(serverId: artist.serverId, coverArtId: artist.coverArtId),
                       showsDefaultArt: true,
                       showsDisclosure: true,
                       action: .drill(makeScreen: { CarPlayDownloadedTagArtistScreen(downloadedTagArtist: artist) }))
        }
        return rows.isEmpty ? [] : [CarPlaySection(rows: rows)]
    }

    override func emptyState() -> CarPlayEmptyState {
        CarPlayEmptyState(title: "No Downloaded Artists")
    }
}

final class CarPlayDownloadedTagArtistScreen: CarPlayListScreen {
    @Injected private var store: Store

    private let downloadedTagArtist: DownloadedTagArtist

    override var title: String { downloadedTagArtist.name }

    init(downloadedTagArtist: DownloadedTagArtist) {
        self.downloadedTagArtist = downloadedTagArtist
        super.init()
    }

    override func sections() -> [CarPlaySection] {
        let albums = store.downloadedTagAlbums(downloadedTagArtist: downloadedTagArtist)
        guard !albums.isEmpty else { return [] }

        var sections = [CarPlaySection]()
        let store = self.store
        let artist = downloadedTagArtist
        let recursiveSongs = {
            store.songsRecursive(downloadedTagArtist: artist).filter { !$0.isVideo }
        }
        sections.append(CarPlaySection(rows: [
            CarPlayRow(title: "Play All", action: .playSongsProvider(provider: recursiveSongs, shuffled: false)),
            CarPlayRow(title: "Shuffle", action: .playSongsProvider(provider: recursiveSongs, shuffled: true)),
        ]))

        let albumRows = albums.map { album in
            CarPlayRow(title: album.name,
                       subtitle: album.year > 0 ? "\(album.year)" : nil,
                       artId: CarPlayRowBuilder.artId(serverId: album.serverId, coverArtId: album.coverArtId),
                       showsDefaultArt: true,
                       showsDisclosure: true,
                       action: .drill(makeScreen: { CarPlayDownloadedTagAlbumScreen(downloadedTagAlbum: album) }))
        }
        sections.append(CarPlaySection(header: "Albums", rows: albumRows))
        return sections
    }
}

// MARK: Downloaded tag albums

final class CarPlayDownloadedTagAlbumsScreen: CarPlayListScreen {
    @Injected private var settings: SavedSettings
    @Injected private var store: Store

    override var title: String { "Albums" }

    override func sections() -> [CarPlaySection] {
        let rows = store.downloadedTagAlbums(serverId: settings.currentServerId).map { album in
            CarPlayRow(title: album.name,
                       subtitle: album.tagArtistName,
                       artId: CarPlayRowBuilder.artId(serverId: album.serverId, coverArtId: album.coverArtId),
                       showsDefaultArt: true,
                       showsDisclosure: true,
                       action: .drill(makeScreen: { CarPlayDownloadedTagAlbumScreen(downloadedTagAlbum: album) }))
        }
        return rows.isEmpty ? [] : [CarPlaySection(rows: rows)]
    }

    override func emptyState() -> CarPlayEmptyState {
        CarPlayEmptyState(title: "No Downloaded Albums")
    }
}

final class CarPlayDownloadedTagAlbumScreen: CarPlayListScreen {
    @Injected private var store: Store
    @Injected private var playQueue: PlayQueue

    private let downloadedTagAlbum: DownloadedTagAlbum

    override var title: String { downloadedTagAlbum.name }

    init(downloadedTagAlbum: DownloadedTagAlbum) {
        self.downloadedTagAlbum = downloadedTagAlbum
        super.init()
    }

    override func sections() -> [CarPlaySection] {
        let downloadedSongs = store.downloadedSongs(downloadedTagAlbum: downloadedTagAlbum)
        guard !downloadedSongs.isEmpty else { return [] }

        let currentSong = playQueue.currentSong
        let rows = downloadedSongs.enumerated().compactMap { index, downloadedSong -> CarPlayRow? in
            guard let song = store.song(downloadedSong: downloadedSong) else { return nil }
            return CarPlayRowBuilder.songRow(song: song,
                                             currentSong: currentSong,
                                             isOfflineMode: false,
                                             showTrackNumber: true,
                                             action: .playDownloadedSongs(songs: downloadedSongs, position: index))
        }
        return [CarPlaySection(rows: rows)]
    }
}

// MARK: Downloaded songs (flat)

final class CarPlayDownloadedSongsScreen: CarPlayListScreen {
    @Injected private var settings: SavedSettings
    @Injected private var store: Store
    @Injected private var playQueue: PlayQueue

    override var title: String { "Songs" }

    override func sections() -> [CarPlaySection] {
        let downloadedSongs = store.downloadedSongs(serverId: settings.currentServerId)
        guard !downloadedSongs.isEmpty else { return [] }

        let currentSong = playQueue.currentSong
        let rows = downloadedSongs.enumerated().compactMap { index, downloadedSong -> CarPlayRow? in
            guard let song = store.song(downloadedSong: downloadedSong) else { return nil }
            return CarPlayRowBuilder.songRow(song: song,
                                             currentSong: currentSong,
                                             isOfflineMode: false,
                                             action: .playDownloadedSongs(songs: downloadedSongs, position: index))
        }
        return [CarPlaySection(rows: rows)]
    }

    override func emptyState() -> CarPlayEmptyState {
        CarPlayEmptyState(title: "No Downloaded Songs")
    }
}
