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
#import <CoreFoundation/CoreFoundation.h>
#import <SystemConfiguration/SCNetworkReachability.h>
#import <netinet/in.h>
#import <netdb.h>
#import <arpa/inet.h>
#import "IntroViewController.h"
#import "iPadRootViewController.h"
#import "MenuViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ISMSUpdateChecker.h"
#import <MediaPlayer/MediaPlayer.h>
#import "UIViewController+PushViewControllerCustom.h"
//#import "HTTPServer.h"
//#import "HLSProxyConnection.h"
//#import "DDFileLogger.h"
//#import "DDTTYLogger.h"
#import "SUSStatusLoader.h"
#import "CustomUIAlertView.h"
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

LOG_LEVEL_ISUB_DEFAULT

@implementation iSubAppDelegate

+ (iSubAppDelegate *)sharedInstance
{
	return (iSubAppDelegate*)[UIApplication sharedApplication].delegate;
}

- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    return UIInterfaceOrientationMaskAll;
}

#pragma mark Application lifecycle

/*void onUncaughtException(NSException* exception)
{
    NSLog(@"uncaught exception: %@", exception.description);
}*/

- (void)showPlayer
{
    iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
    streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
    [(UINavigationController*)self.currentTabBarController.selectedViewController pushViewController:streamingPlayerViewController animated:YES];
}

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    // Set up the window
    //self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // Make sure audio engine and cache singletons get loaded
	[AudioEngine sharedInstance];
	[CacheSingleton sharedInstance];
    
    // Start the save defaults timer and mem cache initial defaults
	[settingsS setupSaveState];
    
    // Run the one time actions
    [self oneTimeRun];
    
    //NSSetUncaughtExceptionHandler(&onUncaughtException);

    // Adjust the window to the correct size before anything else loads to prevent
    // various sizing/positioning issues
    if (!UIDevice.isIPad)
    {
        CGSize screenSize = [[UIScreen mainScreen] preferredMode].size;
        CGFloat screenScale = [UIScreen mainScreen].scale;
        screenScale = screenScale == 0. ? 1. : screenScale;
        self.window.size = CGSizeMake(screenSize.width / screenScale, screenSize.height / screenScale);
    }
	
