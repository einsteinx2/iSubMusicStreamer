//
//  iSubAppDelegate.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "iSubAppDelegate.h"
#import "ServerListViewController.h"
#import "FoldersViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "SUSStatusLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "ViewObjectsSingleton.h"
#import "ZipKit.h"
#import "Flurry.h"
#import "AudioEngine.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "CacheSingleton.h"
#import "ISMSStreamManager.h"
#import "ISMSCacheQueueManager.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "Swift.h"
#import <UserNotifications/UserNotifications.h>
#import <CoreFoundation/CoreFoundation.h>
#import <SystemConfiguration/SCNetworkReachability.h>
#import <netinet/in.h>
#import <netdb.h>
#import <arpa/inet.h>

LOG_LEVEL_ISUB_DEFAULT

@interface iSubAppDelegate()
@property (nonatomic) BOOL isNoNetworkAlertShowing;
@property (nonatomic) BOOL isOnlineModeAlertShowing;
@end

@implementation iSubAppDelegate

+ (instancetype)sharedInstance {
	return (iSubAppDelegate*)[UIApplication sharedApplication].delegate;
}

- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    return UIInterfaceOrientationMaskAll;
}

#pragma mark Application lifecycle

- (void)showPlayer {
    PlayerViewController *playerViewController = [[PlayerViewController alloc] init];
    playerViewController.hidesBottomBarWhenPushed = YES;
    [(UINavigationController*)self.currentTabBarController.selectedViewController pushViewController:playerViewController animated:YES];
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    // Make sure audio engine and cache singletons get loaded
	[AudioEngine sharedInstance];
	[CacheSingleton sharedInstance];
    
    // Start the save defaults timer and mem cache initial defaults
	[settingsS setupSaveState];
    
    // Run the one time actions
    [self oneTimeRun];
    
    // Initialize the lock screen controls
    [LockScreenAudioControls setup];
    
    // Adjust the window to the correct size before anything else loads to prevent various sizing/positioning issues
    // NOTE: This is still needed, probably due to the old school XIB file used for the main window
    if (!UIDevice.isIPad) {
        CGSize screenSize = UIScreen.mainScreen.preferredMode.size;
        CGFloat screenScale = UIScreen.mainScreen.scale;
        self.window.size = CGSizeMake(screenSize.width / screenScale, screenSize.height / screenScale);
    }
	
#if !defined(ADHOC) && !defined(RELEASE)
    // Don't turn on console logging for adhoc or release builds
    [DDLog addLogger:[DDOSLogger sharedInstance]];
#endif
    // Use local time zone when formatting dates for logger
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [dateFormatter setDateFormat:@"yyyy/MM/dd HH:mm:ss:SSS"];
	DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
    fileLogger.logFormatter = [[DDLogFileFormatterDefault alloc] initWithDateFormatter:dateFormatter];
	fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
	fileLogger.logFileManager.maximumNumberOfLogFiles = 7;
	[DDLog addLogger:fileLogger];
    
    // Log system information
    NSString *version = [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleShortVersionString"];
    NSString *build = [NSBundle.mainBundle.infoDictionary objectForKey:(NSString*)kCFBundleVersionKey];
    DDLogInfo(@"\n---------------------------------\niSub %@ build %@ launched\n---------------------------------", version, build);
    
	// Setup network reachability notifications
	self.wifiReach = [EX2Reachability reachabilityForLocalWiFi];
	[self.wifiReach startNotifier];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(reachabilityChanged:) name:EX2ReachabilityNotification_ReachabilityChanged];
	[self.wifiReach currentReachabilityStatus];
	
	// Check battery state and register for notifications
	UIDevice.currentDevice.batteryMonitoringEnabled = YES;
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(batteryStateChanged:) name:@"UIDeviceBatteryStateDidChangeNotification" object:UIDevice.currentDevice];
	[self batteryStateChanged:nil];	
	
    // Request authorization to send background notifications
    [UNUserNotificationCenter.currentNotificationCenter requestAuthorizationWithOptions:UNAuthorizationOptionAlert|UNAuthorizationOptionSound completionHandler:^(BOOL granted, NSError * _Nullable error) {
        DDLogVerbose(@"Request for local notifications granted: %@", NSStringFromBOOL(granted));
    }];
    
	// Handle offline mode
    NSString *offlineModeAlertMessage = nil;
	if (settingsS.isForceOfflineMode) {
		settingsS.isOfflineMode = YES;
        offlineModeAlertMessage = @"Offline mode switch on, entering offline mode.";
	} else if (self.wifiReach.currentReachabilityStatus == NotReachable) {
		settingsS.isOfflineMode = YES;
        offlineModeAlertMessage = @"No network detected, entering offline mode.";
	} else if (self.wifiReach.currentReachabilityStatus == ReachableViaWWAN && settingsS.isDisableUsageOver3G) {
        settingsS.isOfflineMode = YES;
        offlineModeAlertMessage = @"You are not on Wifi, and have chosen to disable use over cellular. Entering offline mode.";
    } else {
		settingsS.isOfflineMode = NO;
	}
    
    // Optionally show offline mode alert
    if (offlineModeAlertMessage && settingsS.isPopupsEnabled) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Notice" message:offlineModeAlertMessage preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [EX2Dispatch runInMainThreadAfterDelay:1.1 block:^{
            [UIApplication.keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
        }];
    }
		
	self.showIntro = NO;
	if (settingsS.isTestServer) {
		if (settingsS.isOfflineMode) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Welcome!" message:@"Looks like this is your first time using iSub or you haven't set up your Subsonic account info yet.\n\nYou'll need an internet connection to get started." preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [EX2Dispatch runInMainThreadAfterDelay:1.0 block:^{
                [UIApplication.keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
            }];
		} else {
			self.showIntro = YES;
		}
	}
				
	[self loadFlurryAnalytics];
    
	// Create and display UI
	if (UIDevice.isIPad) {
		self.padRootViewController = [[PadRootViewController alloc] initWithNibName:nil bundle:nil];
		[self.window setBackgroundColor:[UIColor clearColor]];
        self.window.rootViewController = self.padRootViewController;
		[self.window makeKeyAndVisible];
        
		if (self.showIntro) {
            [self showSettings];
		}
	} else {
        [UITabBar.appearance setBarTintColor:UIColor.blackColor];
        self.mainTabBarController.tabBar.translucent = NO;
        self.offlineTabBarController.tabBar.translucent = NO;

		if (settingsS.isOfflineMode) {
			self.currentTabBarController = self.offlineTabBarController;
            self.window.rootViewController = self.offlineTabBarController;
		} else {
			// Recover the tab order and load the main tabBarController
			self.currentTabBarController = self.mainTabBarController;
            self.window.rootViewController = self.mainTabBarController;
		}
        
        [self.window makeKeyAndVisible];
		
		if (self.showIntro) {
            [self showSettings];
		}
	}
    
    self.window.backgroundColor = settingsS.isJukeboxEnabled ? viewObjectsS.jukeboxColor : viewObjectsS.windowColor;
		
	// Check the server status in the background
    if (!settingsS.isOfflineMode) {
		[viewObjectsS showAlbumLoadingScreen:self.window sender:self];
		[self checkServer];
	}
    
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(showPlayer) name:ISMSNotification_ShowPlayer];
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(playVideoNotification:) name:ISMSNotification_PlayVideo];
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(removeMoviePlayer) name:ISMSNotification_RemoveMoviePlayer];
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(jukeboxToggled) name:ISMSNotification_JukeboxDisabled];
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(jukeboxToggled) name:ISMSNotification_JukeboxEnabled];
    
    [self startHLSProxy];
    
	// Recover current state if player was interrupted
	[ISMSStreamManager sharedInstance];
	[musicS resumeSong];
}

