//
//  iSubAppDelegate.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#ifndef iSub_iSubAppDelegate_h
#define iSub_iSubAppDelegate_h

#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>

#import "ISMSLoaderDelegate.h"
#import "EX2Reachability.h"
#import "HockeySDK.h"

#define appDelegateS [iSubAppDelegate sharedInstance]

@class BBSplitViewController, iPadRootViewController, InitialDetailViewController, LoadingScreen, FMDatabase, iPhoneStreamingPlayerViewController, SettingsViewController, FoldersViewController, AudioStreamer, IntroViewController, ISMSStatusLoader, MPMoviePlayerController, HTTPServer, ServerListViewController;

@interface iSubAppDelegate : NSObject <UIApplicationDelegate, MFMailComposeViewControllerDelegate, BITHockeyManagerDelegate, BITCrashManagerDelegate, ISMSLoaderDelegate>

@property (strong) HTTPServer *hlsProxyServer;

@property (strong) ISMSStatusLoader *statusLoader;

@property (strong, nonatomic) IBOutlet UIWindow *window;

@property (strong) IntroViewController *introController;
@property (strong) SettingsViewController *settingsViewController;
@property (strong) IBOutlet UIImageView *background;
@property (strong) UITabBarController *currentTabBarController;
@property (strong) IBOutlet UITabBarController *mainTabBarController;
@property (strong) IBOutlet UITabBarController *offlineTabBarController;
@property (strong) IBOutlet UINavigationController *homeNavigationController;
@property (strong) IBOutlet UINavigationController *playerNavigationController;
@property (strong) IBOutlet UINavigationController *artistsNavigationController;
@property (strong) IBOutlet FoldersViewController *rootViewController;
@property (strong) IBOutlet UINavigationController *allAlbumsNavigationController;
@property (strong) IBOutlet UINavigationController *allSongsNavigationController;
@property (strong) IBOutlet UINavigationController *playlistsNavigationController;
@property (strong) IBOutlet UINavigationController *bookmarksNavigationController;
@property (strong) IBOutlet UINavigationController *playingNavigationController;
@property (strong) IBOutlet UINavigationController *genresNavigationController;
@property (strong) IBOutlet UINavigationController *cacheNavigationController;
@property (strong) IBOutlet UINavigationController *chatNavigationController;
@property (strong) UINavigationController *supportNavigationController;

@property (strong) ServerListViewController *serverListViewController;

@property (strong) iPadRootViewController *ipadRootViewController;

// Network connectivity objects and variables
//
@property (strong) EX2Reachability *wifiReach;
@property (readonly) BOOL isWifi;

// Multitasking stuff
@property UIBackgroundTaskIdentifier backgroundTask;
@property BOOL isInBackground;

@property BOOL showIntro;

@property (strong) NSURL *referringAppUrl;

@property (strong) MPMoviePlayerController *moviePlayer;

- (void)backToReferringApp;

+ (iSubAppDelegate *)sharedInstance;

- (void)enterOnlineModeForce;
- (void)enterOfflineModeForce;

- (void)loadFlurryAnalytics;
- (void)loadHockeyApp;
//- (void)loadCrittercism;
- (void)loadInAppPurchaseStore;

- (void)reachabilityChanged:(NSNotification *)note;
- (NSInteger)getHour;

- (void)showSettings;

//- (BOOL)isWifi;

- (void)batteryStateChanged:(NSNotification *)notification;

- (void)startRedirectingLogToFile;
- (void)stopRedirectingLogToFile;

- (void)checkServer;

- (NSString *)zipAllLogFiles;

- (void)checkWaveBoxRelease;


@end

#endif

