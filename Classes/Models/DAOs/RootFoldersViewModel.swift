//
//  RootFoldersDAO.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

@objc final class RootFoldersViewModel: NSObject {
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
    @objc var searchCount: Int { searchFolderArtistIds.count }
    @objc var reloadDate: Date? { metadata?.reloadDate }
    
    private var loader: RootFoldersLoader?
    private var folderArtistIds = [Int]()
    private var searchFolderArtistIds = [Int]()
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
        metadata = store.folderArtistMetadata(serverId: serverId, mediaFolderId: mediaFolderId)
        if metadata != nil {
            tableSections = store.folderArtistSections(serverId: serverId, mediaFolderId: mediaFolderId)
            folderArtistIds = store.folderArtistIds(serverId: serverId, mediaFolderId: mediaFolderId)
        } else {
            tableSections.removeAll()
            folderArtistIds.removeAll()
        }
    }
    
    @objc func folderArtist(indexPath: IndexPath) -> FolderArtist? {
        let index = tableSections[indexPath.section].position + indexPath.row
        guard index < folderArtistIds.count else { return nil }
        
        return store.folderArtist(serverId: serverId, id: folderArtistIds[index])
    }
    
    @objc func folderArtistInSearch(indexPath: IndexPath) -> FolderArtist? {
        guard indexPath.row < searchFolderArtistIds.count else { return nil }
        return store.folderArtist(serverId: serverId, id: searchFolderArtistIds[indexPath.row])
    }
    
    @objc func clearSearch() {
        searchFolderArtistIds.removeAll()
        searchName = nil
        shouldContinueSearch = true
    }
    
    @objc func search(name: String) {
        searchName = name
        searchFolderArtistIds = store.search(folderArtistName: name, serverId: serverId, mediaFolderId: mediaFolderId, offset: 0, limit: searchLimit)
    }
    
    @objc func continueSearch() {
        if let searchName = searchName, shouldContinueSearch {
            let folderIds = store.search(folderArtistName: searchName, serverId: serverId, mediaFolderId: mediaFolderId, offset: searchFolderArtistIds.count, limit: searchLimit)
            shouldContinueSearch = (folderIds.count == searchLimit)
            searchFolderArtistIds.append(contentsOf: folderIds)
        }
    }
}

extension RootFoldersViewModel: APILoaderManager {
    func startLoad() {
        cancelLoad()
        
        loader = RootFoldersLoader(delegate: self)
        loader?.mediaFolderId = mediaFolderId
        loader?.startLoad()
    }
    
    func cancelLoad() {
        loader?.cancelLoad()
        loader?.delegate = nil
        loader = nil
    }
}

extension RootFoldersViewModel: APILoaderDelegate {
    func loadingFinished(loader: APILoader?) {
        if let loader = loader as? RootFoldersLoader {
            metadata = loader.metadata
            tableSections = loader.tableSections
            folderArtistIds = loader.folderArtistIds
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