- (void)jukeboxToggled {
    // Change the background color when jukebox is on
    self.window.backgroundColor = settingsS.isJukeboxEnabled ? viewObjectsS.jukeboxColor : viewObjectsS.windowColor;
}

- (void)oneTimeRun {
    if (settingsS.oneTimeRunIncrementor < 1) {
        settingsS.isPartialCacheNextSong = NO;
        settingsS.oneTimeRunIncrementor = 1;
    }
}

// TODO: Fix video playback
- (void)startHLSProxy {
//    self.hlsProxyServer = [[HTTPServer alloc] init];
//    self.hlsProxyServer.connectionClass = [HLSProxyConnection class];
//
//    NSError *error;
//	BOOL success = [self.hlsProxyServer start:&error];
//
//	if(!success)
//	{
//		DDLogError(@"Error starting HLS proxy server: %@", error);
//	}
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    // Handle being openned by a URL
    DDLogVerbose(@"url host: %@ path components: %@", url.host, url.pathComponents );
    
    if (url.host) {
        if ([[url.host lowercaseString] isEqualToString:@"play"]) {
            if (audioEngineS.player) {
                if (!audioEngineS.player.isPlaying) {
                    [audioEngineS.player playPause];
                }
            } else {
                [musicS playSongAtPosition:playlistS.currentIndex];
            }
        } else if ([[url.host lowercaseString] isEqualToString:@"pause"]) {
            if (audioEngineS.player.isPlaying) {
                [audioEngineS.player playPause];
            }
        } else if ([[url.host lowercaseString] isEqualToString:@"playpause"]) {
            if (audioEngineS.player) {
                [audioEngineS.player playPause];
            } else {
                [musicS playSongAtPosition:playlistS.currentIndex];
            }
        } else if ([[url.host lowercaseString] isEqualToString:@"next"]) {
            [musicS playSongAtPosition:playlistS.nextIndex];
        } else if ([[url.host lowercaseString] isEqualToString:@"prev"]) {
            [musicS playSongAtPosition:playlistS.prevIndex];
        }
    }
    
    NSDictionary *queryParameters = url.queryParameterDictionary;
    if ([queryParameters.allKeys containsObject:@"ref"]) {
        self.referringAppUrl = [NSURL URLWithString:[queryParameters objectForKey:@"ref"]];
        
        // On the iPad we need to reload the menu table to see the back button
        if (UIDevice.isIPad) {
            [self.padRootViewController.menuViewController loadCellContents];
        }
    }
    
    return YES;
}