#if !defined(ADHOC) && !defined(RELEASE)
    // Don't turn on console logging for adhoc or release builds
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [[DDTTYLogger sharedInstance] setColorsEnabled:YES];
#endif
	DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
	fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
	fileLogger.logFileManager.maximumNumberOfLogFiles = 7;
	[DDLog addLogger:fileLogger];
    
    
	
	// Setup network reachability notifications
	self.wifiReach = [EX2Reachability reachabilityForLocalWiFi];
	[self.wifiReach startNotifier];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(reachabilityChanged:) name: EX2ReachabilityNotification_ReachabilityChanged object:nil];
	[self.wifiReach currentReachabilityStatus];
	
	// Check battery state and register for notifications
	[UIDevice currentDevice].batteryMonitoringEnabled = YES;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryStateChanged:) name:@"UIDeviceBatteryStateDidChangeNotification" object:[UIDevice currentDevice]];
	[self batteryStateChanged:nil];	
	
	// Handle offline mode
	if (settingsS.isForceOfflineMode)
	{
		settingsS.isOfflineMode = YES;
		
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"Offline mode switch on, entering offline mode." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		alert.tag = 4;
		[alert performSelector:@selector(show) withObject:nil afterDelay:1.1];
	}
	else if ([self.wifiReach currentReachabilityStatus] == NotReachable)
	{
		settingsS.isOfflineMode = YES;
		
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"No network detected, entering offline mode." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		alert.tag = 4;
		[alert performSelector:@selector(show) withObject:nil afterDelay:1.1];
	}
    else if ([self.wifiReach currentReachabilityStatus] == ReachableViaWWAN && settingsS.isDisableUsageOver3G)
    {
        settingsS.isOfflineMode = YES;
		
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"You are not on Wifi, and have chosen to disable use over cellular. Entering offline mode." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		alert.tag = 4;
		[alert performSelector:@selector(show) withObject:nil afterDelay:1.1];
    }
	else
	{
		settingsS.isOfflineMode = NO;
	}
		
	self.showIntro = NO;
	if (settingsS.isTestServer)
	{
		if (settingsS.isOfflineMode)
		{
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Welcome!" message:@"Looks like this is your first time using iSub or you haven't set up your Subsonic account info yet.\n\nYou'll need an internet connection to watch the intro video and use the included demo account." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
			[alert performSelector:@selector(show) withObject:nil afterDelay:1.0];
		}
		else
		{
			self.showIntro = YES;
		}
	}
		
    self.introController = nil;
		
	[self loadFlurryAnalytics];
    
	// Create and display UI
	self.introController = nil;
	if (UIDevice.isIPad)
	{
		self.ipadRootViewController = [[iPadRootViewController alloc] initWithNibName:nil bundle:nil];
		[self.window setBackgroundColor:[UIColor clearColor]];
        self.window.rootViewController = self.ipadRootViewController;
		[self.window makeKeyAndVisible];
        
		if (self.showIntro)
		{
			self.introController = [[IntroViewController alloc] init];
			self.introController.modalPresentationStyle = UIModalPresentationFormSheet;
			[self.ipadRootViewController presentViewController:self.introController animated:NO completion:nil];
		}
	}
	else
	{
        [[UITabBar appearance] setBarTintColor:[UIColor blackColor]];
        self.mainTabBarController.tabBar.translucent = NO;
        self.offlineTabBarController.tabBar.translucent = NO;
        
		// Setup the tabBarController
		self.mainTabBarController.moreNavigationController.navigationBar.barStyle = UIBarStyleBlack;
        self.mainTabBarController.moreNavigationController.navigationBar.translucent = NO;
		
		//DLog(@"isOfflineMode: %i", settingsS.isOfflineMode);
		if (settingsS.isOfflineMode)
		{
			//DLog(@"--------------- isOfflineMode");
			self.currentTabBarController = self.offlineTabBarController;
			//[self.window addSubview:self.offlineTabBarController.view];
            self.window.rootViewController = self.offlineTabBarController;
		}
		else 
		{
			// Recover the tab order and load the main tabBarController
			self.currentTabBarController = self.mainTabBarController;
			
			//[viewObjectsS orderMainTabBarController]; // Do this after server check
			//[self.window addSubview:self.mainTabBarController.view];
            self.window.rootViewController = self.mainTabBarController;
		}
        
        [self.window makeKeyAndVisible];
		
		if (self.showIntro)
		{
			self.introController = [[IntroViewController alloc] init];
			[self.currentTabBarController presentViewController:self.introController animated:NO completion:nil];
		}
	}
    
	if (settingsS.isJukeboxEnabled)
		self.window.backgroundColor = viewObjectsS.jukeboxColor;
	else 
		self.window.backgroundColor = viewObjectsS.windowColor;
		
	// Check the server status in the background
    if (!settingsS.isOfflineMode)
	{
		//DLog(@"adding loading screen");
		[viewObjectsS showAlbumLoadingScreen:self.window sender:self];
		
		[self checkServer];
	}
    
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(showPlayer) name:ISMSNotification_ShowPlayer object:nil];
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(playVideoNotification:) name:ISMSNotification_PlayVideo object:nil];
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(removeMoviePlayer) name:ISMSNotification_RemoveMoviePlayer object:nil];
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(jukeboxToggled) name:ISMSNotification_JukeboxDisabled object:nil];
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(jukeboxToggled) name:ISMSNotification_JukeboxEnabled object:nil];
    
    [self startHLSProxy];
    
	// Recover current state if player was interrupted
	[ISMSStreamManager sharedInstance];
	[musicS resumeSong];
}

- (void)jukeboxToggled
{
    // Change the background color when jukebox is on
    if (settingsS.isJukeboxEnabled)
        self.window.backgroundColor = viewObjectsS.jukeboxColor;
    else
        self.window.backgroundColor = viewObjectsS.windowColor;
}

- (void)oneTimeRun
{
    if (settingsS.oneTimeRunIncrementor < 1)
    {
        settingsS.isPartialCacheNextSong = NO;
        settingsS.oneTimeRunIncrementor = 1;
    }
}

