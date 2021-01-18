//
//  iSubAppDelegate.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#ifndef iSub_iSubAppDelegate_h
#define iSub_iSubAppDelegate_h

#import <AVKit/AVKit.h>

#define appDelegateS [iSubAppDelegate sharedInstance]

@class BBSplitViewController, PadRootViewController, InitialDetailViewController, LoadingScreen, FMDatabase, SettingsViewController, FolderArtistsViewController, AudioStreamer, StatusLoader, MPMoviePlayerController, AVPlayerViewController, HLSReverseProxyServer, ServerListViewController, Reachability, CustomUITabBarController, CustomUINavigationController;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AppDelegate)
@interface iSubAppDelegate: NSObject <UIApplicationDelegate>

@property (nullable,  strong) StatusLoader *statusLoader;

@property (strong, nonatomic) IBOutlet UIWindow *window;

@property (strong) SettingsViewController *settingsViewController;
@property (strong) UITabBarController *currentTabBarController;
@property (strong) IBOutlet CustomUITabBarController *mainTabBarController;
@property (strong) IBOutlet CustomUITabBarController *offlineTabBarController;
@property (strong) IBOutlet CustomUINavigationController *homeNavigationController;
@property (strong) IBOutlet CustomUINavigationController *artistsNavigationController;
@property (strong) IBOutlet FolderArtistsViewController *rootViewController;
@property (strong) IBOutlet CustomUINavigationController *playlistsNavigationController;
@property (strong) IBOutlet CustomUINavigationController *bookmarksNavigationController;
@property (strong) IBOutlet CustomUINavigationController *playingNavigationController;
@property (strong) IBOutlet CustomUINavigationController *cacheNavigationController;
@property (strong) IBOutlet CustomUINavigationController *chatNavigationController;

@property (strong) ServerListViewController *serverListViewController;

@property (strong) PadRootViewController *padRootViewController;

// Network connectivity objects and variables
//
@property (strong) Reachability *wifiReach;
@property (readonly) BOOL isWifi;

// Multitasking stuff
@property UIBackgroundTaskIdentifier backgroundTask;
@property BOOL isInBackground;

@property BOOL showIntro;

@property (nullable, strong) NSURL *referringAppUrl;

@property (nullable, strong) AVPlayerViewController *videoPlayerController;
@property (nullable, strong) HLSReverseProxyServer *hlsProxyServer;

- (void)backToReferringApp;

+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());

- (void)enterOnlineModeForce;
- (void)enterOfflineModeForce;

- (void)loadFlurryAnalytics;

- (void)reachabilityChanged:(nullable NSNotification *)note;

- (void)showSettings;

- (void)batteryStateChanged:(nullable NSNotification *)notification;

- (void)checkServer;

- (NSString *)zipAllLogFiles;


@end

NS_ASSUME_NONNULL_END

#endif
