//
//  ServerChecker.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver
import CocoaLumberjackSwift

final class ServerChecker {
    @Injected private var store: Store
    @Injected private var settings: SavedSettings
    @Injected private var downloadQueue: DownloadQueue
        
    private var task: Task<Void, Never>?
    
    init() {
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(checkServer), name: Notifications.checkServer)
    }
    
    deinit {
        task?.cancel()
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    @objc func checkServer() {
        task?.cancel()
        
        // Check if the subsonic URL is valid by attempting to access the ping.view page,
        // if it's not then display an alert and allow user to change settings if they want.
        // This is in case the user is, for instance, connected to a wifi network but does not
        // have internet access or if the host url entered was wrong.
        task = Task { [weak self] in
            while !Task.isCancelled, let self {
                do {
                    if let currentServer = settings.currentServer {
                        let loader = AsyncStatusLoader(server: currentServer)
                        let responseData = try await loader.load()
                        
                        if let server = settings.currentServer, server.isVideoSupported != responseData.isVideoSupported || server.isNewSearchSupported != responseData.isNewSearchSupported {
                            server.isVideoSupported = responseData.isVideoSupported
                            server.isNewSearchSupported = responseData.isNewSearchSupported
                            settings.currentServer = server
                            _ = store.add(server: server)
                        }
                        
                        if settings.isOfflineMode {
                            NotificationCenter.postOnMainThread(name: Notifications.goOnline)
                            // TODO: change the setting value here?
                        }
                        
                        // Since the download queue has been a frequent source of crashes in the past, and we start this on launch automatically potentially resulting in a crash loop, do NOT start the download queue automatically if the app crashed on last launch.
                        if !settings.appCrashedOnLastRun {
                            downloadQueue.start()
                        }
                    }
                } catch {
                    if !settings.isOfflineMode, !error.isCanceled {
                        DDLogError("[ServerChecker] Status loader failed, entering offline mode. Error: \(error)")
                        NotificationCenter.postOnMainThread(name: Notifications.goOffline)
                        // TODO: change the setting value here?
                    }
                }
                
                // Sleep for 30 minutes (30 * 60 seconds = 1800 seconds * 1 billion for nanoseconds)
                try? await Task.sleep(nanoseconds: 1_800_000_000_000)
            }
        }
    }

    func cancelNextServerCheck() {
        task?.cancel()
        task = nil
    }
}