- (void)backToReferringApp {
    if (self.referringAppUrl) {
        [UIApplication.sharedApplication openURL:self.referringAppUrl options:@{} completionHandler:nil];
    }
}

// Check server cancel load
- (void)cancelLoad {
	[self.statusLoader cancelLoad];
	[viewObjectsS hideLoadingScreen];
}

- (void)checkServer {
    // Check if the subsonic URL is valid by attempting to access the ping.view page, 
	// if it's not then display an alert and allow user to change settings if they want.
	// This is in case the user is, for instance, connected to a wifi network but does not 
	// have internet access or if the host url entered was wrong.
    if (!settingsS.isOfflineMode) {
        self.statusLoader = [[SUSStatusLoader alloc] initWithDelegate:self];
        self.statusLoader.urlString = settingsS.urlString;
        self.statusLoader.username = settingsS.username;
        self.statusLoader.password = settingsS.password;
        [self.statusLoader startLoad];
    }
	
	// Do a server check every half hour
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkServer) object:nil];
	NSTimeInterval delay = 30 * 60; // 30 minutes
	[self performSelector:@selector(checkServer) withObject:nil afterDelay:delay];
}

#pragma mark SUS Loader Delegate

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error {
    if (theLoader.type == SUSLoaderType_Status) {
        [viewObjectsS hideLoadingScreen];
        
        if (!settingsS.isOfflineMode) {
            DDLogVerbose(@"Loading failed for loading type %i, entering offline mode. Error: %@", theLoader.type, error);
            [self enterOfflineMode];
        }
        
        if ([theLoader isKindOfClass:SUSStatusLoader.class]) {
            settingsS.isNewSearchAPI = ((SUSStatusLoader *)theLoader).isNewSearchAPI;
            settingsS.isVideoSupported = ((SUSStatusLoader *)theLoader).isVideoSupported;
        }
        
        self.statusLoader = nil;
    }
}

