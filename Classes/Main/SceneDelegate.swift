//
//  SceneDelegate.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver
import CocoaLumberjackSwift

// TODO: Refactor to support multiple scenes/windows
@objc final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    @Injected private var settings: Settings
    @Injected private var cacheQueue: CacheQueue
    @Injected private var playQueue: PlayQueue
    @Injected private var streamManager: StreamManager
    
    // Temporary singleton access until multiple scenes are properly supported
    @objc static var shared: SceneDelegate { UIApplication.shared.connectedScenes.first!.delegate as! SceneDelegate }
    
    @objc var window: UIWindow?
    @objc private(set) var tabBarController: CustomUITabBarController?
    @objc private(set) var padRootViewController: PadRootViewController?
    
    // TODO: Get rid of these
    @objc private(set) var foldersTab: CustomUINavigationController?
    @objc private(set) var artistsTab: CustomUINavigationController?
    
    private let serverChecker = ServerChecker()
    
    private var isInBackground = false
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid
    
    // MARK: Scene lifecycle
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = scene as? UIWindowScene else { return }

        // Manually create window to remove need for useless Storyboard file
        let window = UIWindow(windowScene: windowScene)
        window.frame = windowScene.coordinateSpace.bounds
        window.backgroundColor = settings.isJukeboxEnabled ? Colors.jukeboxWindowColor : Colors.windowColor
        
        if UIDevice.isPad {
            
        } else {
            // Manually create tab bar controller
            let tabBarController = CustomUITabBarController()
            self.tabBarController = tabBarController
            
            let homeTab = CustomUINavigationController(rootViewController: HomeViewController())
            homeTab.tabBarItem = UITabBarItem(title: "Home", image: UIImage(named: "tabbaricon-home"), tag: 0)
            
            let foldersMediaFolderId = settings.rootFoldersSelectedFolderId?.intValue ?? MediaFolder.allFoldersId
            let foldersDataModel = FolderArtistsViewModel(serverId: settings.currentServerId, mediaFolderId: foldersMediaFolderId)
            let foldersTab = CustomUINavigationController(rootViewController: ArtistsViewController(dataModel: foldersDataModel))
            foldersTab.tabBarItem = UITabBarItem(title: "Folders", image: UIImage(named: "tabbaricon-folders"), tag: 0)
            self.foldersTab = foldersTab
            
            let artistsMediaFolderId = settings.rootArtistsSelectedFolderId?.intValue ?? MediaFolder.allFoldersId
            let artistsDataModel = TagArtistsViewModel(serverId: settings.currentServerId, mediaFolderId: artistsMediaFolderId)
            let artistsTab = CustomUINavigationController(rootViewController: ArtistsViewController(dataModel: artistsDataModel))
            artistsTab.tabBarItem = UITabBarItem(title: "Artists", image: UIImage(named: "tabbaricon-folders"), tag: 0)
            self.artistsTab = artistsTab
            
            let playlistsTab = CustomUINavigationController(rootViewController: PlaylistsViewController())
            playlistsTab.tabBarItem = UITabBarItem(title: "Playlists", image: UIImage(named: "tabbaricon-playlists"), tag: 0)
            
            let downloadsTab = CustomUINavigationController(rootViewController: DownloadsViewController())
            downloadsTab.tabBarItem = UITabBarItem(title: "Downloads", image: UIImage(named: "tabbaricon-cache"), tag: 0)
            
            let bookmarksTab = CustomUINavigationController(rootViewController: BookmarksViewController())
            bookmarksTab.tabBarItem = UITabBarItem(title: "Bookmarks", image: UIImage(named: "tabbaricon-bookmarks"), tag: 0)
            
            let nowPlayingTab = CustomUINavigationController(rootViewController: NowPlayingViewController())
            nowPlayingTab.tabBarItem = UITabBarItem(title: "Playing", image: UIImage(named: "tabbaricon-playing"), tag: 0)
            
            let chatTab = CustomUINavigationController(rootViewController: ChatViewController())
            chatTab.tabBarItem = UITabBarItem(title: "Chat", image: UIImage(named: "tabbaricon-chat"), tag: 0)
            
            tabBarController.viewControllers = [homeTab, foldersTab, artistsTab, playlistsTab, downloadsTab, bookmarksTab, nowPlayingTab, chatTab]
            
            window.rootViewController = tabBarController
        }
        window.makeKeyAndVisible()
        self.window = window
        
        // Handle offline mode
        // TODO: implement this
//        NSString *offlineModeAlertMessage = nil;
//        if (settingsS.isForceOfflineMode) {
//            settingsS.isOfflineMode = YES;
//            offlineModeAlertMessage = @"Offline mode switch on, entering offline mode.";
//        } else if (self.wifiReach.currentReachabilityStatus == NotReachable) {
//            settingsS.isOfflineMode = YES;
//            offlineModeAlertMessage = @"No network detected, entering offline mode.";
//        } else if (self.wifiReach.currentReachabilityStatus == ReachableViaWWAN && settingsS.isDisableUsageOver3G) {
//            settingsS.isOfflineMode = YES;
//            offlineModeAlertMessage = @"You are not on Wifi, and have chosen to disable use over cellular. Entering offline mode.";
//        } else {
//            settingsS.isOfflineMode = NO;
//        }
        
