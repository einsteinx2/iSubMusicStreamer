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

final class ServerChecker: NSObject {
    @Injected private var store: Store
    @Injected private var settings: Settings
    @Injected private var cacheQueue: CacheQueue
    
    private var statusLoader: StatusLoader?
    
    override init() {
        super.init()
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(checkServer), name: Notifications.checkServer)
    }
    
    deinit {
        cancelLoad()
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    @objc func checkServer() {
        // Check if the subsonic URL is valid by attempting to access the ping.view page,
        // if it's not then display an alert and allow user to change settings if they want.
        // This is in case the user is, for instance, connected to a wifi network but does not
        // have internet access or if the host url entered was wrong.
        if let currentServer = settings.currentServer {
            statusLoader?.cancelLoad()
            statusLoader = StatusLoader(server: currentServer) { [weak self] _, success, error in
                guard let self = self, let statusLoader = self.statusLoader else { return }
                
                if success {
                    if let server = self.settings.currentServer, server.isVideoSupported != statusLoader.isVideoSupported || server.isNewSearchSupported != statusLoader.isNewSearchSupported {
                        
                        server.isVideoSupported = statusLoader.isVideoSupported
                        server.isNewSearchSupported = statusLoader.isNewSearchSupported
                        self.settings.currentServer = server
                        _ = self.store.add(server: server)
                    }
                    
                    if self.settings.isOfflineMode {
                        NotificationCenter.postOnMainThread(name: Notifications.willEnterOnlineMode)
                        // TODO: change the setting value here?
                    }
                    
                    // Since the download queue has been a frequent source of crashes in the past, and we start this on launch automatically potentially resulting in a crash loop, do NOT start the download queue automatically if the app crashed on last launch.
                    if !self.settings.appCrashedOnLastRun {
                        self.cacheQueue.start()
                    }
                } else {
                    if !self.settings.isOfflineMode {
                        DDLogVerbose("[ServerChecker] Loading failed for loading type \(statusLoader.type), entering offline mode. Error: \(error?.localizedDescription ?? "unknown")")
                        NotificationCenter.postOnMainThread(name: Notifications.willEnterOfflineMode)
                        // TODO: change the setting value here?
                    }
                }
                
                HUD.hide()
                self.statusLoader = nil
            }
            statusLoader?.startLoad()
        }
        
        // Check every 30 minutes
        cancelNextServerCheck()
        perform(#selector(checkServer), with: nil, afterDelay: 30 * 60)
    }
    
    func cancelNextServerCheck() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(checkServer), object: nil)
    }
    
    @objc func cancelLoad() {
        statusLoader?.cancelLoad()
        statusLoader?.callback = nil
        statusLoader = nil
        HUD.hide()
    }
}