- (void)loadingFinished:(SUSLoader *)theLoader {
    // This happens right on app launch
    if (theLoader.type == SUSLoaderType_Status) {
        if ([theLoader isKindOfClass:SUSStatusLoader.class]) {
            settingsS.isNewSearchAPI = ((SUSStatusLoader *)theLoader).isNewSearchAPI;
            settingsS.isVideoSupported = ((SUSStatusLoader *)theLoader).isVideoSupported;
        }
        
        self.statusLoader = nil;
        
        //DLog(@"server verification passed, hiding loading screen");
        [viewObjectsS hideLoadingScreen];
        
        // TODO: Find another way to detect crashes without using HockeyApp
        // Since the download queue has been a frequent source of crashes in the past, and we start this on launch automatically
        // potentially resulting in a crash loop, do NOT start the download queue automatically if the app crashed on last launch.
//        if (![BITHockeyManager sharedHockeyManager].crashManager.didCrashInLastSession)
        {
            // Start the queued downloads if Wifi is available
            [cacheQueueManagerS startDownloadQueue];
        }
    }
}

- (void)loadFlurryAnalytics {
	BOOL isSessionStarted = NO;
#if defined(RELEASE)
    [Flurry startSession:@"3KK4KKD2PSEU5APF7PNX"];
    isSessionStarted = YES;
#elif defined(BETA)
    [Flurry startSession:@"KNN9DUXQEENZUG4Q12UA"];
    isSessionStarted = YES;
#endif
	
	if (isSessionStarted) {
		// Send the firmware version
        [Flurry logEvent:@"DeviceInfo" withParameters:@{@"FirmwareVersion": UIDevice.currentDevice.completeVersionString, @"HardwareVersion": UIDevice.currentDevice.platform}];
	}
}

- (NSString *)latestLogFileName {
    NSString *logsFolder = [settingsS.cachesPath stringByAppendingPathComponent:@"Logs"];
	NSArray *logFiles = [NSFileManager.defaultManager contentsOfDirectoryAtPath:logsFolder error:nil];
	
	NSTimeInterval modifiedTime = 0.;
	NSString *fileNameToUse;
	for (NSString *file in logFiles) {
		NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:[logsFolder stringByAppendingPathComponent:file] error:nil];
		NSDate *modified = attributes.fileModificationDate;
		//DLog(@"Checking file %@ with modified time of %f", file, [modified timeIntervalSince1970]);
		if (modified && modified.timeIntervalSince1970 >= modifiedTime) {
			//DLog(@"Using this file, since it's modified time %f is higher than %f", [modified timeIntervalSince1970], modifiedTime);
			
			// This file is newer
			fileNameToUse = file;
			modifiedTime = [modified timeIntervalSince1970];
		}
	}
    
    return fileNameToUse;
}

- (NSString *)zipAllLogFiles {
    // Flush all logs to disk
    [DDLog flushLog];
    
    NSString *zipFileName = @"iSub Logs.zip";
    NSString *zipFilePath = [settingsS.cachesPath stringByAppendingPathComponent:zipFileName];
    NSString *logsFolder = [settingsS.cachesPath stringByAppendingPathComponent:@"Logs"];
    
    // Delete the old zip if exists
    [[NSFileManager defaultManager] removeItemAtPath:zipFilePath error:nil];
    
    // Zip the logs
    ZKFileArchive *archive = [ZKFileArchive archiveWithArchivePath:zipFilePath];
    NSInteger result = [archive deflateDirectory:logsFolder relativeToPath:settingsS.cachesPath usingResourceFork:NO];
    if (result == zkSucceeded) {
        return zipFilePath;
    }
    return nil;
}

- (void)batteryStateChanged:(NSNotification *)notification {
	if (UIDevice.currentDevice.batteryState == UIDeviceBatteryStateCharging || UIDevice.currentDevice.batteryState == UIDeviceBatteryStateFull) {
        UIApplication.sharedApplication.idleTimerDisabled = YES;
    } else if (settingsS.isScreenSleepEnabled) {
        UIApplication.sharedApplication.idleTimerDisabled = NO;
    }
}

- (void)applicationDidBecomeActive:(UIApplication*)application {
    [self checkServer];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
	[settingsS saveState];
	
	[NSUserDefaults.standardUserDefaults synchronize];
	
	if (cacheQueueManagerS.isQueueDownloading) {
		self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            // App is about to be put to sleep, stop the cache download queue
            if (cacheQueueManagerS.isQueueDownloading) {
                [cacheQueueManagerS stopDownloadQueue];
            }
            
            // Make sure to end the background so we don't get killed by the OS
            [self cancelBackgroundTask];
            
            // Cancel the next server check otherwise it will fire immediately on launch
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkServer) object:nil];
        }];
        
        self.isInBackground = YES;
		[self performSelector:@selector(checkRemainingBackgroundTime) withObject:nil afterDelay:1.0];
	}
}

