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

class ArtistsViewModel {
    @Injected private var store: Store
    
    let type: ArtistsViewModelType
    
    weak var delegate: ArtistsViewModelDelegate?
    var serverId: Int
    var mediaFolderId: Int {
        didSet {
            loadFromCache()
        }
    }
    var mediaFolderIndex: Int {
        let index = mediaFolders.firstIndex { $0.id == mediaFolderId }
        return index ?? MediaFolder.allFoldersId
    }
    
    var isCached: Bool { mediaFolders.count > 0 && metadata != nil }
    var count: Int { metadata?.itemCount ?? 0 }
    var searchCount: Int { searchArtistIds.count }
    var reloadDate: Date? { metadata?.reloadDate }
    
    private(set) var metadata: RootListMetadata?
    private(set) var tableSections = [TableSection]()
    private(set) var mediaFolders = [MediaFolder]()
    private(set) var artistIds = [String]()
    private(set) var searchArtistIds = [String]()
    
    private var loaderTask: Task<Void, Never>?
    private let searchLimit = 100
    private var searchName: String?
    private var shouldContinueSearch = true
    
    init(serverId: Int, mediaFolderId: Int, type: ArtistsViewModelType, delegate: ArtistsViewModelDelegate? = nil) {
        self.serverId = serverId
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
        artistIds.removeAll()
        searchArtistIds.removeAll()
        searchName = nil
        shouldContinueSearch = true
        
        loadFromCache()
    }
    
    func clearSearch() {
        searchArtistIds.removeAll()
        searchName = nil
        shouldContinueSearch = true
    }
    
    func startLoad() {
        cancelLoad()
    
        loaderTask = Task {
            do {
                self.mediaFolders = try await AsyncMediaFoldersLoader(serverId: serverId).load()
                _ = self.store.deleteMediaFolders()
                _ = self.store.add(mediaFolders: self.mediaFolders)
                
                let artistsLoader = type == .folders ? AsyncRootFoldersLoader(serverId: serverId, mediaFolderId: mediaFolderId) : AsyncRootArtistsLoader(serverId: serverId, mediaFolderId: mediaFolderId)
                let artistsResponse = try await artistsLoader.load()
                self.metadata = artistsResponse.metadata
                self.tableSections = artistsResponse.tableSections
                self.artistIds = artistsResponse.artistIds
                
                await MainActor.run {
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
    
    fileprivate func loadFromCache() {
        mediaFolders = store.mediaFolders(serverId: serverId)
        
        let metadataFunc = type == .folders ? store.folderArtistMetadata : store.tagArtistMetadata
        metadata = metadataFunc(serverId, mediaFolderId)
        if metadata != nil {
            let tableSectionsFunc = type == .folders ? store.folderArtistSections : store.tagArtistSections
            tableSections = tableSectionsFunc(serverId, mediaFolderId)
            
            let artistIdsFunc = type == .folders ? store.folderArtistIds : store.tagArtistIds
            artistIds = artistIdsFunc(serverId, mediaFolderId)
        } else {
            tableSections.removeAll()
            artistIds.removeAll()
        }
    }
    
    func artist(indexPath: IndexPath) -> Artist? {
        let index = tableSections[indexPath.section].position + indexPath.row
        guard index < artistIds.count else { return nil }
        
        let id = artistIds[index]
        return type == .folders ? store.folderArtist(serverId: serverId, id: id) : store.tagArtist(serverId: serverId, id: id)
    }
    
    func artistInSearch(indexPath: IndexPath) -> Artist? {
        guard indexPath.row < searchArtistIds.count else { return nil }
        
        let id = searchArtistIds[indexPath.row]
        return type == .folders ? store.folderArtist(serverId: serverId, id: id) : store.tagArtist(serverId: serverId, id: id)
    }
    
    func search(name: String) {
        searchName = name
        
        let searchFunc = type == .folders ? store.search(folderArtistName:serverId:mediaFolderId:offset:limit:) : store.search(tagArtistName:serverId:mediaFolderId:offset:limit:)
        searchArtistIds = searchFunc(name, serverId, mediaFolderId, 0, searchLimit)
    }
    
    func continueSearch() {
        if let searchName = searchName, shouldContinueSearch {
            let searchFunc = type == .folders ? store.search(folderArtistName:serverId:mediaFolderId:offset:limit:) : store.search(tagArtistName:serverId:mediaFolderId:offset:limit:)
            let ids = searchFunc(searchName, serverId, mediaFolderId, searchArtistIds.count, searchLimit)
            shouldContinueSearch = (ids.count == searchLimit)
            searchArtistIds.append(contentsOf: ids)
        }
    }
}
