//
//  TagArtistsViewModel.swift
//  iSub
//
//  Created by Benjamin Baron on 1/6/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

final class TagArtistsViewModel: ArtistsViewModel {
    @Injected private var store: Store
    
    weak var delegate: APILoaderDelegate?
    var serverId = Settings.shared().currentServerId
    var mediaFolderId: Int {
        didSet {
            loadFromCache()
        }
    }
    
    private var metadata: RootListMetadata?
    var tableSections = [TableSection]()
    
    var isCached: Bool { metadata != nil }
    var count: Int { metadata?.itemCount ?? 0 }
    var searchCount: Int { searchTagArtistIds.count }
    var reloadDate: Date? { metadata?.reloadDate }
    
    private var loader: RootArtistsLoader?
    private var tagArtistIds = [Int]()
    private var searchTagArtistIds = [Int]()
    private let searchLimit = 100
    private var searchName: String?
    private(set) var shouldContinueSearch = true
    
    init(mediaFolderId: Int, delegate: APILoaderDelegate? = nil) {
        self.mediaFolderId = mediaFolderId
        self.delegate = delegate
    }
    
    deinit {
        cancelLoad()
    }
    
    private func loadFromCache() {
        metadata = store.tagArtistMetadata(serverId: serverId, mediaFolderId: mediaFolderId)
        if metadata != nil {
            tableSections = store.tagArtistSections(serverId: serverId, mediaFolderId: mediaFolderId)
            tagArtistIds = store.tagArtistIds(serverId: serverId, mediaFolderId: mediaFolderId)
        } else {
            tableSections.removeAll()
            tagArtistIds.removeAll()
        }
    }
    
    func reset() {
        loader?.cancelLoad()
        loader?.delegate = nil
        loader = nil
        
        metadata = nil
        tableSections.removeAll()
        tagArtistIds.removeAll()
        searchTagArtistIds.removeAll()
        searchName = nil
        shouldContinueSearch = true
        
        loadFromCache()
    }
    
    func artist(indexPath: IndexPath) -> Artist? {
        let index = tableSections[indexPath.section].position + indexPath.row
        guard index < tagArtistIds.count else { return nil }
        
        return store.tagArtist(serverId: serverId, id: tagArtistIds[index])
    }
    
    func artistInSearch(indexPath: IndexPath) -> Artist? {
        guard indexPath.row < searchTagArtistIds.count else { return nil }
        return store.tagArtist(serverId: serverId, id: searchTagArtistIds[indexPath.row])
    }
    
    func clearSearch() {
        searchTagArtistIds.removeAll()
        searchName = nil
        shouldContinueSearch = true
    }
    
    func search(name: String) {
        searchName = name
        searchTagArtistIds = store.search(tagArtistName: name, serverId: serverId, mediaFolderId: mediaFolderId, offset: 0, limit: searchLimit)
    }
    
    func continueSearch() {
        if let searchName = searchName, shouldContinueSearch {
            let artistIds = store.search(tagArtistName: searchName, serverId: serverId, mediaFolderId: mediaFolderId, offset: searchTagArtistIds.count, limit: searchLimit)
            shouldContinueSearch = (artistIds.count == searchLimit)
            searchTagArtistIds.append(contentsOf: artistIds)
        }
    }
}

extension TagArtistsViewModel: APILoaderManager {
    func startLoad() {
        cancelLoad()
        
        loader = RootArtistsLoader(serverId: serverId, mediaFolderId: mediaFolderId, delegate: self)
        loader?.startLoad()
    }
    
    func cancelLoad() {
        loader?.cancelLoad()
        loader?.delegate = nil
        loader = nil
    }
}

extension TagArtistsViewModel: APILoaderDelegate {
    func loadingFinished(loader: AbstractAPILoader?) {
        if let loader = loader as? RootArtistsLoader {
            metadata = loader.metadata
            tableSections = loader.tableSections
            tagArtistIds = loader.tagArtistIds
        }
        
        self.loader?.delegate = nil
        self.loader = nil
        delegate?.loadingFinished(loader: nil)
    }
    
    func loadingFailed(loader: AbstractAPILoader?, error: Error?) {
        self.loader?.delegate = nil
        self.loader = nil
        delegate?.loadingFailed(loader: nil, error: error)
    }
}