// TODO: Fix video playback
- (void)startHLSProxy
{
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

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    // Handle being openned by a URL
    DDLogVerbose(@"url host: %@ path components: %@", url.host, url.pathComponents );
    
    if (url.host)
    {
        if ([[url.host lowercaseString] isEqualToString:@"play"])
        {
            if (audioEngineS.player)
            {
                if (!audioEngineS.player.isPlaying)
                {
                    [audioEngineS.player playPause];
                }
            }
            else
            {
                [musicS playSongAtPosition:playlistS.currentIndex];
            }
        }
        else if ([[url.host lowercaseString] isEqualToString:@"pause"])
        {
            if (audioEngineS.player.isPlaying)
            {
                [audioEngineS.player playPause];
            }
        }
        else if ([[url.host lowercaseString] isEqualToString:@"playpause"])
        {
            if (audioEngineS.player)
            {
                [audioEngineS.player playPause];
            }
            else
            {
                [musicS playSongAtPosition:playlistS.currentIndex];
            }
        }
        else if ([[url.host lowercaseString] isEqualToString:@"next"])
        {
            [musicS playSongAtPosition:playlistS.nextIndex];
        }
        else if ([[url.host lowercaseString] isEqualToString:@"prev"])
        {
            [musicS playSongAtPosition:playlistS.prevIndex];
        }
    }
    
    NSDictionary *queryParameters = url.queryParameterDictionary;
    if ([queryParameters.allKeys containsObject:@"ref"])
    {
        self.referringAppUrl = [NSURL URLWithString:[queryParameters objectForKey:@"ref"]];
        
        // On the iPad we need to reload the menu table to see the back button
        if (UIDevice.isIPad)
        {
            [self.ipadRootViewController.menuViewController loadCellContents];
        }
    }
    
    return YES;
}

- (void)backToReferringApp
{
    if (self.referringAppUrl)
    {
        [[UIApplication sharedApplication] openURL:self.referringAppUrl];
    }
}

// Check server cancel load
- (void)cancelLoad
{
	[self.statusLoader cancelLoad];
	[viewObjectsS hideLoadingScreen];
}

- (void)checkServer
{
    //DLog(@"urlString: %@", settingsS.urlString);
	ISMSUpdateChecker *updateChecker = [[ISMSUpdateChecker alloc] init];
	[updateChecker checkForUpdate];

    // Check if the subsonic URL is valid by attempting to access the ping.view page, 
	// if it's not then display an alert and allow user to change settings if they want.
	// This is in case the user is, for instance, connected to a wifi network but does not 
	// have internet access or if the host url entered was wrong.
    if (!settingsS.isOfflineMode) 
	{
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

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error
{
    if (theLoader.type == SUSLoaderType_Status)
    {
        [viewObjectsS hideLoadingScreen];
        
        if(!settingsS.isOfflineMode)
        {
            /*UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Server Unavailable" message:[NSString stringWithFormat:@"Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\n☆☆ Tap the gear in the top left and choose a server to return to online mode. ☆☆\n\nError code %i:\n%@", [error code], [error localizedDescription]] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:@"Settings", nil];
             alert.tag = 3;
             [alert show];
             [alert release];
             
             [self enterOfflineModeForce];*/
            
            DDLogVerbose(@"Loading failed for loading type %i, entering offline mode. Error: %@", theLoader.type, error);
            
            [self enterOfflineMode];
        }
        
        if ([theLoader isKindOfClass:[SUSStatusLoader class]])
        {
            settingsS.isNewSearchAPI = ((SUSStatusLoader *)theLoader).isNewSearchAPI;
            settingsS.isVideoSupported = ((SUSStatusLoader *)theLoader).isVideoSupported;
        }
        
        self.statusLoader = nil;
    }
}

- (void)loadingFinished:(SUSLoader *)theLoader
{
    // This happens right on app launch
    if (theLoader.type == SUSLoaderType_Status)
    {
        if ([theLoader isKindOfClass:[SUSStatusLoader class]])
        {
            settingsS.isNewSearchAPI = ((SUSStatusLoader *)theLoader).isNewSearchAPI;
            settingsS.isVideoSupported = ((SUSStatusLoader *)theLoader).isVideoSupported;
        }
        
        self.statusLoader = nil;
        
        //DLog(@"server verification passed, hiding loading screen");
        [viewObjectsS hideLoadingScreen];
        
        if (!UIDevice.isIPad && !settingsS.isOfflineMode)
            [viewObjectsS orderMainTabBarController];
        
        // TODO: Find another way to detect crashes without using HockeyApp
//        // Since the download queue has been a frequent source of crashes in the past, and we start this on launch automatically
//        // potentially resulting in a crash loop, do NOT start the download queue automatically if the app crashed on last launch.
//        if (![BITHockeyManager sharedHockeyManager].crashManager.didCrashInLastSession)
//        {
//            // Start the queued downloads if Wifi is available
//            [cacheQueueManagerS startDownloadQueue];
//        }
    }
}

- (void)loadFlurryAnalytics
{
	BOOL isSessionStarted = NO;
#if defined(RELEASE)
    [Flurry startSession:@"3KK4KKD2PSEU5APF7PNX"];
    isSessionStarted = YES;
#elif defined(BETA)
    [Flurry startSession:@"KNN9DUXQEENZUG4Q12UA"];
    isSessionStarted = YES;
#endif
	
	if (isSessionStarted)
	{		
		// Send the firmware version
		UIDevice *device = [UIDevice currentDevice];
		NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:[device completeVersionString], @"FirmwareVersion", 
																		  [device platform], @"HardwareVersion", nil];
		[Flurry logEvent:@"DeviceInfo" withParameters:params];
	}
}

/*
#ifdef ADHOC
- (NSString *)userNameForCrashManager:(BITCrashManager *)crashManager
{
    if ([[UIDevice currentDevice] respondsToSelector:@selector(uniqueIdentifier)])
        return [[UIDevice currentDevice] performSelector:@selector(uniqueIdentifier)];
    return nil;
}
#endif

- (NSString *)customDeviceIdentifierForUpdateManager
{
#ifdef ADHOC
    if ([[UIDevice currentDevice] respondsToSelector:@selector(uniqueIdentifier)])
		return [[UIDevice currentDevice] performSelector:@selector(uniqueIdentifier)];
#endif
	
	return nil;
}
*/

- (NSString *)latestLogFileName
{
    NSString *logsFolder = [settingsS.cachesPath stringByAppendingPathComponent:@"Logs"];
	NSArray *logFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:logsFolder error:nil];
	
	NSTimeInterval modifiedTime = 0.;
	NSString *fileNameToUse;
	for (NSString *file in logFiles)
	{
		NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[logsFolder stringByAppendingPathComponent:file] error:nil];
		NSDate *modified = [attributes fileModificationDate];
		//DLog(@"Checking file %@ with modified time of %f", file, [modified timeIntervalSince1970]);
		if (modified && [modified timeIntervalSince1970] >= modifiedTime)
		{
			//DLog(@"Using this file, since it's modified time %f is higher than %f", [modified timeIntervalSince1970], modifiedTime);
			
			// This file is newer
			fileNameToUse = file;
			modifiedTime = [modified timeIntervalSince1970];
		}
	}
    
    return fileNameToUse;
}

