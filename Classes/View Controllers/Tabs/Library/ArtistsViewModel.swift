//
//  ArtistsViewModel.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

class ArtistsViewModel {
    @Injected fileprivate var store: Store
    
    weak var delegate: APILoaderDelegate?
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
    
    fileprivate(set) var metadata: RootListMetadata?
    fileprivate(set) var tableSections = [TableSection]()
    fileprivate(set) var mediaFolders = [MediaFolder]()
    fileprivate(set) var artistIds = [Int]()
    fileprivate(set) var searchArtistIds = [Int]()
    
    fileprivate var mediaFoldersLoader: MediaFoldersLoader?
    fileprivate var artistsLoader: APILoader?
    fileprivate let searchLimit = 100
    fileprivate var searchName: String?
    fileprivate var shouldContinueSearch = true
    
    init(serverId: Int, mediaFolderId: Int, delegate: APILoaderDelegate? = nil) {
        self.serverId = serverId
        self.mediaFolderId = mediaFolderId
        self.delegate = delegate
    }
    
    deinit {
        cancelLoad()
    }
    
    func reset() {
        artistsLoader?.cancelLoad()
        artistsLoader?.delegate = nil
        artistsLoader = nil
        
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
    
    fileprivate func loadMediaFolders(completion: @escaping APILoaderCallback) {
        mediaFoldersLoader = MediaFoldersLoader(serverId: serverId) { [weak self] loader, success, error in
            guard let self = self, let loader = loader as? MediaFoldersLoader else { return }
            if success {
                self.mediaFolders = loader.mediaFolders
                // TODO: Handle store errors
                _ = self.store.deleteMediaFolders()
                _ = self.store.add(mediaFolders: self.mediaFolders)
//                self.delegate?.loadingFinished(loader: loader)
            } else {
//                self.delegate?.loadingFailed(loader: loader, error: error)
            }
            self.mediaFoldersLoader?.callback = nil
            self.mediaFoldersLoader = nil
            completion(loader, success, error)
        }
        mediaFoldersLoader?.startLoad()
    }
    
    func startLoad() {
        cancelLoad()
        loadMediaFolders() { [weak self] _, success, error in
            if success {
                self?.loadArtists() { [weak self] _, success, error in
                    if success {
                        self?.delegate?.loadingFinished(loader: nil)
                    } else {
                        self?.delegate?.loadingFailed(loader: nil, error: error)
                    }
                }
            } else {
                self?.delegate?.loadingFailed(loader: nil, error: error)
            }
        }
    }
    
    func cancelLoad() {
        mediaFoldersLoader?.cancelLoad()
        mediaFoldersLoader?.callback = nil
        mediaFoldersLoader = nil
        
        artistsLoader?.cancelLoad()
        artistsLoader?.callback = nil
        artistsLoader = nil
    }
    
    // MARK: Overrides
    
    var itemType: String {
        fatalError("Must override this in subclass")
    }
    
    var showCoverArt: Bool {
        fatalError("Must override this in subclass")
    }
    
    fileprivate func loadFromCache() {
        fatalError("Must override this in subclass")
    }
    
    fileprivate func loadArtists(completion: @escaping APILoaderCallback) {
        fatalError("Must override this in subclass")
    }
    
    func artist(indexPath: IndexPath) -> Artist? {
        fatalError("Must override this in subclass")
    }
    
    func artistInSearch(indexPath: IndexPath) -> Artist? {
        fatalError("Must override this in subclass")
    }
    
    func search(name: String) {
        fatalError("Must override this in subclass")
    }
    
    func continueSearch() {
        fatalError("Must override this in subclass")
    }
}

final class FolderArtistsViewModel: ArtistsViewModel {
    override var itemType: String { "Folder" }
    override var showCoverArt: Bool { false }
        
    override fileprivate func loadFromCache() {
        mediaFolders = store.mediaFolders(serverId: serverId)
        
        metadata = store.folderArtistMetadata(serverId: serverId, mediaFolderId: mediaFolderId)
        if metadata != nil {
            tableSections = store.folderArtistSections(serverId: serverId, mediaFolderId: mediaFolderId)
            artistIds = store.folderArtistIds(serverId: serverId, mediaFolderId: mediaFolderId)
        } else {
            tableSections.removeAll()
            artistIds.removeAll()
        }
    }
    
