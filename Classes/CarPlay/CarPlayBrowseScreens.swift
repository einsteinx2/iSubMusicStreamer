//
//  CarPlayBrowseScreens.swift
//  iSub
//
//  Created by Ben Baron on 7/18/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

// The Library tab: Folders / Artists / Bookmarks, mirroring the phone's Library
// tab minus the Browse sub-tab (which lives in the car's Discover tab).

// MARK: Library root

final class CarPlayLibraryRootScreen: CarPlayListScreen {
    @Injected private var settings: SavedSettings

    override var title: String { "Library" }

    override func sections() -> [CarPlaySection] {
        guard settings.currentServer != nil else { return [] }
        let rows = [
            CarPlayRow(title: "Folders", showsDisclosure: true, action: .drill(makeScreen: { CarPlayArtistsScreen(type: .folders) })),
            CarPlayRow(title: "Artists", showsDisclosure: true, action: .drill(makeScreen: { CarPlayArtistsScreen(type: .tags) })),
            CarPlayRow(title: "Bookmarks", showsDisclosure: true, action: .drill(makeScreen: { CarPlayBookmarksScreen() })),
        ]
        return [CarPlaySection(rows: rows)]
    }

    override func emptyState() -> CarPlayEmptyState {
        CarPlayEmptyState(title: "Set Up iSub", subtitle: "Open iSub on your iPhone to add your server")
    }
}

// MARK: Folder/tag artist lists

// The folder and tag artist lists, backed by the same ArtistsViewModel the phone's
// Library sub-tabs use (cache-first, A–Z sections, per-list media folder setting)
final class CarPlayArtistsScreen: CarPlayListScreen, ArtistsViewModelDelegate {
    @Injected private var settings: SavedSettings

    let type: ArtistsViewModelType
    private let viewModel: ArtistsViewModel

    override var title: String { type == .folders ? "Folders" : "Artists" }

    init(type: ArtistsViewModelType) {
        self.type = type
        let settings: SavedSettings = Resolver.resolve()
        let mediaFolderId = type == .folders ? settings.rootFoldersSelectedFolderId : settings.rootArtistsSelectedFolderId
        viewModel = ArtistsViewModel(serverId: settings.currentServerId, mediaFolderId: mediaFolderId, type: type)
        super.init()
        viewModel.delegate = self
        viewModel.reset() // populate from cache
    }

    override func sections() -> [CarPlaySection] {
        guard settings.currentServer != nil else { return [] }
        var sections = [CarPlaySection]()

        // Media folder picker row, only when there is more than one real folder
        // (the list always contains the synthetic "All Media Folders" entry)
        if viewModel.mediaFolders.count > 2 {
            let type = self.type
            let currentName = viewModel.mediaFolders.first { $0.id == viewModel.mediaFolderId }?.name ?? "All Media Folders"
            let pickerRow = CarPlayRow(title: "Media Folder",
                                       subtitle: currentName,
                                       showsDisclosure: true,
                                       action: .drill(makeScreen: { CarPlayMediaFolderPickerScreen(type: type) }))
            sections.append(CarPlaySection(rows: [pickerRow]))
        }

        // A–Z sections from the cached table sections; hydration stops at the car's
        // item limit so huge libraries don't build thousands of rows
        var budget = CarPlayLimits.maximumItemCount - sections.reduce(0) { $0 + $1.rows.count }
        for (sectionIndex, tableSection) in viewModel.tableSections.enumerated() {
            guard budget > 0 else { break }
            var rows = [CarPlayRow]()
            for row in 0..<tableSection.itemCount {
                guard budget > 0 else { break }
                guard let artist = viewModel.artist(indexPath: IndexPath(row: row, section: sectionIndex)) else { continue }
                rows.append(artistRow(artist: artist))
                budget -= 1
            }
            if !rows.isEmpty {
                sections.append(CarPlaySection(header: tableSection.name, indexTitle: tableSection.name, rows: rows))
            }
        }
        return sections
    }