//- (NSString *)applicationLogForCrashManager:(BITCrashManager *)crashManager
//{
//    NSString *logsFolder = [settingsS.cachesPath stringByAppendingPathComponent:@"Logs"];
//	NSString *fileNameToUse = [self latestLogFileName];
//	
//	if (fileNameToUse)
//	{
//		NSString *logPath = [logsFolder stringByAppendingPathComponent:fileNameToUse];
//		NSString *contents = [[NSString alloc] initWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil];
//		//DLog(@"Sending contents with length %u from path %@", contents.length, logPath);
//		return contents;
//	}
//	
//	return nil;
//}

- (NSString *)zipAllLogFiles
{    
    NSString *zipFileName = @"iSub Logs.zip";
    NSString *zipFilePath = [settingsS.cachesPath stringByAppendingPathComponent:zipFileName];
    NSString *logsFolder = [settingsS.cachesPath stringByAppendingPathComponent:@"Logs"];
    
    // Delete the old zip if exists
    [[NSFileManager defaultManager] removeItemAtPath:zipFilePath error:nil];
    
    // Zip the logs
    ZKFileArchive *archive = [ZKFileArchive archiveWithArchivePath:zipFilePath];
    NSInteger result = [archive deflateDirectory:logsFolder relativeToPath:settingsS.cachesPath usingResourceFork:NO];
    if (result == zkSucceeded)
    {
        return zipFilePath;
    }
    return nil;
}

- (void)startRedirectingLogToFile
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndexSafe:0];
	NSString *logPath = [documentsDirectory stringByAppendingPathComponent:@"console.log"];
	freopen([logPath cStringUsingEncoding:NSASCIIStringEncoding],"a+",stderr);
}

- (void)stopRedirectingLogToFile
{
	freopen("/dev/tty","w",stderr);
}

- (void)batteryStateChanged:(NSNotification *)notification
{
	UIDevice *device = [UIDevice currentDevice];
	if (device.batteryState == UIDeviceBatteryStateCharging || device.batteryState == UIDeviceBatteryStateFull) 
	{
			[UIApplication sharedApplication].idleTimerDisabled = YES;
    }
	else
	{
		if (settingsS.isScreenSleepEnabled)
			[UIApplication sharedApplication].idleTimerDisabled = NO;
	}
}