    override fileprivate func loadArtists(completion: @escaping APILoaderCallback) {
        artistsLoader = RootFoldersLoader(serverId: serverId, mediaFolderId: mediaFolderId) { [weak self] loader, success, error in
            guard let self = self, let loader = loader as? RootFoldersLoader else { return }
            if success {
                self.metadata = loader.metadata
                self.tableSections = loader.tableSections
                self.artistIds = loader.folderArtistIds
//                self.delegate?.loadingFinished(loader: loader)
            } else {
//                self.delegate?.loadingFailed(loader: loader, error: error)
            }
            self.artistsLoader?.callback = nil
            self.artistsLoader = nil
            completion(loader, success, error)
        }
        artistsLoader?.startLoad()
    }
    
    override func artist(indexPath: IndexPath) -> Artist? {
        let index = tableSections[indexPath.section].position + indexPath.row
        guard index < artistIds.count else { return nil }
        
        return store.folderArtist(serverId: serverId, id: artistIds[index])
    }
    
    override func artistInSearch(indexPath: IndexPath) -> Artist? {
        guard indexPath.row < searchArtistIds.count else { return nil }
        return store.folderArtist(serverId: serverId, id: searchArtistIds[indexPath.row])
    }
    
    override func search(name: String) {
        searchName = name
        searchArtistIds = store.search(folderArtistName: name, serverId: serverId, mediaFolderId: mediaFolderId, offset: 0, limit: searchLimit)
    }
    
    override func continueSearch() {
        if let searchName = searchName, shouldContinueSearch {
            let folderIds = store.search(folderArtistName: searchName, serverId: serverId, mediaFolderId: mediaFolderId, offset: searchArtistIds.count, limit: searchLimit)
            shouldContinueSearch = (folderIds.count == searchLimit)
            searchArtistIds.append(contentsOf: folderIds)
        }
    }
}

final class TagArtistsViewModel: ArtistsViewModel {
    override var itemType: String { "Artist" }
    override var showCoverArt: Bool { true }
    
    override fileprivate func loadFromCache() {
        mediaFolders = store.mediaFolders(serverId: serverId)
        
        metadata = store.tagArtistMetadata(serverId: serverId, mediaFolderId: mediaFolderId)
        if metadata != nil {
            tableSections = store.tagArtistSections(serverId: serverId, mediaFolderId: mediaFolderId)
            artistIds = store.tagArtistIds(serverId: serverId, mediaFolderId: mediaFolderId)
        } else {
            tableSections.removeAll()
            artistIds.removeAll()
        }
    }
    
    override fileprivate func loadArtists(completion: @escaping APILoaderCallback) {
        artistsLoader = RootArtistsLoader(serverId: serverId, mediaFolderId: mediaFolderId) { [weak self] loader, success, error in
            guard let self = self, let loader = loader as? RootArtistsLoader else { return }
            if success {
                self.metadata = loader.metadata
                self.tableSections = loader.tableSections
                self.artistIds = loader.tagArtistIds
//                self.delegate?.loadingFinished(loader: loader)
            } else {
//                self.delegate?.loadingFailed(loader: loader, error: error)
            }
            self.artistsLoader?.callback = nil
            self.artistsLoader = nil
            completion(loader, success, error)
        }
        artistsLoader?.startLoad()
    }
    
    override func artist(indexPath: IndexPath) -> Artist? {
        let index = tableSections[indexPath.section].position + indexPath.row
        guard index < artistIds.count else { return nil }
        
        return store.tagArtist(serverId: serverId, id: artistIds[index])
    }
    
    override func artistInSearch(indexPath: IndexPath) -> Artist? {
        guard indexPath.row < searchArtistIds.count else { return nil }
        return store.tagArtist(serverId: serverId, id: searchArtistIds[indexPath.row])
    }
    
    override func search(name: String) {
        searchName = name
        searchArtistIds = store.search(tagArtistName: name, serverId: serverId, mediaFolderId: mediaFolderId, offset: 0, limit: searchLimit)
    }
    
    override func continueSearch() {
        if let searchName = searchName, shouldContinueSearch {
            let artistIds = store.search(tagArtistName: searchName, serverId: serverId, mediaFolderId: mediaFolderId, offset: searchArtistIds.count, limit: searchLimit)
            shouldContinueSearch = (artistIds.count == searchLimit)
            searchArtistIds.append(contentsOf: artistIds)
        }
    }
}
