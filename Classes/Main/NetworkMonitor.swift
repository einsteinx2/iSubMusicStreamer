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

class NetworkMonitor: NSObject {
    @Injected private var settings: Settings
    
    private let wifiReach = Reachability.forInternetConnection()
    var isWifi: Bool { wifiReach.currentReachabilityStatus() == ReachableViaWiFi }
    var isNetworkReachable: Bool { wifiReach.currentReachabilityStatus() != NotReachable }
    
    override init() {
        super.init()
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reachabilityChanged(notification:)), name: NSNotification.Name.reachabilityChanged.rawValue)
        wifiReach.startNotifier()
        
        // TODO: Why was I calling this? I think it's to prime the values but I don't think it's necessary...
        wifiReach.currentReachabilityStatus()
    }
    
    deinit {
        wifiReach.stopNotifier()
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    @objc private func reachabilityChanged(notification: Notification) {
        guard !settings.isForceOfflineMode else { return }
        
        EX2Dispatch.runInMainThreadAsync {
            // Perform the actual check after a few seconds to make sure it's the last message received
            // this prevents a bug where the status changes from wifi to not reachable, but first it receives
            // some messages saying it's still on wifi, then gets the not reachable messages
            // TODO: Check if this bug still exists in iOS 13+
            NSObject.cancelPreviousPerformRequests(withTarget: self)
            self.perform(#selector(self.reachabilityChangedInternal), with: nil, afterDelay: 6)
        }
    }
    
    @objc private func reachabilityChangedInternal() {
        let status = wifiReach.currentReachabilityStatus()
        if status == NotReachable {
            // Change over to offline mode
            if !settings.isOfflineMode {
                DDLogVerbose("[NetworkMonitor] Reachability changed to NotReachable, entering offline mode");
                NotificationCenter.postNotificationToMainThread(name: ISMSNotification_WillEnterOfflineMode)
            }
        } else if status == ReachableViaWWAN && settings.isDisableUsageOver3G {
            // Change over to offline mode
            if !settings.isOfflineMode {
                DDLogVerbose("[NetworkMonitor] Reachability changed to ReachableViaWWAN and usage over 3G is disabled, entering offline mode");
                NotificationCenter.postNotificationToMainThread(name: ISMSNotification_WillEnterOfflineMode)
                SlidingNotification.showOnMainWindow(message: "You have chosen to disable usage over cellular in settings and are no longer on Wifi. Entering offline mode.")
            }
        } else {
            // Check that the server is available before entering online mode
            NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CheckServer)
        }
    }
}
