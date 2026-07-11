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
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    @Injected private var settings: SavedSettings
    @Injected private var session: ServerSession
    @Injected private var bootstrap: AppBootstrap
    @Injected private var downloadQueue: DownloadQueueing
    @Injected private var playQueue: PlayQueue
    @Injected private var downloadEngine: DownloadEngine
    @Injected private var jukebox: Jukebox
    @Injected private var analytics: Analytics
    @Injected private var stateRestorer: StateRestorer
    @Injected private var nowPlayingService: NowPlayingService
    @Injected private var playbackCoordinator: PlaybackCoordinator

    // Temporary singleton access until multiple scenes are properly supported
    static var shared: SceneDelegate { UIApplication.shared.connectedScenes.first!.delegate as! SceneDelegate }
    
    var window: UIWindow?
    private(set) var tabBarController: CustomUITabBarController?
    private(set) var padRootViewController: PadRootViewController?
        
    @Injected private var networkMonitor: NetworkMonitor
    
    var isWifi: Bool { networkMonitor.isWifi }
    var isNetworkReachable: Bool { networkMonitor.isNetworkReachable }
    
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
        window.backgroundColor = settings.isJukeboxEnabled ? Colors.jukeboxWindow : Colors.window
        
        if UIDevice.isPad {
            let padRootViewController = PadRootViewController()
            self.padRootViewController = padRootViewController
            window.rootViewController = CustomRootViewController(mainViewController: padRootViewController)
        } else {
            let tabBarController = CustomUITabBarController()
            self.tabBarController = tabBarController
            window.rootViewController = CustomRootViewController(mainViewController: tabBarController)
        }
        window.makeKeyAndVisible()
        self.window = window
        
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
        
        // TODO: Handle these properly for multiple scenes/windows
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(showPlayer), name: Notifications.showPlayer)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(jukeboxToggled), name: Notifications.jukeboxDisabled)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(jukeboxToggled), name: Notifications.jukeboxEnabled)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(enterOnlineMode), name: Notifications.goOnline)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(enterOfflineMode), name: Notifications.goOffline)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(showJukeboxError(notification:)), name: Notifications.jukeboxError)
        
        // Recover current state if player was interrupted
        bootstrap.sceneDidConnect()
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
        if !hasPerformedLaunchOfflineCheck {
            hasPerformedLaunchOfflineCheck = true
            performLaunchOfflineCheck()
        } else if networkMonitor.isNetworkReachable {
            serverChecker.checkServer()
        } else {
            enterOfflineMode()
        }
    }

    private var hasPerformedLaunchOfflineCheck = false

    // Decides whether to enter offline mode at launch and, if so, with which alert
    // message (nil means stay online). Static and internal for test access.
    static func launchOfflineAlertMessage(isForceOfflineMode: Bool, isNetworkReachable: Bool, isWifi: Bool, isDisableUsageOver3G: Bool) -> String? {
        if isForceOfflineMode {
            return "Offline mode switch on, entering offline mode."
        } else if !isNetworkReachable {
            return "No network detected, entering offline mode."
        } else if !isWifi && isDisableUsageOver3G {
            return "You are not on Wifi, and have chosen to disable use over cellular. Entering offline mode."
        }
        return nil
    }

    // Reproduces the old app's launch behavior (iSubAppDelegate.m): enter offline mode
    // when the force-offline switch is on, there's no network, or we're on cellular
    // with cellular usage disabled - presenting the explanatory alert when popups are
    // enabled - and only check the server when staying online
    private func performLaunchOfflineCheck() {
        let alertMessage = Self.launchOfflineAlertMessage(isForceOfflineMode: settings.isForceOfflineMode,
                                                          isNetworkReachable: isNetworkReachable,
                                                          isWifi: isWifi,
                                                          isDisableUsageOver3G: settings.isDisableUsageOver3G)
        if let alertMessage {
            if settings.isOfflineMode {
                // Already offline (the mode was set before the UI loaded): still announce
                // it so the offline indicator banner and controls update
                NotificationCenter.postOnMainThread(name: Notifications.didEnterOfflineMode)
            } else {
                enterOfflineMode()
            }
            if settings.isPopupsEnabled {
                DispatchQueue.main.async(after: 1.1) {
                    let alert = UIAlertController(title: "Notice", message: alertMessage, preferredStyle: .alert)
                    alert.addOKAction()
                    UIApplication.keyWindow?.rootViewController?.present(alert, animated: true)
                }
            }
        } else {
            serverChecker.checkServer()
        }
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
        nowPlayingService.refresh()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        stateRestorer.saveState()
        UserDefaults.standard.synchronize()
        
        if downloadQueue.isDownloading {
            backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: backgroundTaskExpirationHandler)
            isInBackground = true
            checkRemainingBackgroundTime()
        }
    }
    
    func showSettings() {
        if UIDevice.isPad {
            padRootViewController?.menuViewController.showSettings()
        } else {
            // The Settings tab's navigation stack is built in createTabs(); on first
            // run it already holds root + server list in one operation
            tabBarController?.selectedIndex = CustomUITabBarController.TabType.settings.rawValue
        }
    }
    
    @objc  func showPlayer() {
        guard !UIDevice.isPad else { return }
        DispatchQueue.mainSyncSafe {
            tabBarController?.selectedIndex = CustomUITabBarController.TabType.player.rawValue
        }
    }
    
    @objc private func jukeboxToggled() {
        window?.backgroundColor = settings.isJukeboxEnabled ? Colors.jukeboxWindow : Colors.window
    }

    // The jukebox posts errors instead of presenting alerts itself (Phase 8.9)
    @objc private func showJukeboxError(notification: Notification) {
        let title = notification.userInfo?["title"] as? String ?? "Error"
        let message = notification.userInfo?["message"] as? String ?? "There was an error controlling the Jukebox."
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addOKAction()
        UIApplication.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
    }
    
    @objc private func enterOnlineMode() {
        session.enterOnlineMode(isNetworkReachable: isNetworkReachable,
                                isWifi: isWifi,
                                isForceOfflineMode: settings.isForceOfflineMode,
                                isDisableUsageOver3G: settings.isDisableUsageOver3G)
    }

    @objc private func enterOfflineMode() {
        guard session.enterOfflineMode() else { return }

        if settings.isJukeboxEnabled {
            playbackCoordinator.setJukeboxEnabled(false)
            analytics.log(event: .jukeboxDisabled)
        }
    }
    
    // MARK: Multitasking
    
    private func backgroundTaskExpirationHandler() {
        // App is about to be put to sleep, stop the download queue
        if downloadQueue.isDownloading {
            downloadQueue.stop()
        }
        
        // Make sure to end the background so we don't get killed by the OS
        cancelBackgroundTask()
        
        // Cancel the next server check otherwise it will fire immediately on launch
        serverChecker.cancelNextServerCheck()
    }
    
    @objc private func checkRemainingBackgroundTime() {
        let timeRemaining = UIApplication.shared.backgroundTimeRemaining
        DDLogVerbose("checking remaining background time: \(timeRemaining) isInBackground: \(isInBackground)")
        
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(checkRemainingBackgroundTime), object: nil)
        guard isInBackground else { return }
        
        if timeRemaining < 30 && downloadQueue.isDownloading {
            // Warn at 30 second mark if download queue is downloading
            // TODO: Test this implementation
            let content = UNMutableNotificationContent()
            content.body = "Songs are still downloading. Please return to iSub within 30 seconds, or it will be put to sleep."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        } else if !downloadQueue.isDownloading {
            // Cancel the next server check otherwise it will fire immediately on launch
            // TODO: See if this is necessary since the expiration handler should fire and handle it...
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
    
    func popLibraryTab() {
        if UIDevice.isPad {
            padRootViewController?.menuViewController.popLibraryTab()
        } else {
            tabBarController?.popLibraryTab()
        }
    }
}
