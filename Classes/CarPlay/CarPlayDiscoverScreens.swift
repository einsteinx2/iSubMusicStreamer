//
//  CarPlayDiscoverScreens.swift
//  iSub
//
//  Created by Ben Baron on 7/18/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

// The Discover tab: the phone's Browse tab minus chat and "now playing on server"
// — quick album lists (getAlbumList) and the server shuffle (getRandomSongs).
// Everything here requires the server, so the whole tab disables offline.

// MARK: Discover root

final class CarPlayDiscoverScreen: CarPlayListScreen {
    @Injected private var settings: SavedSettings
    @Injected private var store: Store

    override var title: String { "Discover" }

    override func sections() -> [CarPlaySection] {
        guard settings.currentServer != nil, !settings.isOfflineMode else { return [] }

        let quickLists: [(title: String, modifier: QuickAlbumsModifier)] = [
            ("Recently Added", .newest),
            ("Recently Played", .recent),
            ("Frequently Played", .frequent),
            ("Random Albums", .random),
        ]
        var rows = quickLists.map { entry in
            CarPlayRow(title: entry.title,
                       showsDisclosure: true,
                       action: .drill(makeScreen: { CarPlayQuickAlbumsScreen(title: entry.title, modifier: entry.modifier) }))
        }

        // Mirrors BrowseViewController.shuffleAll: shuffle everything directly when
        // there's at most one real media folder, otherwise offer a folder picker
        let serverId = settings.currentServerId
        let mediaFolders = store.mediaFolders(serverId: serverId)
        if mediaFolders.count <= 2 {
            rows.append(CarPlayRow(title: "Shuffle All",
                                   action: .serverShuffle(serverId: serverId, mediaFolderId: MediaFolder.allFoldersId)))
        } else {
            rows.append(CarPlayRow(title: "Shuffle All",
                                   showsDisclosure: true,
                                   action: .drill(makeScreen: { CarPlayShuffleFolderPickerScreen() })))
        }

        return [CarPlaySection(rows: rows)]
    }

    override func emptyState() -> CarPlayEmptyState {
        if settings.currentServer == nil {
            return CarPlayEmptyState(title: "Set Up iSub", subtitle: "Open iSub on your iPhone to add your server")
        }
        return CarPlayEmptyState(title: "Offline Mode", subtitle: "Connect to your server to browse")
    }
}

// MARK: Quick album lists

// One page of getAlbumList results. These are never persisted (matching the
// phone's QuickAlbumsViewController), so the list is loaded live and paged with
// a Load More row.
final class CarPlayQuickAlbumsScreen: CarPlayListScreen {
    @Injected private var settings: SavedSettings

    private let screenTitle: String
    private let modifier: QuickAlbumsModifier
    private let serverId: Int
    private var albums = [FolderAlbum]()
    private var hasMorePages = false

    // getAlbumList returns pages of 20 (AsyncQuickAlbumsLoader.size)
    private static let pageSize = 20

    override var title: String { screenTitle }

    init(title: String, modifier: QuickAlbumsModifier) {
        self.screenTitle = title
        self.modifier = modifier
        let settings: SavedSettings = Resolver.resolve()
        self.serverId = settings.currentServerId
        super.init()
    }

    override func sections() -> [CarPlaySection] {
        guard !albums.isEmpty else { return [] }

        var rows = albums.map { album in
            CarPlayRow(title: album.name,
                       subtitle: album.tagArtistName,
                       artId: CarPlayRowBuilder.artId(serverId: album.serverId, coverArtId: album.coverArtId),
                       showsDefaultArt: true,
                       showsDisclosure: true,
                       action: .drill(makeScreen: {
                           CarPlayFolderContentsScreen(serverId: album.serverId, parentFolderId: album.id, title: album.name)
                       }))
        }

        if hasMorePages && rows.count < CarPlayLimits.maximumItemCount {
            rows.append(CarPlayRow(title: "Load More…", action: .custom(handler: { [weak self] completion in
                self?.loadPage()
                completion()
            })))
        }

        return [CarPlaySection(rows: rows)]
    }

    override func loadIfNeeded() {
        guard albums.isEmpty, !settings.isOfflineMode else { return }
        loadPage()
    }

    private func loadPage() {
        let serverId = serverId
        let modifier = modifier
        let offset = albums.count
        runLoad {
            let page = try await AsyncQuickAlbumsLoader(serverId: serverId, modifier: modifier, offset: offset).load()
            await MainActor.run {
                if offset == 0 {
                    self.albums = page
                } else {
                    self.albums += page
                }
                self.hasMorePages = page.count >= Self.pageSize
            }
        }
    }
}

// MARK: Shuffle folder picker

final class CarPlayShuffleFolderPickerScreen: CarPlayListScreen {
    @Injected private var settings: SavedSettings
    @Injected private var store: Store

    override var title: String { "Shuffle All" }

    override func sections() -> [CarPlaySection] {
        let serverId = settings.currentServerId
        var rows = [CarPlayRow(title: "All Media Folders",
                               action: .serverShuffle(serverId: serverId, mediaFolderId: MediaFolder.allFoldersId))]
        for mediaFolder in store.mediaFolders(serverId: serverId) where mediaFolder.id != MediaFolder.allFoldersId {
            rows.append(CarPlayRow(title: mediaFolder.name,
                                   action: .serverShuffle(serverId: serverId, mediaFolderId: mediaFolder.id)))
        }
        return [CarPlaySection(rows: rows)]
    }
}
