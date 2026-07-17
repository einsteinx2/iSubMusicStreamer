//
//  ArtistsViewModel.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

enum ArtistsViewModelType {
    case folders
    case tags
}

// TODO: Get rid of this legacy protocol
protocol ArtistsViewModelDelegate: AnyObject {
    func loadingFinished()
    func loadingFailed(error: Error?)
}

// Backs the Folders and Artists sub-tabs in both modes: one server's root list (with
// its media-folder dropdown), or — while the Combined Library is active — every
// server's list merged alphabetically. The scope is resolved live from the active
// context at reset/load time, so a context switch can never leave the model reading
// a stale server's cache.
class ArtistsViewModel {
    @Injected private var store: Store
    @Injected private var settings: SavedSettings

    let type: ArtistsViewModelType

    weak var delegate: ArtistsViewModelDelegate?

    var serverId: Int { settings.currentServerId }
    var isCombined: Bool { settings.isCombinedContext }

    var mediaFolderId: Int {
        didSet {
            loadFromCache()
        }
    }
    var mediaFolderIndex: Int {
        let index = mediaFolders.firstIndex { $0.id == mediaFolderId }
        return index ?? MediaFolder.allFoldersId
    }

    var isCached: Bool { isCombined ? metadata != nil : mediaFolders.count > 0 && metadata != nil }
    var count: Int { metadata?.itemCount ?? 0 }
    var searchCount: Int { searchRefs.count }
    var reloadDate: Date? { metadata?.reloadDate }

    private(set) var metadata: RootListMetadata?
    private(set) var tableSections = [TableSection]()
    private(set) var mediaFolders = [MediaFolder]()
    private(set) var artistRefs = [ArtistRef]()
    private(set) var searchRefs = [ArtistRef]()
    // Servers that failed the last combined reload (display labels, for the
    // "couldn't reach" note); empty after a fully successful load
    private(set) var lastLoadFailedServerLabels = [String]()

    private var loaderTask: Task<Void, Never>?
    private let searchLimit = 100
    private var searchName: String?
    private var shouldContinueSearch = true

    init(mediaFolderId: Int, type: ArtistsViewModelType, delegate: ArtistsViewModelDelegate? = nil) {
        self.mediaFolderId = mediaFolderId
        self.type = type
        self.delegate = delegate
    }

    deinit {
        cancelLoad()
    }

    func reset() {
        loaderTask?.cancel()
        loaderTask = nil

        metadata = nil
        tableSections.removeAll()
        artistRefs.removeAll()
        searchRefs.removeAll()
        searchName = nil
        shouldContinueSearch = true
        lastLoadFailedServerLabels.removeAll()

        loadFromCache()
    }

    func clearSearch() {
        searchRefs.removeAll()
        searchName = nil
        shouldContinueSearch = true
    }

    func startLoad() {
        cancelLoad()
        if isCombined {
            startCombinedLoad()
        } else {
            startSingleServerLoad()
        }
    }

    private func startSingleServerLoad() {
        let serverId = serverId
        let mediaFolderId = mediaFolderId
        loaderTask = Task {
            do {
                let mediaFolders = try await AsyncMediaFoldersLoader(serverId: serverId).load()
                _ = self.store.deleteMediaFolders(serverId: serverId)
                _ = self.store.add(mediaFolders: mediaFolders)

                let artistsLoader = type == .folders ? AsyncRootFoldersLoader(serverId: serverId, mediaFolderId: mediaFolderId) : AsyncRootArtistsLoader(serverId: serverId, mediaFolderId: mediaFolderId)
                let artistsResponse = try await artistsLoader.load()

                // This Task is not actor-isolated, so the table view state must be
                // published on the main thread: assigning it here races UITableView
                // layout (numberOfSections reads one snapshot, cellForRowAt another)
                // and crashes on the tableSections subscript
                await MainActor.run {
                    self.lastLoadFailedServerLabels = []
                    self.mediaFolders = mediaFolders
                    self.metadata = artistsResponse.metadata
                    self.tableSections = artistsResponse.tableSections
                    self.artistRefs = artistsResponse.artistIds.map { ArtistRef(serverId: serverId, id: $0) }
                    self.delegate?.loadingFinished()
                }
            } catch {
                if !error.isCanceled {
                    await MainActor.run {
                        self.delegate?.loadingFailed(error: error)
                    }
                }
            }
        }
    }