    private func artistRow(artist: Artist) -> CarPlayRow {
        var subtitle: String?
        if type == .tags && artist.albumCount > 0 {
            subtitle = "\(artist.albumCount) \("Album".pluralize(amount: artist.albumCount))"
        }
        let serverId = artist.serverId
        let artistId = artist.id
        let artistName = artist.name
        let action: CarPlayRowAction
        if type == .folders {
            action = .drill(makeScreen: { CarPlayFolderContentsScreen(serverId: serverId, parentFolderId: artistId, title: artistName) })
        } else {
            action = .drill(makeScreen: { CarPlayTagArtistScreen(serverId: serverId, tagArtistId: artistId, title: artistName) })
        }
        return CarPlayRow(title: artistName,
                          subtitle: subtitle,
                          artId: CarPlayRowBuilder.artId(serverId: serverId, coverArtId: artist.coverArtId),
                          showsDefaultArt: type == .tags,
                          isEnabled: !settings.isOfflineMode || artist.isAvailableOffline,
                          showsDisclosure: true,
                          action: action)
    }

    override func loadIfNeeded() {
        guard !viewModel.isCached, loadState != .loading, !settings.isOfflineMode else { return }
        loadState = .loading
        viewModel.startLoad()
    }

    override func onCancelLoad() {
        viewModel.cancelLoad()
    }

    // Called by the manager when the media folder picker changes this list's folder
    func mediaFolderChanged(mediaFolderId: Int) {
        viewModel.mediaFolderId = mediaFolderId // didSet re-reads the cache
        loadState = .loading
        viewModel.startLoad()
        notifyChanged()
    }

    // MARK: ArtistsViewModelDelegate (called on main)

    func loadingFinished() {
        loadState = .idle
        notifyChanged()
    }

    func loadingFailed(error: Error?) {
        loadState = viewModel.isCached ? .idle : .failed
        notifyChanged()
    }
}

// MARK: Media folder picker

final class CarPlayMediaFolderPickerScreen: CarPlayListScreen {
    @Injected private var settings: SavedSettings
    @Injected private var store: Store

    private let type: ArtistsViewModelType

    override var title: String { "Media Folder" }

    init(type: ArtistsViewModelType) {
        self.type = type
        super.init()
    }

    override func sections() -> [CarPlaySection] {
        let rows = store.mediaFolders(serverId: settings.currentServerId).map { mediaFolder in
            CarPlayRow(title: mediaFolder.name,
                       action: .selectMediaFolder(type: type, mediaFolderId: mediaFolder.id))
        }
        return rows.isEmpty ? [] : [CarPlaySection(rows: rows)]
    }
}

// MARK: Folder contents (folder artist or folder album drill-down)

// Mirrors FolderAlbumViewController: subfolders + songs of one folder, loaded via
// getMusicDirectory when the folder metadata isn't cached yet
final class CarPlayFolderContentsScreen: CarPlayListScreen {
    @Injected private var settings: SavedSettings
    @Injected private var store: Store
    @Injected private var playQueue: PlayQueue

    private let serverId: Int
    private let parentFolderId: String
    private let screenTitle: String

    override var title: String { screenTitle }

    init(serverId: Int, parentFolderId: String, title: String) {
        self.serverId = serverId
        self.parentFolderId = parentFolderId
        self.screenTitle = title
        super.init()
    }