- (void)checkRemainingBackgroundTime {
    NSLog(@"checking remaining background time: %f", UIApplication.sharedApplication.backgroundTimeRemaining);
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkRemainingBackgroundTime) object:nil];
    if (!self.isInBackground) {
        return;
    }
    
    UIApplication *application = [UIApplication sharedApplication];
    if (application.backgroundTimeRemaining < 30.0 && cacheQueueManagerS.isQueueDownloading) {
        // Warn at 2 minute mark if cache queue is downloading
        // TODO: Test this implementation
        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        content.body = @"Songs are still caching. Please return to iSub within 30 seconds, or it will be put to sleep and your song caching will be paused.";
        content.sound = UNNotificationSound.defaultSound;
        UNNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1 repeats:NO];
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:NSUUID.UUID.UUIDString content:content trigger:trigger];
        [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request withCompletionHandler:nil];
    } else if (!cacheQueueManagerS.isQueueDownloading) {
        // Cancel the next server check otherwise it will fire immediately on launch
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkServer) object:nil];
        [self cancelBackgroundTask];
    } else {
        [self performSelector:@selector(checkRemainingBackgroundTime) withObject:nil afterDelay:1.0];
    }
}

- (void)cancelBackgroundTask {
    if (self.backgroundTask != UIBackgroundTaskInvalid) {
        [UIApplication.sharedApplication endBackgroundTask:self.backgroundTask];
        self.backgroundTask = UIBackgroundTaskInvalid;
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
	
	if ([UIApplication.sharedApplication respondsToSelector:@selector(endBackgroundTask:)]) {
		self.isInBackground = NO;
        [self cancelBackgroundTask];
	}

	// Update the lock screen art in case were were using another app
	[musicS updateLockScreenInfo];
}

- (void)applicationWillTerminate:(UIApplication *)application {
	[UIApplication.sharedApplication endReceivingRemoteControlEvents];
	[settingsS saveState];
	[audioEngineS.player stop];
}

#pragma mark Helper Methods

- (void)enterOfflineMode {
	if (!self.isNoNetworkAlertShowing) {
		self.isNoNetworkAlertShowing = YES;
        if (settingsS.isPopupsEnabled) {
            NSString *message = @"Server unavailable, would you like to enter offline mode? Any currently playing music will stop.\n\nIf this is just temporary connection loss, select No.";
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Notice" message:message preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                [self enterOfflineModeForce];
            }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:nil]];
            [self.window.rootViewController presentViewController:alert animated:YES completion:^{
                self.isNoNetworkAlertShowing = NO;
            }];
        }
	}
}

- (void)enterOnlineMode {
	if (!self.isOnlineModeAlertShowing) {
        self.isOnlineModeAlertShowing = YES;
        if (settingsS.isPopupsEnabled) {
            NSString *message = @"Network detected, would you like to enter online mode? Any currently playing music will stop.";
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Notice" message:message preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                [self enterOnlineModeForce];
            }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:nil]];
            [self.window.rootViewController presentViewController:alert animated:YES completion:^{
                self.isOnlineModeAlertShowing = NO;
            }];
        }
	}
}

- (void)enterOfflineModeForce {
    if (settingsS.isOfflineMode) {
		return;
    }
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_EnteringOfflineMode];
	
    settingsS.isJukeboxEnabled = NO;
    self.window.backgroundColor = viewObjectsS.windowColor;
    [Flurry logEvent:@"JukeboxDisabled"];
    
	settingsS.isOfflineMode = YES;
    
	[audioEngineS.player stop];
	[streamManagerS cancelAllStreams];
	[cacheQueueManagerS stopDownloadQueue];

    if (UIDevice.isIPad) {
		[self.padRootViewController.menuViewController toggleOfflineMode];
    } else {
		[self.mainTabBarController.view removeFromSuperview];
    }
    
	[databaseS closeAllDatabases];
	[databaseS setupDatabases];
	
	if (UIDevice.isIPad) {
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowPlayer];
	} else {
		self.currentTabBarController = self.offlineTabBarController;
        self.window.rootViewController = self.offlineTabBarController;
	}
	
	[musicS updateLockScreenInfo];
}

