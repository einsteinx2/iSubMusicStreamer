//
//  NetworkMonitor.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver
import CocoaLumberjackSwift
import ProgressHUD
import Reachability

final class NetworkMonitor {
    @Injected private var settings: SavedSettings
    
    private let wifiReach: Reachability? = {
        do {
            return try Reachability()
        } catch {
            DDLogError("[NetworkMonitor] Failed to create Reachability object, there will be no network change notifications")
            return nil
        }
    }()
    var isWifi: Bool {
        wifiReach?.connection == .wifi
    }
    var isNetworkReachable: Bool {
        wifiReach?.connection != .unavailable
    }
    
    init() {
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reachabilityChanged(notification:)), name: Notification.Name.reachabilityChanged)
        do {
            try wifiReach?.startNotifier()
            let _ = wifiReach?.connection
        } catch {
            DDLogError("[NetworkMonitor] Failed to start Reachability notifier, there will be no network change notifications")
        }
    }
    
    deinit {
        wifiReach?.stopNotifier()
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    @objc private func reachabilityChanged(notification: Notification) {
        guard !settings.isForceOfflineMode, let status = wifiReach?.connection else { return }
        
        DDLogVerbose("[NetworkMonitor] Reachability changed to \(status)")
        
        if status == .unavailable {
            // Change over to offline mode
            if !settings.isOfflineMode {
                DDLogVerbose("[NetworkMonitor] Reachability changed to unavailable, entering offline mode")
                NotificationCenter.postOnMainThread(name: Notifications.goOffline)
            }
        } else if status == .cellular && settings.isDisableUsageOver3G {
            // Change over to offline mode
            if !settings.isOfflineMode {
                DDLogVerbose("[NetworkMonitor] Reachability changed to cellular and usage over cellular is disabled, entering offline mode")
                NotificationCenter.postOnMainThread(name: Notifications.goOffline)
                ProgressHUD.banner("You have chosen to disable usage over cellular in settings and are no longer on Wifi. Entering offline mode.", nil)
            }
        } else {
            // Check that the server is available before entering online mode
            NotificationCenter.postOnMainThread(name: Notifications.checkServer)
        }
    }
}
