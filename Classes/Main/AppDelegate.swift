//
//  AppDelegate.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver
import CocoaLumberjackSwift

// TODO: Refactor to support multiple scenes/windows
@objc final class AppDelegate: UIResponder, UIApplicationDelegate {
    @Injected private var store: Store
    @Injected private var settings: Settings
    @Injected private var player: BassPlayer
    @Injected private var playQueue: PlayQueue
    @Injected private var cache: Cache
    
    @objc static var shared: AppDelegate { UIApplication.shared.delegate as! AppDelegate }
    
    @objc var referringAppUrl: URL?
    
    private let videoPlayer = VideoPlayer()
    private let networkMonitor = NetworkMonitor()
    
    @objc var isWifi: Bool { networkMonitor.isWifi }
    @objc var isNetworkReachable: Bool { networkMonitor.isNetworkReachable }
    
    // MARK: UIApplication Lifecycle
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize database
        store.setup()
        
        // Setup singletons
        // TODO: Don't have so many singletons lol
        settings.setup()
        cache.setup()
        
        // Detect app crash on previous launch
        #if RELEASE
        settings.appCrashedOnLastRun = !settings.appTerminatedCleanly
        settings.appTerminatedCleanly = false
        #endif
        
        // Initialize the lock screen controls
        LockScreenAudioControls.setup()
        
        // Enable console logging for Xcode builds
        #if DEBUG
        DDLog.add(DDOSLogger.sharedInstance)
        #endif
        
        // Enable file logging (Use local time zone when formatting dates)
        let dateFormatter = DateFormatter()
        dateFormatter.formatterBehavior = .behavior10_4
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss:SSS"
        let fileLogger = DDFileLogger()
        fileLogger.logFormatter = DDLogFileFormatterDefault(dateFormatter: dateFormatter)
        fileLogger.rollingFrequency = 60 * 60 * 24 // 24 hour rolling
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.add(fileLogger)
        
        // Set default log level (verbose logs only included in beta builds)
        Defines.setupDefaultLogLevel()
        