- (void)applicationWillResignActive:(UIApplication*)application
{
	//DLog(@"applicationWillResignActive called");
	
	//DLog(@"applicationWillResignActive finished");
}


- (void)applicationDidBecomeActive:(UIApplication*)application
{
	//DLog(@"isWifi: %i", [self isWifi]);
	//DLog(@"applicationDidBecomeActive called");
	
	//DLog(@"applicationDidBecomeActive finished");
    
    [self checkServer];
}


- (void)applicationDidEnterBackground:(UIApplication *)application
{
	//DLog(@"applicationDidEnterBackground called");
	
	[settingsS saveState];
	
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	if (cacheQueueManagerS.isQueueDownloading)
    {
		self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:
						  ^{
							  // App is about to be put to sleep, stop the cache download queue
							  if (cacheQueueManagerS.isQueueDownloading)
								  [cacheQueueManagerS stopDownloadQueue];
							  
							  // Make sure to end the background so we don't get killed by the OS
                              [self cancelBackgroundTask];
                              
                              // Cancel the next server check otherwise it will fire immediately on launch
                              [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkServer) object:nil];
						  }];
        
        self.isInBackground = YES;
		[self performSelector:@selector(checkRemainingBackgroundTime) withObject:nil afterDelay:1.0];
	}
}

- (void)checkRemainingBackgroundTime
{
    NSLog(@"checking remaining background time: %f", [[UIApplication sharedApplication] backgroundTimeRemaining]);
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkRemainingBackgroundTime) object:nil];
    if (!self.isInBackground)
    {
        return;
    }
    
    UIApplication *application = [UIApplication sharedApplication];
    if ([application backgroundTimeRemaining] < 30.0 && cacheQueueManagerS.isQueueDownloading)
    {
        // Warn at 2 minute mark if cache queue is downloading
        UILocalNotification *localNotif = [[UILocalNotification alloc] init];
        if (localNotif)
        {
            localNotif.alertBody = NSLocalizedString(@"Songs are still caching. Please return to iSub within 30 seconds, or it will be put to sleep and your song caching will be paused.", nil);
            localNotif.alertAction = NSLocalizedString(@"Open iSub", nil);
            [application presentLocalNotificationNow:localNotif];
        }
    }
    else if (!cacheQueueManagerS.isQueueDownloading)
    {
        // Cancel the next server check otherwise it will fire immediately on launch
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkServer) object:nil];
        [self cancelBackgroundTask];
    }
    else
    {
        [self performSelector:@selector(checkRemainingBackgroundTime) withObject:nil afterDelay:1.0];
    }
}

- (void)cancelBackgroundTask
{
    if (self.backgroundTask != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
        self.backgroundTask = UIBackgroundTaskInvalid;
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	//DLog(@"applicationWillEnterForeground called");
	
	if ([[UIApplication sharedApplication] respondsToSelector:@selector(endBackgroundTask:)])
    {
		self.isInBackground = NO;
        [self cancelBackgroundTask];
	}

	// Update the lock screen art in case were were using another app
	[musicS updateLockScreenInfo];
}


- (void)applicationWillTerminate:(UIApplication *)application
{
	//DLog(@"applicationWillTerminate called");
	
	[[UIApplication sharedApplication] endReceivingRemoteControlEvents];
	
	[settingsS saveState];
	
	[audioEngineS.player stop];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
	
}


#pragma mark Helper Methods

- (void)enterOfflineMode
{
	if (viewObjectsS.isNoNetworkAlertShowing == NO)
	{
		viewObjectsS.isNoNetworkAlertShowing = YES;
		
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"Server unavailable, would you like to enter offline mode? Any currently playing music will stop.\n\nIf this is just temporary connection loss, select No." delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
		alert.tag = 4;
		[alert show];
	}
}


- (void)enterOnlineMode
{
	if (!viewObjectsS.isOnlineModeAlertShowing)
	{
		viewObjectsS.isOnlineModeAlertShowing = YES;
		
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"Network detected, would you like to enter online mode? Any currently playing music will stop." delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
		alert.tag = 4;
		[alert show];
	}
}


- (void)enterOfflineModeForce
{
	if (settingsS.isOfflineMode)
		return;
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_EnteringOfflineMode];
	
    settingsS.isJukeboxEnabled = NO;
    self.window.backgroundColor = viewObjectsS.windowColor;
    [Flurry logEvent:@"JukeboxDisabled"];
    
	settingsS.isOfflineMode = YES;
		
	[audioEngineS.player stop];
	
	[streamManagerS cancelAllStreams];
	
	[cacheQueueManagerS stopDownloadQueue];

	if (UIDevice.isIPad)
		[self.ipadRootViewController.menuViewController toggleOfflineMode];
	else
		[self.mainTabBarController.view removeFromSuperview];
	
	[databaseS closeAllDatabases];
	[databaseS setupDatabases];
	
	if (UIDevice.isIPad)
	{
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowPlayer];
	}
	else
	{
		self.currentTabBarController = self.offlineTabBarController;
		//[self.window addSubview:self.offlineTabBarController.view];
        self.window.rootViewController = self.offlineTabBarController;
	}
	
	[musicS updateLockScreenInfo];
}