//        // Optionally show offline mode alert
//        if (offlineModeAlertMessage && settingsS.isPopupsEnabled) {
//            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Notice" message:offlineModeAlertMessage preferredStyle:UIAlertControllerStyleAlert];
//            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
//            [EX2Dispatch runInMainThreadAfterDelay:1.1 block:^{
//                [UIApplication.keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
//            }];
//        }
        
        
        
        if settings.currentServer == nil {
            if settings.isOfflineMode {
                DispatchQueue.main.async(after: 1) {
                    let message = "Looks like this is your first time using iSub!\n\nYou'll need an internet connection to get started."
                    let alert = UIAlertController(title: "Welcome!", message: message, preferredStyle: .alert)
                    alert.addOKAction()
                    UIApplication.keyWindow?.rootViewController?.present(alert, animated: true) {
                        self.showSettings()
                    }
                }
            } else {
                showSettings()
            }
        }
        
        // Create and display UI
//        if (UIDevice.isPad) {
//            self.padRootViewController = [[PadRootViewController alloc] initWithNibName:nil bundle:nil];
//            [self.window setBackgroundColor:[UIColor clearColor]];
//            self.window.rootViewController = self.padRootViewController;
//            [self.window makeKeyAndVisible];
//
//            if (self.showIntro) {
//                [self showSettings];
//            }
//        } else {
//            [UITabBar.appearance setBarTintColor:UIColor.blackColor];
//            self.mainTabBarController.tabBar.translucent = NO;
//            self.offlineTabBarController.tabBar.translucent = NO;
//
//            if (settingsS.isOfflineMode) {
//                self.currentTabBarController = self.offlineTabBarController;
//                self.window.rootViewController = self.offlineTabBarController;
//            } else {
//                // Recover the tab order and load the main tabBarController
//                self.currentTabBarController = self.mainTabBarController;
//                self.window.rootViewController = self.mainTabBarController;
//            }
//
//            [self.window makeKeyAndVisible];
//
//            if (self.showIntro) {
//                [self showSettings];
//            }
//        }
        
        // Start checking the server status
        serverChecker.checkServer()
        
        // TODO: Handle these properly for multiple scenes/windows
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(showPlayer), name: Notifications.showPlayer)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(jukeboxToggled), name: Notifications.jukeboxDisabled)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(jukeboxToggled), name: Notifications.jukeboxEnabled)
        
        // Recover current state if player was interrupted
        streamManager.setup()
        playQueue.resumeSong()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        serverChecker.checkServer()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        isInBackground = false
        cancelBackgroundTask()
        
        // Update the lock screen art in case were were using another app
        playQueue.updateLockScreenInfo()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        settings.saveState()
        UserDefaults.standard.synchronize()
        
        if cacheQueue.isDownloading {
            backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: backgroundTaskExpirationHandler)
            isInBackground = true
            checkRemainingBackgroundTime()
        }
    }
    
    @objc func showSettings() {
        if UIDevice.isPad {
            padRootViewController?.menuViewController.showSettings()
        } else if let tabBarController = tabBarController {
            let controller = SettingsViewController()
            controller.hidesBottomBarWhenPushed = true
            
            if tabBarController.selectedIndex >= 4 || tabBarController.selectedIndex == NSNotFound {
                tabBarController.moreNavigationController.pushViewController(controller, animated: true)
            } else if let navigationController = tabBarController.selectedViewController as? UINavigationController {
                navigationController.pushViewController(controller, animated: true)
            }
        }
    }
    
    @objc private func showPlayer() {
        guard !UIDevice.isPad else { return }
        
        let controller = PlayerViewController()
        controller.hidesBottomBarWhenPushed = true
        if let navigationController = tabBarController?.selectedViewController as? UINavigationController {
            navigationController.pushViewController(controller, animated: true)
        }
    }
    
    @objc private func jukeboxToggled() {
        window?.backgroundColor = settings.isJukeboxEnabled ? Colors.jukeboxWindowColor : Colors.windowColor
    }
    
    // MARK: Multitasking
    
    private func backgroundTaskExpirationHandler() {
        // App is about to be put to sleep, stop the cache download queue
        if cacheQueue.isDownloading {
            cacheQueue.stop()
        }
        
        // Make sure to end the background so we don't get killed by the OS
        cancelBackgroundTask()
        
        // Cancel the next server check otherwise it will fire immediately on launch
        serverChecker.cancelLoad()
        serverChecker.cancelNextServerCheck()
    }
    
    @objc private func checkRemainingBackgroundTime() {
        let timeRemaining = UIApplication.shared.backgroundTimeRemaining
        DDLogVerbose("checking remaining background time: \(timeRemaining) isInBackground: \(isInBackground)")
        
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(checkRemainingBackgroundTime), object: nil)
        guard isInBackground else { return }
        
        if timeRemaining < 30 && cacheQueue.isDownloading {
            // Warn at 30 second mark if cache queue is downloading
            // TODO: Test this implementation
            let content = UNMutableNotificationContent()
            content.body = "Songs are still downloading. Please return to iSub within 30 seconds, or it will be put to sleep."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        } else if !cacheQueue.isDownloading {
            // Cancel the next server check otherwise it will fire immediately on launch
            // TODO: See if this is necessary since the expiration handler should fire and handle it...
            serverChecker.cancelLoad()
            serverChecker.cancelNextServerCheck()
            cancelBackgroundTask()
        } else {
            perform(#selector(checkRemainingBackgroundTime), with: nil, afterDelay: 1)
        }
    }
    
    private func cancelBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}