        // Log system info
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "Unknown"
        let build = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] ?? "Unknown"
        DDLogInfo("\n---------------------------------\niSub \(version) build \(build) launched\n---------------------------------")
        
        // Check battery state and register for notifications
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(batteryStateChanged), name: UIDevice.batteryStateDidChangeNotification)
        batteryStateChanged()
        
        // Request authorization to send background notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            DDLogInfo("[AppDelegate] Request for local notifications granted: \(granted)")
            if !granted {
                // TODO: Test this alert
                DispatchQueue.main.async(after: 1) {
                    let message = "iSub uses local notifications to let you know if it will be put to sleep while you still have downloads running in the background. If you'd like to receive these notifications, you can enable it in the Settings app."
                    let alert = UIAlertController(title: "Local Notifications", message: message, preferredStyle: .alert)
                    alert.addAction(title: "Open Settings", style: .default) { _ in
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    alert.addCancelAction()
                    UIApplication.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
                }
            }
        }
        
        // Load Flurry
        loadFlurryAnalytics()
        
        return true
    }
    
    // Called if the application terminates without crashing
    func applicationWillTerminate(_ application: UIApplication) {
        // Save settings and state
        settings.appTerminatedCleanly = true
        settings.setup()
        UserDefaults.standard.synchronize()
        
        // Cleanly terminate audio
        UIApplication.shared.endReceivingRemoteControlEvents()
        player.stop()
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .all
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Handle being openned by a URL
        DDLogVerbose("[AppDelegate] url host: \(url.host ?? "nil") path components: \(url.pathComponents)")
        
        if let host = url.host {
            switch host.lowercased() {
            case "play":
                if !player.isPlaying {
                    player.playPause()
                } else {
                    playQueue.playCurrentSong()
                }
            case "pause":
                player.pause()
            case "playpause":
                player.playPause()
            case "next":
                playQueue.playSong(position: playQueue.nextIndex)
            case "prev":
                playQueue.playSong(position: playQueue.prevIndex)
            default: break
            }
            
            if let ref = url["ref"] {
                referringAppUrl = URL(string: ref)
                
                // On the iPad we need to reload the menu table to see the back button
//                if (UIDevice.isPad) {
//                    [self.padRootViewController.menuViewController loadCellContents];
//                }
            }
        }
        
        return true
    }
    
    @objc func backToReferringApp() {
        if let referringAppUrl = referringAppUrl {
            UIApplication.shared.open(referringAppUrl, options: [:], completionHandler: nil)
        }
    }
    
    private func loadFlurryAnalytics() {
        var apiKey: String? = nil
        #if DEBUG
            apiKey = nil
        #elseif RELEASE
            apiKey = "3KK4KKD2PSEU5APF7PNX"
        #elseif BETA
            apiKey = "KNN9DUXQEENZUG4Q12UA"
        #endif
        
        if let apiKey = apiKey {
            Flurry.startSession(apiKey)
            
            // Send basic device model and OS information
            let parameters = ["FirmwareVersion": UIDevice.completeOSVersion, "HardwareVersion": UIDevice.deviceModel]
            Flurry.logEvent("DeviceInfo", withParameters: parameters)
        }
    }
    
    // Disable screen sleep when plugged in (for car use)
    @objc private func batteryStateChanged() {
        if UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full {
            UIApplication.shared.isIdleTimerDisabled = true
        } else if settings.isScreenSleepEnabled {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    // MARK: Offline Mode
    
    // TODO: Listen for entering online/offline mode notifications and handle them (maybe in SceneDelegate?)
    @objc func enterOnlineMode() {
        // TODO: Implement this
//        if (settingsS.isOfflineMode) {
//            [self enterOnlineMode];
//        } else {
//            if (currentReachabilityStatus == ReachableViaWiFi || settingsS.isManualCachingOnWWANEnabled) {
//                if (!cacheQueueManagerS.isQueueDownloading) {
//                    [cacheQueueManagerS startDownloadQueue];
//                }
//            } else {
//                [cacheQueueManagerS stopDownloadQueue];
//            }
//        }
        
        
        // Old implementation
//        if (!self.isOnlineModeAlertShowing) {
//            self.isOnlineModeAlertShowing = YES;
//            if (settingsS.isPopupsEnabled) {
//                NSString *message = @"Network detected, would you like to enter online mode? Any currently playing music will stop.";
//                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Notice" message:message preferredStyle:UIAlertControllerStyleAlert];
//                [alert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
//                    [self enterOnlineModeForce];
//                }]];
//                [alert addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:nil]];
//                [self.window.rootViewController presentViewController:alert animated:YES completion:^{
//                    self.isOnlineModeAlertShowing = NO;
//                }];
//            }
//        }
    }
    
    @objc func enterOfflineMode() {
        // TODO: Implement this
        
        
        // Old implementation
//        if (!self.isNoNetworkAlertShowing) {
//            self.isNoNetworkAlertShowing = YES;
//            if (settingsS.isPopupsEnabled) {
//                NSString *message = @"Server unavailable, would you like to enter offline mode? Any currently playing music will stop.\n\nIf this is just temporary connection loss, select No.";
//                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Notice" message:message preferredStyle:UIAlertControllerStyleAlert];
//                [alert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
//                    [self enterOfflineModeForce];
//                }]];
//                [alert addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:nil]];
//                [self.window.rootViewController presentViewController:alert animated:YES completion:^{
//                    self.isNoNetworkAlertShowing = NO;
//                }];
//            }
//        }
    }
    
    @objc func enterOnlineModeForce() {
        // TODO: Implement this
        
//        if (self.wifiReach.currentReachabilityStatus == NotReachable) return;
//
//        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_WillEnterOnlineMode];
//
//        settingsS.isOfflineMode = NO;
//
//        [audioEngineS.player stop];
//
//        if (UIDevice.isPad) {
//            [self.padRootViewController.menuViewController toggleOfflineMode];
//        } else {
//            [self.offlineTabBarController.view removeFromSuperview];
//        }
//
//        [databaseS closeAllDatabases];
//        [databaseS setupDatabases];
//        [self checkServer];
//        [cacheQueueManagerS startDownloadQueue];
//
//        if (UIDevice.isPad) {
//            [NSNotificationCenter postNotificationToMainThreadWithName:Notifications.showPlayer];
//        } else {
//    //        [viewObjectsS orderMainTabBarController];
//            self.window.rootViewController = self.mainTabBarController;
//        }
//
//        [musicS updateLockScreenInfo];
    }
    
    @objc func enterOfflineModeForce() {
        // TODO: Implement this
        
//        if (settingsS.isOfflineMode) {
//            return;
//        }
//
//        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_WillEnterOfflineMode];
//
//        settingsS.isJukeboxEnabled = NO;
//        self.window.backgroundColor = viewObjectsS.windowColor;
//        [Flurry logEvent:@"JukeboxDisabled"];
//
//        settingsS.isOfflineMode = YES;
//
//        [audioEngineS.player stop];
//        [streamManagerS cancelAllStreams];
//        [cacheQueueManagerS stopDownloadQueue];
//
//        if (UIDevice.isPad) {
//            [self.padRootViewController.menuViewController toggleOfflineMode];
//        } else {
//            [self.mainTabBarController.view removeFromSuperview];
//        }
//
//        [databaseS closeAllDatabases];
//        [databaseS setupDatabases];
//
//        if (UIDevice.isPad) {
//            [NSNotificationCenter postNotificationToMainThreadWithName:Notifications.showPlayer];
//        } else {
//            self.currentTabBarController = self.offlineTabBarController;
//            self.window.rootViewController = self.offlineTabBarController;
//        }
//
//        [musicS updateLockScreenInfo];
    }
}