- (void)enterOnlineModeForce
{
	if ([self.wifiReach currentReachabilityStatus] == NotReachable)
		return;
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_EnteringOnlineMode];
		
	settingsS.isOfflineMode = NO;
	
	[audioEngineS.player stop];
	
	if (UIDevice.isIPad)
		[self.ipadRootViewController.menuViewController toggleOfflineMode];
	else
		[self.offlineTabBarController.view removeFromSuperview];
	
	[databaseS closeAllDatabases];
	[databaseS setupDatabases];
	[self checkServer];
	[cacheQueueManagerS startDownloadQueue];
	
	if (UIDevice.isIPad)
	{
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowPlayer];
	}
	else
	{
		[viewObjectsS orderMainTabBarController];
		//[self.window addSubview:self.mainTabBarController.view];
        self.window.rootViewController = self.mainTabBarController;
	}
	
	[musicS updateLockScreenInfo];
}

- (void)reachabilityChangedInternal
{
    EX2Reachability *curReach = self.wifiReach;
    
	if ([curReach currentReachabilityStatus] == NotReachable)
	{
		//Change over to offline mode
		if (!settingsS.isOfflineMode)
		{
            DDLogVerbose(@"Reachability changed to NotReachable, prompting to go to offline mode");
			[self enterOfflineMode];
		}
	}
    else if ([curReach currentReachabilityStatus] == ReachableViaWWAN && settingsS.isDisableUsageOver3G)
    {
        if (!settingsS.isOfflineMode)
		{            
			[self enterOfflineModeForce];
            
            [[EX2SlidingNotification slidingNotificationOnMainWindowWithMessage:@"You have chosen to disable usage over cellular in settings and are no longer on Wifi. Entering offline mode." image:nil] showAndHideSlidingNotification];
		}
    }
	else
	{
		[self checkServer];
		
		if (settingsS.isOfflineMode)
		{
			[self enterOnlineMode];
		}
		else
		{
            if ([curReach currentReachabilityStatus] == ReachableViaWiFi || settingsS.isManualCachingOnWWANEnabled)
            {
                if (!cacheQueueManagerS.isQueueDownloading)
                {
                    [cacheQueueManagerS startDownloadQueue];
                }
            }
			else
            {
                [cacheQueueManagerS stopDownloadQueue];
            }
		}
	}
}

- (void)reachabilityChanged:(NSNotification *)note
{
	if (settingsS.isForceOfflineMode)
		return;
    
    [EX2Dispatch runInMainThreadAsync:^{
        // Cancel any previous requests
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reachabilityChangedInternal) object:nil];
        
        // Perform the actual check after a few seconds to make sure it's the last message received
        // this prevents a bug where the status changes from wifi to not reachable, but first it receives
        // some messages saying it's still on wifi, then gets the not reachable messages
        [self performSelector:@selector(reachabilityChangedInternal) withObject:nil afterDelay:6.0];
    }];
}

- (BOOL)isWifi
{
	if ([self.wifiReach currentReachabilityStatus] == ReachableViaWiFi)
		return YES;
	else
		return NO;
}