    override func sections() -> [CarPlaySection] {
        let isOfflineMode = settings.isOfflineMode
        let albums = store.folderAlbumIds(serverId: serverId, parentFolderId: parentFolderId)
            .compactMap { store.folderAlbum(serverId: serverId, id: $0) }
        let songs = store.songIds(serverId: serverId, parentFolderId: parentFolderId)
            .compactMap { store.song(serverId: serverId, id: $0) }
            .filter { !$0.isVideo }
        let songIds = songs.map { $0.id }

        var sections = [CarPlaySection]()

        if !albums.isEmpty || !songs.isEmpty {
            // Recursive play-all like the phone's header buttons, but only when
            // online — offline it plays just this folder's downloaded songs
            let playAction: CarPlayRowAction
            let shuffleAction: CarPlayRowAction
            if isOfflineMode || albums.isEmpty {
                playAction = .playSongIds(songIds: songIds, serverId: serverId, position: 0, shuffled: false)
                shuffleAction = .playSongIds(songIds: songIds, serverId: serverId, position: 0, shuffled: true)
            } else {
                playAction = .playAllRecursive(serverId: serverId, id: parentFolderId, idType: .folder, shuffled: false)
                shuffleAction = .playAllRecursive(serverId: serverId, id: parentFolderId, idType: .folder, shuffled: true)
            }
            let canPlay = !isOfflineMode || songs.contains { $0.isAvailableOffline } || !albums.isEmpty
            sections.append(CarPlaySection(rows: [
                CarPlayRow(title: "Play All", isEnabled: canPlay, action: playAction),
                CarPlayRow(title: "Shuffle", isEnabled: canPlay, action: shuffleAction),
            ]))
        }

        if !albums.isEmpty {
            let albumRows = albums.map { album in
                CarPlayRow(title: album.name,
                           artId: CarPlayRowBuilder.artId(serverId: album.serverId, coverArtId: album.coverArtId),
                           showsDefaultArt: true,
                           isEnabled: !isOfflineMode || album.isAvailableOffline,
                           showsDisclosure: true,
                           action: .drill(makeScreen: {
                               CarPlayFolderContentsScreen(serverId: album.serverId, parentFolderId: album.id, title: album.name)
                           }))
            }
            sections.append(CarPlaySection(header: "Albums", rows: albumRows))
        }

        if !songs.isEmpty {
            let currentSong = playQueue.currentSong
            let songRows = songs.enumerated().map { index, song in
                CarPlayRowBuilder.songRow(song: song,
                                          currentSong: currentSong,
                                          isOfflineMode: isOfflineMode,
                                          showTrackNumber: true,
                                          action: .playSongIds(songIds: songIds, serverId: serverId, position: index, shuffled: false))
            }
            sections.append(CarPlaySection(header: "Songs", rows: songRows))
        }

        return sections
    }

    override func loadIfNeeded() {
        guard store.folderMetadata(serverId: serverId, parentFolderId: parentFolderId) == nil, !settings.isOfflineMode else { return }
        let serverId = serverId
        let parentFolderId = parentFolderId
        runLoad {
            _ = try await AsyncSubfolderLoader(serverId: serverId, parentFolderId: parentFolderId).load()
        }
    }
}

// MARK: Tag artist (albums list)

final class CarPlayTagArtistScreen: CarPlayListScreen {
    @Injected private var settings: SavedSettings
    @Injected private var store: Store

    private let serverId: Int
    private let tagArtistId: String
    private let screenTitle: String

    override var title: String { screenTitle }

    init(serverId: Int, tagArtistId: String, title: String) {
        self.serverId = serverId
        self.tagArtistId = tagArtistId
        self.screenTitle = title
        super.init()
    }

    override func sections() -> [CarPlaySection] {
        let isOfflineMode = settings.isOfflineMode
        let albums = store.tagAlbumIds(serverId: serverId, tagArtistId: tagArtistId, orderBy: .year)
            .compactMap { store.tagAlbum(serverId: serverId, id: $0) }
        guard !albums.isEmpty else { return [] }

        var sections = [CarPlaySection]()
        if !isOfflineMode {
            sections.append(CarPlaySection(rows: [
                CarPlayRow(title: "Play All", action: .playAllRecursive(serverId: serverId, id: tagArtistId, idType: .tagArtist, shuffled: false)),
                CarPlayRow(title: "Shuffle", action: .playAllRecursive(serverId: serverId, id: tagArtistId, idType: .tagArtist, shuffled: true)),
            ]))
        }

        let albumRows = albums.map { album in
            var subtitleParts = [String]()
            if album.year > 0 { subtitleParts.append("\(album.year)") }
            if album.songCount > 0 { subtitleParts.append("\(album.songCount) \("Song".pluralize(amount: album.songCount))") }
            return CarPlayRow(title: album.name,
                              subtitle: subtitleParts.isEmpty ? nil : subtitleParts.joined(separator: " • "),
                              artId: CarPlayRowBuilder.artId(serverId: album.serverId, coverArtId: album.coverArtId),
                              showsDefaultArt: true,
                              isEnabled: !isOfflineMode || album.isAvailableOffline,
                              showsDisclosure: true,
                              action: .drill(makeScreen: { CarPlayTagAlbumScreen(tagAlbum: album) }))
        }
        sections.append(CarPlaySection(header: "Albums", rows: albumRows))
        return sections
    }