- (void)enterOnlineModeForce {
	if ([self.wifiReach currentReachabilityStatus] == NotReachable) return;
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_EnteringOnlineMode];
    
	settingsS.isOfflineMode = NO;
	
	[audioEngineS.player stop];
	
    if (UIDevice.isIPad) {
		[self.padRootViewController.menuViewController toggleOfflineMode];
    } else {
		[self.offlineTabBarController.view removeFromSuperview];
    }
    
	[databaseS closeAllDatabases];
	[databaseS setupDatabases];
	[self checkServer];
	[cacheQueueManagerS startDownloadQueue];
	
	if (UIDevice.isIPad) {
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowPlayer];
	} else {
		[viewObjectsS orderMainTabBarController];
        self.window.rootViewController = self.mainTabBarController;
	}
	
	[musicS updateLockScreenInfo];
}

- (void)reachabilityChangedInternal {
    NetworkStatus currentReachabilityStatus = self.wifiReach.currentReachabilityStatus;
	if (currentReachabilityStatus == NotReachable) {
		// Change over to offline mode
		if (!settingsS.isOfflineMode) {
            DDLogVerbose(@"Reachability changed to NotReachable, prompting to go to offline mode");
			[self enterOfflineMode];
		}
	} else if (currentReachabilityStatus == ReachableViaWWAN && settingsS.isDisableUsageOver3G) {
        if (!settingsS.isOfflineMode) {
			[self enterOfflineModeForce];
            [[EX2SlidingNotification slidingNotificationOnMainWindowWithMessage:@"You have chosen to disable usage over cellular in settings and are no longer on Wifi. Entering offline mode." image:nil] showAndHideSlidingNotification];
		}
    } else {
		[self checkServer];
		
		if (settingsS.isOfflineMode) {
			[self enterOnlineMode];
		} else {
            if (currentReachabilityStatus == ReachableViaWiFi || settingsS.isManualCachingOnWWANEnabled) {
                if (!cacheQueueManagerS.isQueueDownloading) {
                    [cacheQueueManagerS startDownloadQueue];
                }
            } else {
                [cacheQueueManagerS stopDownloadQueue];
            }
		}
	}
}

- (void)reachabilityChanged:(NSNotification *)note {
    if (settingsS.isForceOfflineMode) return;
    
    [EX2Dispatch runInMainThreadAsync:^{
        // Cancel any previous requests
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reachabilityChangedInternal) object:nil];
        
        // Perform the actual check after a few seconds to make sure it's the last message received
        // this prevents a bug where the status changes from wifi to not reachable, but first it receives
        // some messages saying it's still on wifi, then gets the not reachable messages
        [self performSelector:@selector(reachabilityChangedInternal) withObject:nil afterDelay:6.0];
    }];
}

- (BOOL)isWifi {
    return self.wifiReach.currentReachabilityStatus == ReachableViaWiFi;
}

- (void)showSettings {
	if (UIDevice.isIPad) {
		[self.padRootViewController.menuViewController showSettings];
	} else {
		self.serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
		self.serverListViewController.hidesBottomBarWhenPushed = YES;
		
		if (self.currentTabBarController.selectedIndex >= 4) {
			[self.currentTabBarController.moreNavigationController pushViewController:self.serverListViewController animated:YES];
		} else if (self.currentTabBarController.selectedIndex == NSNotFound) {
			[self.currentTabBarController.moreNavigationController pushViewController:self.serverListViewController animated:YES];
		} else {
			[(UINavigationController*)self.currentTabBarController.selectedViewController pushViewController:self.serverListViewController animated:YES];
		}
	}
}

#pragma mark Movie Playing

- (void)removeMoviePlayer {
    if (self.videoPlayerController) {
        [self.videoPlayerController dismissViewControllerAnimated:YES completion:^{
            self.videoPlayerController = nil;
        }];
    }
}

- (void)playVideoNotification:(NSNotification *)notification {
    id aSong = notification.userInfo[@"song"];
    if (aSong && [aSong isKindOfClass:[ISMSSong class]]) {
        [self playVideo:aSong];
    }
}