- (void)showSettings
{
	if (UIDevice.isIPad)
	{
		[self.ipadRootViewController.menuViewController showSettings];
	}
	else
	{
		self.serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
		self.serverListViewController.hidesBottomBarWhenPushed = YES;
		
		if (self.currentTabBarController.selectedIndex >= 4)
		{
			//[self.currentTabBarController.moreNavigationController popToViewController:[currentTabBarController.moreNavigationController.viewControllers objectAtIndexSafe:1] animated:YES];
			[self.currentTabBarController.moreNavigationController pushViewController:self.serverListViewController animated:YES];
		}
		else if (self.currentTabBarController.selectedIndex == NSNotFound)
		{
			//[self.currentTabBarController.moreNavigationController popToRootViewControllerAnimated:YES];
			[self.currentTabBarController.moreNavigationController pushViewController:self.serverListViewController animated:YES];
		}
		else
		{
			//[(UINavigationController*)self.currentTabBarController.selectedViewController popToRootViewControllerAnimated:YES];
			[(UINavigationController*)self.currentTabBarController.selectedViewController pushViewController:self.serverListViewController animated:YES];
		}
	}
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	switch (alertView.tag)
	{
		case 1:
		{
			// Title: @"Subsonic Error"
			if(buttonIndex == 1)
			{
				[self showSettings];
				
				/*if (UIDevice.isIPad)
				{
					[mainMenu showSettings];
				}
				else
				{
					ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
					
					if (currentTabBarController.selectedIndex == 4)
					{
						[currentTabBarController.moreNavigationController pushViewController:serverListViewController animated:YES];
					}
					else
					{
						[(UINavigationController*)currentTabBarController.selectedViewController pushViewController:serverListViewController animated:YES];
					}
					
					[serverListViewController release];
				}*/
			}
			
			break;
		}
		/*case 2: // Isn't used
		{
			// Title: @"Error"
			[introController dismissModalViewControllerAnimated:NO];
			
			if (buttonIndex == 0)
			{
				[self appInit2];
			}
			else if (buttonIndex == 1)
			{
				if (UIDevice.isIPad)
				{
					[mainMenu showSettings];
				}
				else
				{
					[self showSettings];
				}
			}
			
			break;
		}*/
		case 3:
		{
			// Title: @"Server Unavailable"
			if (buttonIndex == 1)
			{
				[self showSettings];
			}
			
			break;
		}
		case 4:
		{
			// Title: @"Notice"
			
			// Offline mode handling
			
			viewObjectsS.isOnlineModeAlertShowing = NO;
			viewObjectsS.isNoNetworkAlertShowing = NO;
			
			if (buttonIndex == 1)
			{
				if (settingsS.isOfflineMode)
				{
					[self enterOnlineModeForce];
				}
				else
				{
					[self enterOfflineModeForce];
				}
			}
			
			break;
		}
		case 6:
		{
			// Title: @"Update Alerts"
			if (buttonIndex == 0)
			{
				settingsS.isUpdateCheckEnabled = NO;
			}
			else if (buttonIndex == 1)
			{
				settingsS.isUpdateCheckEnabled = YES;
			}
			
			settingsS.isUpdateCheckQuestionAsked = YES;
			
			break;
		}
	}
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error 
{   
	if (UIDevice.isIPad)
		[self.ipadRootViewController dismissViewControllerAnimated:YES completion:nil];
	else
		[self.currentTabBarController dismissViewControllerAnimated:YES completion:nil];
}


/*- (BOOL)wifiReachability
{
	switch ([wifiReach currentReachabilityStatus])
	{
		case NotReachable:
		{
			return NO;
		}
		case ReachableViaWWAN:
		{
			return NO;
		}
		case ReachableViaWiFi:
		{
			return YES;
		}
	}
	
	return NO;
}*/


/*- (BOOL) connectedToNetwork
{
	// Create zero addy
	struct sockaddr_in zeroAddress;
	bzero(&zeroAddress, sizeof(zeroAddress));
	zeroAddress.sin_len = sizeof(zeroAddress);
	zeroAddress.sin_family = AF_INET;
	
	// Recover reachability flags
	SCNetworkReachabilityRef defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&zeroAddress);
	SCNetworkReachabilityFlags flags;
	
	BOOL didRetrieveFlags = SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags);
	CFRelease(defaultRouteReachability);
	
	if (!didRetrieveFlags) {
		printf("Error. Could not recover network reachability flags\n"); return 0;
	}
	
	BOOL isReachable = flags & kSCNetworkFlagsReachable;
	BOOL needsConnection = flags & kSCNetworkFlagsConnectionRequired;
	return (isReachable && !needsConnection) ? YES : NO;
}*/

- (NSInteger) getHour
{
	// Get the time
	NSCalendar *calendar= [[NSCalendar alloc] initWithCalendarIdentifier: NSCalendarIdentifierGregorian];
	NSCalendarUnit unitFlags = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
	NSDate *date = [NSDate date];
	NSDateComponents *dateComponents = [calendar components:unitFlags fromDate:date];

	// Turn the date into Integers
	//NSInteger year = [dateComponents year];
	//NSInteger month = [dateComponents month];
	//NSInteger day = [dateComponents day];
	//NSInteger hour = [dateComponents hour];
	//NSInteger min = [dateComponents minute];
	//NSInteger sec = [dateComponents second];
	
	return [dateComponents hour];
}

#pragma mark Movie Playing

- (void)createMoviePlayer
{
    if (!self.moviePlayer)
    {
        self.moviePlayer = [[MPMoviePlayerController alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayerExitedFullscreen:) name:MPMoviePlayerDidExitFullscreenNotification object:self.moviePlayer];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayBackDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:self.moviePlayer];
        
        self.moviePlayer.controlStyle = MPMovieControlStyleDefault;
        self.moviePlayer.shouldAutoplay = YES;
        self.moviePlayer.movieSourceType = MPMovieSourceTypeStreaming;
        self.moviePlayer.allowsAirPlay = YES;
        
        if (UIDevice.isIPad)
        {
            [self.ipadRootViewController.menuViewController.playerHolder addSubview:self.moviePlayer.view];
            self.moviePlayer.view.frame = self.moviePlayer.view.superview.bounds;
        }
        else
        {
            [self.mainTabBarController.view addSubview:self.moviePlayer.view];
            self.moviePlayer.view.frame = CGRectZero;
        }
        
        [self.moviePlayer setFullscreen:YES animated:YES];
    }
}

