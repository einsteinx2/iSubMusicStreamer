//
//  CarPlayRowModel.swift
//  iSub
//
//  Created by Ben Baron on 7/18/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// CP-free value models for everything the CarPlay screens display. Screens build
// [CarPlaySection] from synchronous Store reads and CarPlayItemFactory maps them to
// CPListSection/CPListItem. Keeping this layer free of CarPlay types is what lets
// the row-building logic be unit tested without a car session.

struct CarPlaySection {
    let header: String?
    let indexTitle: String?
    let rows: [CarPlayRow]

    init(header: String? = nil, indexTitle: String? = nil, rows: [CarPlayRow]) {
        self.header = header
        self.indexTitle = indexTitle
        self.rows = rows
    }
}

struct CarPlayRow {
    let title: String
    let subtitle: String?
    // Small cover art variant; nil means no artwork lookup for this row
    let artId: CoverArtLoadingId?
    // Show the bundled default album art when artId is nil or not yet loaded
    // (song/album rows); menu rows leave it false and render text-only
    let showsDefaultArt: Bool
    let isEnabled: Bool
    let isPlaying: Bool
    let showsDisclosure: Bool
    let action: CarPlayRowAction

    init(title: String,
         subtitle: String? = nil,
         artId: CoverArtLoadingId? = nil,
         showsDefaultArt: Bool = false,
         isEnabled: Bool = true,
         isPlaying: Bool = false,
         showsDisclosure: Bool = false,
         action: CarPlayRowAction) {
        self.title = title
        self.subtitle = subtitle
        self.artId = artId
        self.showsDefaultArt = showsDefaultArt
        self.isEnabled = isEnabled
        self.isPlaying = isPlaying
        self.showsDisclosure = showsDisclosure
        self.action = action
    }
}

// Row tap behaviors, mapped 1:1 onto PlaybackCoordinator calls (or a pushed child
// screen) by CarPlayManager.handleRowAction
enum CarPlayRowAction {
    case drill(makeScreen: () -> CarPlayListScreen)
    // shuffled replicates AsyncSongsHelper.finishShuffle: queue, shuffle, then play
    case playSongIds(songIds: [String], serverId: Int, position: Int, shuffled: Bool)
    case playSongs(songs: [Song], position: Int)
    // Songs resolved lazily on tap (e.g. recursive downloaded gathers) so section
    // building stays cheap
    case playSongsProvider(provider: () -> [Song], shuffled: Bool)
    case playDownloadedSongs(songs: [DownloadedSong], position: Int)
    case playLocalPlaylist(localPlaylistId: Int, position: Int)
    case playServerPlaylist(serverId: Int, serverPlaylistId: Int, position: Int)
    case playBookmark(Bookmark)
    case playQueuePosition(Int)
    // The recursive folder/tag-artist gather the phone's play-all header uses
    case playAllRecursive(serverId: Int, id: String, idType: RecursiveSongLoaderIdType, shuffled: Bool)
    // getRandomSongs; pass MediaFolder.allFoldersId for all folders
    case serverShuffle(serverId: Int, mediaFolderId: Int)
    case selectMediaFolder(type: ArtistsViewModelType, mediaFolderId: Int)
    // Screen-specific behavior (load more, retry); the handler must call completion
    // when the car UI should stop showing the row as busy
    case custom(handler: (_ completion: @escaping () -> Void) -> Void)
}

// Shown by the list template when a screen has no rows
struct CarPlayEmptyState {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
}
