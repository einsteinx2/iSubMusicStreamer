//
//  CoverArtLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/8/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

@objc final class CoverArtLoader: APILoader {
    @Injected private var store: Store
    @Injected private var settings: Settings
    
    private struct PrivateNotifications {
        static let downloadFinished = Notification.Name("CoverArtLoader.downloadFinished")
        static let downloadFailed = Notification.Name("CoverArtLoader.downloadFailed")
    }
        
    private static var syncObject = NSObject()
    private static var loadingIds = Set<String>()
    
    let serverId: Int
    let coverArtId: String
    let isLarge: Bool
    
    private var mergedId: String {
        return "\(serverId)_\(coverArtId)"
    }
    
    @objc var isCached: Bool {
        return store.isCoverArtCached(serverId: serverId, id: coverArtId, isLarge: isLarge)
    }
    
    @objc init(serverId: Int, coverArtId: String, isLarge: Bool, delegate: APILoaderDelegate? = nil, callback: LoaderCallback? = nil) {
        self.serverId = serverId
        self.coverArtId = coverArtId
        self.isLarge = isLarge
        super.init(delegate: delegate, callback: callback)
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(coverArtDownloadFinished(notification:)), name: PrivateNotifications.downloadFinished)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(coverArtDownloadFailed(notification:)), name: PrivateNotifications.downloadFailed)
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    @objc func downloadArtIfNotExists() -> Bool {
        if !isCached {
            startLoad()
            return true
        }
        return false
    }
    
    // MARK: Notifications
    
    @objc private func coverArtDownloadFinished(notification: Notification) {
        if let id = notification.object as? String, id == mergedId {
            if isLarge {
                NotificationCenter.postOnMainThread(name: Notifications.albumArtLargeDownloaded)
            }
            informDelegateLoadingFinished()
        }
    }
    
    @objc private func coverArtDownloadFailed(notification: Notification) {
        if let id = notification.object as? String, id == mergedId {
            informDelegateLoadingFailed(error: nil)
        }
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .coverArt }
    
    override func createRequest() -> URLRequest? {
        synchronized(Self.syncObject) { () -> URLRequest? in
            if !settings.isOfflineMode && !isCached && !Self.loadingIds.contains(mergedId) {
                Self.loadingIds.insert(mergedId)
                let scale = UIScreen.main.scale
                var size = scale * 80
                if isLarge {
                    size = UIDevice.isPad() ? scale * 1080 : scale * 640
                }
                return URLRequest(serverId: serverId, subsonicAction: "getCoverArt", parameters: ["id": coverArtId, "size": size])
            }
            return nil
        }
    }
    
    override func processResponse(data: Data) {
        synchronized(Self.syncObject) {
            _ = Self.loadingIds.remove(mergedId)
        }
                
        // Check to see if the data is a valid image. If so, use it; if not, use the default image.
        let coverArt = CoverArt(serverId: serverId, id: coverArtId, isLarge: isLarge, data: data)
        if coverArt.image == nil {
            DDLogError("[SUSCoverArtLoader] art loading failed for server: \(serverId) id: \(coverArtId)")
            NotificationCenter.postOnMainThread(name: PrivateNotifications.downloadFailed, object: mergedId)
        } else {
            DDLogInfo("[SUSCoverArtLoader] art loading completed for server: \(serverId) id: \(coverArtId)")
            _ = store.add(coverArt: coverArt)
            NotificationCenter.postOnMainThread(name: PrivateNotifications.downloadFinished, object: mergedId)
        }
    }
    
    @objc override func cancelLoad() {
        super.cancelLoad()
        synchronized(Self.syncObject) {
            _ = Self.loadingIds.remove(mergedId)
        }
    }
    
    override func informDelegateLoadingFailed(error: Error?) {
        synchronized(Self.syncObject) {
            _ = Self.loadingIds.remove(mergedId)
        }
        NotificationCenter.postOnMainThread(name: PrivateNotifications.downloadFinished, object: coverArtId, userInfo: nil)
    }
}