- (void)playVideo:(ISMSSong *)aSong {
    if (!aSong.isVideo || !settingsS.isVideoSupported) {
        return;
    }
    
//    if (UIDevice.isIPad) {
//        // Turn off repeat one so user doesn't get stuck
//        if (playlistS.repeatMode == ISMSRepeatMode_RepeatOne) {
//            playlistS.repeatMode = ISMSRepeatMode_Normal;
//        }
//    }
    
    [self playSubsonicVideo:aSong bitrates:settingsS.currentVideoBitrates];
}

- (void)playSubsonicVideo:(ISMSSong *)aSong bitrates:(NSArray *)bitrates {
    [audioEngineS.player stop];
    
    if (!aSong.songId || !bitrates) {
        return;
    }

    // If we're on HTTPS, use our proxy to allow for playback from a self signed server
    // TODO: Right now we always use the proxy server as even if it's http, if the server has https enabled, it will forward requests there. In the future, it would be better to first test if it's possible to play without the proxy even with https (in case they are using a legit SSL cert) and then also enable picture in picture mode and airplay.
    self.hlsProxyServer = [[HLSReverseProxyServer alloc] init];
    [self.hlsProxyServer start];

    NSDictionary *parameters = @{ @"id" : aSong.songId, @"bitRate" : bitrates };
    NSURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"hls" parameters:parameters];
    NSString *urlString = [NSString stringWithFormat:@"http://localhost:%lu%@?%@", self.hlsProxyServer.port, request.URL.relativePath, request.URL.query];
    NSString *originUrlString = [NSString stringWithFormat:@"%@://%@:%@%@", request.URL.scheme, request.URL.host, request.URL.port, request.URL.path];
    urlString = [NSString stringWithFormat:@"%@&__hls_origin_url=%@", urlString, originUrlString];
    DDLogVerbose(@"TEST HLS urlString: %@", urlString);

    AVPlayer *player = [AVPlayer playerWithURL:[NSURL URLWithString:urlString]];
    player.allowsExternalPlayback = NO; // Disable AirPlay since it won't work with the proxy server
    self.videoPlayerController = [[AVPlayerViewController alloc] init];
    self.videoPlayerController.delegate = self;
    self.videoPlayerController.player = player;
    self.videoPlayerController.allowsPictureInPicturePlayback = NO;
    self.videoPlayerController.entersFullScreenWhenPlaybackBegins = YES;
    self.videoPlayerController.exitsFullScreenWhenPlaybackEnds = YES;
    [UIApplication.keyWindow.rootViewController presentViewController:self.videoPlayerController animated:YES completion:^{
        // Start audio session
        NSError *error = nil;
        [AVAudioSession.sharedInstance setActive:YES error:&error];
        if (error) {
            DDLogError(@"Failed to activate audio session for video playback: %@", error.localizedDescription);
        }
        
        // Allow audio playback when mute switch is on
        [AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeMoviePlayback options:0 error:&error];
        if (error) {
            DDLogError(@"Failed to set audio session category/mode for video playback: %@", error.localizedDescription);
        }
        
        // Auto-start playback
        [player play];
    }];
}

- (void)playerViewController:(AVPlayerViewController *)playerViewController willEndFullScreenPresentationWithAnimationCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        // Do nothing
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        // If the window has been dismissed (superview is nil), clean up the player controller
        if (!playerViewController.view.superview) {
            // Clean up the player controller
            DDLogVerbose(@"TEST player ended full screen presentation");
            [playerViewController.player pause];
            playerViewController.player.rate = 0.0;
            playerViewController.player = nil;
            self.videoPlayerController = nil;
            
            // Clean up proxy server
            [self.hlsProxyServer stop];
            self.hlsProxyServer = nil;
            
            // Clean up audio session
            // TODO: Figure out where to put this, currently it always prints this error: Deactivating an audio session that has running I/O. All I/O should be stopped or paused prior to deactivating the audio session.
//            NSError *error = nil;
//            [AVAudioSession.sharedInstance setActive:NO error:&error];
//            if (error) {
//                DDLogError(@"Failed to deactivate audio session for video playback: %@", error.localizedDescription);
//            }
        }
    }];
}

@end