- (void)removeMoviePlayer
{
    if (self.moviePlayer)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerDidExitFullscreenNotification object:self.moviePlayer];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:self.moviePlayer];
        
        // Dispose of any existing movie player
        [self.moviePlayer stop];
        [self.moviePlayer.view removeFromSuperview];
        self.moviePlayer = nil;
    }
}

- (void)playVideoNotification:(NSNotification *)notification
{
    id aSong = notification.userInfo[@"song"];
    if (aSong && [aSong isKindOfClass:[ISMSSong class]])
    {
        [self playVideo:aSong];
    }
}

- (void)playVideo:(ISMSSong *)aSong
{
    if (!aSong.isVideo || !settingsS.isVideoSupported)
        return;
    
    if (UIDevice.isIPad)
    {
        // Turn off repeat one so user doesn't get stuck
        if (playlistS.repeatMode == ISMSRepeatMode_RepeatOne)
            playlistS.repeatMode = ISMSRepeatMode_Normal;
    }
    
    [self playSubsonicVideo:aSong bitrates:settingsS.currentVideoBitrates];
}

// TODO: Fix video playback
- (void)playSubsonicVideo:(ISMSSong *)aSong bitrates:(NSArray *)bitrates
{
    [audioEngineS.player stop];
    
//    if (!aSong.songId || !bitrates)
//        return;
//
//    NSDictionary *parameters = @{ @"id" : aSong.songId, @"bitRate" : bitrates };
//    NSURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"hls" parameters:parameters];
//
//    // If we're on HTTPS, use our proxy to allow for playback from a self signed server
//    NSString *host = request.URL.absoluteString;
//    host = [host.lowercaseString hasPrefix:@"https"] ? [NSString stringWithFormat:@"http://localhost:%u%@", self.hlsProxyServer.listeningPort, request.URL.relativePath] : host;
//    NSString *urlString = [NSString stringWithFormat:@"%@?%@", host, [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]];
//    DDLogVerbose(@"HLS urlString: %@", urlString);
//
//    [self createMoviePlayer];
//
//    [self.moviePlayer stop]; // Doing this to prevent potential crash
//    self.moviePlayer.contentURL = [NSURL URLWithString:urlString];
//    //[moviePlayer prepareToPlay];
//    [self.moviePlayer play];
}

- (void)moviePlayerExitedFullscreen:(NSNotification *)notification
{
    // Hack to fix broken navigation bar positioning
    UIWindow *window = [UIApplication keyWindow];
    UIView *view = [window.subviews lastObject];
    if (view)
    {
        [view removeFromSuperview];
        [window addSubview:view];
    }
    
    if (!UIDevice.isIPad)
    {
        [self removeMoviePlayer];
    }
}

- (void)moviePlayBackDidFinish:(NSNotification *)notification
{
    DDLogVerbose(@"userInfo: %@", notification.userInfo);
    if (notification.userInfo)
    {
        NSNumber *reason = [notification.userInfo objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
        if (reason && reason.integerValue == MPMovieFinishReasonPlaybackEnded)
        {
            // Playback ended normally, so start the next item
            [playlistS incrementIndex];
            [musicS playSongAtPosition:playlistS.currentIndex];
        }
    }
    else
    {
        //[self removeMoviePlayer];
    }
}


@end