    override func loadIfNeeded() {
        guard store.tagAlbumIds(serverId: serverId, tagArtistId: tagArtistId, orderBy: .year).isEmpty, !settings.isOfflineMode else { return }
        let serverId = serverId
        let tagArtistId = tagArtistId
        runLoad {
            _ = try await AsyncTagArtistLoader(serverId: serverId, tagArtistId: tagArtistId).load()
        }
    }
}

// MARK: Tag album (songs list)

final class CarPlayTagAlbumScreen: CarPlayListScreen {
    @Injected private var settings: SavedSettings
    @Injected private var store: Store
    @Injected private var playQueue: PlayQueue

    private let tagAlbum: TagAlbum

    override var title: String { tagAlbum.name }

    init(tagAlbum: TagAlbum) {
        self.tagAlbum = tagAlbum
        super.init()
    }

    override func sections() -> [CarPlaySection] {
        let isOfflineMode = settings.isOfflineMode
        let songs = store.songIds(serverId: tagAlbum.serverId, tagAlbumId: tagAlbum.id)
            .compactMap { store.song(serverId: tagAlbum.serverId, id: $0) }
            .filter { !$0.isVideo }
        guard !songs.isEmpty else { return [] }
        let songIds = songs.map { $0.id }

        let canPlay = !isOfflineMode || songs.contains { $0.isAvailableOffline }
        var sections = [CarPlaySection]()
        sections.append(CarPlaySection(rows: [
            CarPlayRow(title: "Play All", isEnabled: canPlay, action: .playSongIds(songIds: songIds, serverId: tagAlbum.serverId, position: 0, shuffled: false)),
            CarPlayRow(title: "Shuffle", isEnabled: canPlay, action: .playSongIds(songIds: songIds, serverId: tagAlbum.serverId, position: 0, shuffled: true)),
        ]))

        let currentSong = playQueue.currentSong
        let songRows = songs.enumerated().map { index, song in
            CarPlayRowBuilder.songRow(song: song,
                                      currentSong: currentSong,
                                      isOfflineMode: isOfflineMode,
                                      showTrackNumber: true,
                                      action: .playSongIds(songIds: songIds, serverId: tagAlbum.serverId, position: index, shuffled: false))
        }
        sections.append(CarPlaySection(header: "Songs", rows: songRows))
        return sections
    }

    override func loadIfNeeded() {
        guard store.songIds(serverId: tagAlbum.serverId, tagAlbumId: tagAlbum.id).isEmpty, !settings.isOfflineMode else { return }
        let serverId = tagAlbum.serverId
        let tagAlbumId = tagAlbum.id
        runLoad {
            _ = try await AsyncTagAlbumLoader(serverId: serverId, tagAlbumId: tagAlbumId).load()
        }
    }
}

// MARK: Bookmarks

final class CarPlayBookmarksScreen: CarPlayListScreen {
    @Injected private var settings: SavedSettings
    @Injected private var store: Store

    override var title: String { "Bookmarks" }

    override func sections() -> [CarPlaySection] {
        let isOfflineMode = settings.isOfflineMode
        let rows = store.bookmarks().compactMap { bookmark -> CarPlayRow? in
            guard let song = store.song(bookmark: bookmark) else { return nil }
            var subtitleParts = [String]()
            if let playlist = store.localPlaylist(bookmark: bookmark) {
                subtitleParts.append(playlist.name)
            }
            subtitleParts.append(formatTime(seconds: Int(bookmark.offsetInSeconds)))
            return CarPlayRow(title: song.title,
                              subtitle: subtitleParts.joined(separator: " • "),
                              artId: CarPlayRowBuilder.artId(serverId: song.serverId, coverArtId: song.coverArtId),
                              showsDefaultArt: true,
                              isEnabled: !isOfflineMode || song.isAvailableOffline,
                              action: .playBookmark(bookmark))
        }
        return rows.isEmpty ? [] : [CarPlaySection(rows: rows)]
    }

    override func emptyState() -> CarPlayEmptyState {
        CarPlayEmptyState(title: "No Bookmarks", subtitle: "Create bookmarks from the player on your iPhone")
    }
}
