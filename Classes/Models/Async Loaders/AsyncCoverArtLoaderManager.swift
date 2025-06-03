//
//  AsyncCoverArtLoaderManager.swift
//  iSub
//
//  Created by Ben Baron on 6/3/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

struct CoverArtLoadingId: Equatable, Hashable {
    let serverId: Int
    let coverArtId: String
    let isLarge: Bool
}

private actor SharedLoadingIds {
    private var loadingIds = Set<CoverArtLoadingId>()
    private var tasks = [CoverArtLoadingId: Task<CoverArt, Error>]()
    
    func insert(id: CoverArtLoadingId, task: Task<CoverArt, Error>) {
        loadingIds.insert(id)
        tasks[id] = task
    }
    
    func remove(id: CoverArtLoadingId) {
        loadingIds.remove(id)
        tasks[id] = nil
    }
    
    func contains(id: CoverArtLoadingId) -> Bool {
        loadingIds.contains(id)
    }
    
    func cancel(id: CoverArtLoadingId) {
        if let task = tasks[id] {
            task.cancel()
            remove(id: id)
        }
    }
}

final class AsyncCoverArtLoaderManager {
    @Injected private var store: Store
    @Injected private var settings: SavedSettings
    
    // Shared instance, use this in the app normally, or create a new insance for unit tests
    static let shared = AsyncCoverArtLoaderManager()
    
    private var loadingIds = SharedLoadingIds()
    
    static func defaultCoverArtImage(isLarge: Bool) -> UIImage? {
        isLarge ? UIImage(named: "default-album-art") : UIImage(named: "default-album-art-small")
    }
    
    func isCached(loadingId: CoverArtLoadingId) -> Bool {
        isCached(serverId: loadingId.serverId, coverArtId: loadingId.coverArtId, isLarge: loadingId.isLarge)
    }
    
    func isCached(serverId: Int, coverArtId: String, isLarge: Bool) -> Bool {
        store.isCoverArtCached(serverId: serverId, id: coverArtId, isLarge: isLarge)
    }
    
    func coverArtImage(loadingId: CoverArtLoadingId) -> UIImage? {
        coverArtImage(serverId: loadingId.serverId, coverArtId: loadingId.coverArtId, isLarge: loadingId.isLarge)
    }
    
    func coverArtImage(serverId: Int, coverArtId: String, isLarge: Bool) -> UIImage? {
        store.coverArt(serverId: serverId, id: coverArtId, isLarge: isLarge)?.image ?? Self.defaultCoverArtImage(isLarge: isLarge)
    }
    
    func download(loadingId: CoverArtLoadingId) async -> CoverArt? {
        await download(serverId: loadingId.serverId, coverArtId: loadingId.coverArtId, isLarge: loadingId.isLarge)
    }
    
    func download(serverId: Int, coverArtId: String, isLarge: Bool) async -> CoverArt? {
        let loadingId = CoverArtLoadingId(serverId: serverId, coverArtId: coverArtId, isLarge: isLarge)
        do {
            let isLoading = await loadingIds.contains(id: loadingId)
            if !isCached(serverId: serverId, coverArtId: coverArtId, isLarge: isLarge) && !isLoading {
                let task = Task {
                    let loader = AsyncCoverArtLoader(serverId: serverId, coverArtId: coverArtId, isLarge: isLarge)
                    let coverArt = try await loader.load()
                    await loadingIds.remove(id: loadingId)
                    
                    guard store.add(coverArt: coverArt) else {
                        throw APIError.database
                    }
                    
                    if isLarge {
                        NotificationCenter.postOnMainThread(name: Notifications.albumArtLargeDownloaded)
                    }
                    
                    return coverArt
                }
                
                await loadingIds.insert(id: loadingId, task: task)
                let coverArt = try await task.value
                await loadingIds.remove(id: loadingId)
                return coverArt
            }
        } catch is CancellationError {
            await loadingIds.remove(id: loadingId)
        } catch {
            DDLogError("[AsyncCoverArtLoaderManager] failed to download cover art \(loadingId): \(error)")
            await loadingIds.remove(id: loadingId)
        }
        return nil
    }
    
    func cancel(loadingId: CoverArtLoadingId) async {
        await cancel(serverId: loadingId.serverId, coverArtId: loadingId.coverArtId, isLarge: loadingId.isLarge)
    }
        
    func cancel(serverId: Int, coverArtId: String, isLarge: Bool) async {
        let loadingId = CoverArtLoadingId(serverId: serverId, coverArtId: coverArtId, isLarge: isLarge)
        await loadingIds.cancel(id: loadingId)
    }
}
