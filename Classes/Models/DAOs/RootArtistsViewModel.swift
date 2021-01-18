//
//  RootArtistsDAO.swift
//  iSub
//
//  Created by Benjamin Baron on 1/6/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

@objc final class RootArtistsViewModel: NSObject {
    @Injected private var store: Store
    
    @objc weak var delegate: APILoaderDelegate?
    @objc var serverId = Settings.shared().currentServerId
    @objc var mediaFolderId: Int {
        didSet {
            loadFromCache()
        }
    }
    
    private var metadata: RootListMetadata?
    @objc var tableSections = [TableSection]()
    
    @objc var isCached: Bool { metadata != nil }
    @objc var count: Int { metadata?.itemCount ?? 0 }
    @objc var searchCount: Int { searchTagArtistIds.count }
    @objc var reloadDate: Date? { metadata?.reloadDate }
    
    private var loader: RootArtistsLoader?
    private var tagArtistIds = [Int]()
    private var searchTagArtistIds = [Int]()
    private let searchLimit = 100
    private var searchName: String?
    @objc private(set) var shouldContinueSearch = true
    
    @objc init(mediaFolderId: Int, delegate: APILoaderDelegate?) {
        self.mediaFolderId = mediaFolderId
        self.delegate = delegate
        super.init()
        loadFromCache()
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
    
    @objc func tagArtist(indexPath: IndexPath) -> TagArtist? {
        let index = tableSections[indexPath.section].position + indexPath.row
        guard index < tagArtistIds.count else { return nil }
        
        return store.tagArtist(serverId: serverId, id: tagArtistIds[index])
    }
    
    @objc func tagArtistInSearch(indexPath: IndexPath) -> TagArtist? {
        guard indexPath.row < searchTagArtistIds.count else { return nil }
        return store.tagArtist(serverId: serverId, id: searchTagArtistIds[indexPath.row])
    }
    
    @objc func clearSearch() {
        searchTagArtistIds.removeAll()
        searchName = nil
        shouldContinueSearch = true
    }
    
    @objc func search(name: String) {
        searchName = name
        searchTagArtistIds = store.search(tagArtistName: name, serverId: serverId, mediaFolderId: mediaFolderId, offset: 0, limit: searchLimit)
    }
    
    @objc func continueSearch() {
        if let searchName = searchName, shouldContinueSearch {
            let artistIds = store.search(tagArtistName: searchName, serverId: serverId, mediaFolderId: mediaFolderId, offset: searchTagArtistIds.count, limit: searchLimit)
            shouldContinueSearch = (artistIds.count == searchLimit)
            searchTagArtistIds.append(contentsOf: artistIds)
        }
    }
}

extension RootArtistsViewModel: APILoaderManager {
    func startLoad() {
        cancelLoad()
        
        loader = RootArtistsLoader(delegate: self)
        loader?.mediaFolderId = mediaFolderId
        loader?.startLoad()
    }
    
    func cancelLoad() {
        loader?.cancelLoad()
        loader?.delegate = nil
        loader = nil
    }
}

extension RootArtistsViewModel: APILoaderDelegate {
    func loadingFinished(loader: APILoader?) {
        if let loader = loader as? RootArtistsLoader {
            metadata = loader.metadata
            tableSections = loader.tableSections
            tagArtistIds = loader.tagArtistIds
        }
        
        self.loader?.delegate = nil
        self.loader = nil
        delegate?.loadingFinished(loader: nil)
    }
    
    func loadingFailed(loader: APILoader?, error: NSError?) {
        self.loader?.delegate = nil
        self.loader = nil
        delegate?.loadingFailed(loader: nil, error: error)
    }
}