    // One refresh per server (its media folders + its root list, honoring that
    // server's saved folder selection), then a merged read from the cache. Partial
    // failures keep the successful servers' rows and are reported for the header
    // note; only a total failure surfaces the modal error.
    private func startCombinedLoad() {
        let type = type
        let store = store
        let servers = store.servers()
        let selections = combinedSelections
        loaderTask = Task {
            let mediaFolderIdsByServer = Dictionary(uniqueKeysWithValues: selections.map { ($0.serverId, $0.mediaFolderId) })
            let result = await ServerFanOut.run(servers: servers) { server in
                let mediaFolders = try await AsyncMediaFoldersLoader(serverId: server.id).load()
                _ = store.deleteMediaFolders(serverId: server.id)
                _ = store.add(mediaFolders: mediaFolders)

                let mediaFolderId = mediaFolderIdsByServer[server.id] ?? MediaFolder.allFoldersId
                let artistsLoader = type == .folders ? AsyncRootFoldersLoader(serverId: server.id, mediaFolderId: mediaFolderId) : AsyncRootArtistsLoader(serverId: server.id, mediaFolderId: mediaFolderId)
                _ = try await artistsLoader.load()
            }
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.loadFromCache()
                self.lastLoadFailedServerLabels = result.failures.map { $0.server.displayLabel }
                if result.isTotalFailure {
                    self.delegate?.loadingFailed(error: result.failures.first?.error)
                } else {
                    self.delegate?.loadingFinished()
                }
            }
        }
    }

    func cancelLoad() {
        loaderTask?.cancel()
        loaderTask = nil
    }

    // MARK: Overrides

    var itemType: String {
        return type == .folders ? "Folder" : "Artist"
    }

    var showCoverArt: Bool {
        return type == .tags
    }

    private var combinedSelections: [ServerMediaFolderSelection] {
        store.servers().map { server in
            let mediaFolderId = type == .folders
                ? settings.rootFoldersSelectedFolderId(serverId: server.id)
                : settings.rootArtistsSelectedFolderId(serverId: server.id)
            return ServerMediaFolderSelection(serverId: server.id, mediaFolderId: mediaFolderId)
        }
    }

    fileprivate func loadFromCache() {
        if isCombined {
            // No dropdown in the merged view — each server contributes its own saved
            // folder selection
            mediaFolders = []
            let list = type == .folders ? store.combinedFolderArtists(selections: combinedSelections) : store.combinedTagArtists(selections: combinedSelections)
            artistRefs = list.refs
            tableSections = list.sections
            metadata = list.oldestReloadDate.map {
                RootListMetadata(serverId: LibraryContext.combinedContextId, mediaFolderId: MediaFolder.allFoldersId,
                                 itemCount: list.refs.count, reloadDate: $0)
            }
            return
        }

        mediaFolders = store.mediaFolders(serverId: serverId)

        let metadataFunc = type == .folders ? store.folderArtistMetadata : store.tagArtistMetadata
        metadata = metadataFunc(serverId, mediaFolderId)
        if metadata != nil {
            let tableSectionsFunc = type == .folders ? store.folderArtistSections : store.tagArtistSections
            tableSections = tableSectionsFunc(serverId, mediaFolderId)

            let serverId = serverId
            let artistIdsFunc = type == .folders ? store.folderArtistIds : store.tagArtistIds
            artistRefs = artistIdsFunc(serverId, mediaFolderId).map { ArtistRef(serverId: serverId, id: $0) }
        } else {
            tableSections.removeAll()
            artistRefs.removeAll()
        }
    }

    func artist(indexPath: IndexPath) -> Artist? {
        guard indexPath.section < tableSections.count else { return nil }
        let index = tableSections[indexPath.section].position + indexPath.row
        guard index < artistRefs.count else { return nil }

        return artist(ref: artistRefs[index])
    }

    func artistInSearch(indexPath: IndexPath) -> Artist? {
        guard indexPath.row < searchRefs.count else { return nil }

        return artist(ref: searchRefs[indexPath.row])
    }

    private func artist(ref: ArtistRef) -> Artist? {
        return type == .folders ? store.folderArtist(serverId: ref.serverId, id: ref.id) : store.tagArtist(serverId: ref.serverId, id: ref.id)
    }

    func search(name: String) {
        searchName = name
        searchRefs = searchArtists(name: name, offset: 0)
    }

    func continueSearch() {
        if let searchName = searchName, shouldContinueSearch {
            let refs = searchArtists(name: searchName, offset: searchRefs.count)
            shouldContinueSearch = (refs.count == searchLimit)
            searchRefs.append(contentsOf: refs)
        }
    }

    private func searchArtists(name: String, offset: Int) -> [ArtistRef] {
        if isCombined {
            return type == .folders
                ? store.searchCombinedFolderArtists(name: name, selections: combinedSelections, offset: offset, limit: searchLimit)
                : store.searchCombinedTagArtists(name: name, selections: combinedSelections, offset: offset, limit: searchLimit)
        }

        let serverId = serverId
        let searchFunc = type == .folders ? store.search(folderArtistName:serverId:mediaFolderId:offset:limit:) : store.search(tagArtistName:serverId:mediaFolderId:offset:limit:)
        return searchFunc(name, serverId, mediaFolderId, offset, searchLimit).map { ArtistRef(serverId: serverId, id: $0) }
    }
}
