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
#include <netinet/in.h> 
#include <netdb.h>
#include <arpa/inet.h>
#import "IntroViewController.h"
#import "SFHFKeychainUtils.h"
#import "iPadRootViewController.h"
#import "MenuViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ISMSUpdateChecker.h"
#import "MKStoreManager.h"
#import <MediaPlayer/MediaPlayer.h>
#import "StoreViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "HTTPServer.h"
#import "HLSProxyConnection.h"

LOG_LEVEL_ISUB_DEFAULT

@implementation iSubAppDelegate

+ (iSubAppDelegate *)sharedInstance
{
	return (iSubAppDelegate*)[UIApplication sharedApplication].delegate;
}

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

#pragma mark -
#pragma mark Application lifecycle
#pragma mark -


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
    /*if (!IS_IPAD())
    {
        CGSize screenSize = [[UIScreen mainScreen] preferredMode].size;
        CGFloat screenScale = [UIScreen mainScreen].scale;
        screenScale = screenScale == 0. ? 1. : screenScale;
        self.window.size = CGSizeMake(screenSize.width / screenScale, screenSize.height / screenScale);
    }*/
	
#if !IS_ADHOC() && !IS_RELEASE()
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
	
	//DLog(@"md5: %@", [settings.urlString md5]);
	
	[self loadFlurryAnalytics];
	[self loadHockeyApp];
	//[self loadCrittercism];
		
	[self loadInAppPurchaseStore];
			
	// Create and display UI
	self.introController = nil;
	if (IS_IPAD())
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
        if (IS_IOS7())
        {
            [[UITabBar appearance] setBarTintColor:[UIColor blackColor]];
            self.mainTabBarController.tabBar.translucent = NO;
            self.offlineTabBarController.tabBar.translucent = NO;
        }
        
		// Setup the tabBarController
		self.mainTabBarController.moreNavigationController.navigationBar.barStyle = UIBarStyleBlack;
        self.mainTabBarController.moreNavigationController.navigationBar.translucent = NO;
		/*// Add the support tab
		[Crittercism showCrittercism:nil];
		UIViewController *vc = (UIViewController *)[Crittercism sharedInstance].crittercismViewController;
		self.supportNavigationController = [[UINavigationController alloc] initWithRootViewController:vc];
		supportNavigationController.tabBarItem.tag = 9;
		supportNavigationController.tabBarItem.image = [UIImage imageNamed:@"support-tabbaricon.png"];
		supportNavigationController.tabBarItem.title = @"Support";
		NSMutableArray *viewControllers = [NSMutableArray arrayWithArray:mainTabBarController.viewControllers];
		[viewControllers addObject:supportNavigationController];
		[mainTabBarController setViewControllers:viewControllers animated:NO];
		[vc logMethods];
         //DLog(@"toolbarItems: %@", [vc toolbarItems]);*/
		
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
        appDelegateS.window.backgroundColor = viewObjectsS.jukeboxColor;
    else
        appDelegateS.window.backgroundColor = viewObjectsS.windowColor;
}

- (void)oneTimeRun
{
    if (settingsS.oneTimeRunIncrementor < 1)
    {
        settingsS.isPartialCacheNextSong = NO;
        settingsS.oneTimeRunIncrementor = 1;
    }
}

- (void)startHLSProxy
{
    self.hlsProxyServer = [[HTTPServer alloc] init];
    self.hlsProxyServer.connectionClass = [HLSProxyConnection class];
    
    NSError *error;
	BOOL success = [self.hlsProxyServer start:&error];
	
	if(!success)
	{
		DDLogError(@"Error starting HLS proxy server: %@", error);
	}
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    // Handle being openned by a URL
    DLog(@"url host: %@ path components: %@", url.host, url.pathComponents );
    
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
        if (IS_IPAD())
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
        self.statusLoader = [ISMSStatusLoader loaderWithDelegate:self];
        if ([settingsS.serverType isEqualToString:SUBSONIC])
        {
            SUSStatusLoader *subsonicLoader = (SUSStatusLoader *)self.statusLoader;
            subsonicLoader.urlString = settingsS.urlString;
            subsonicLoader.username = settingsS.username;
            subsonicLoader.password = settingsS.password;
        }
        [self.statusLoader startLoad];
    }
	
	// Do a server check every half hour
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkServer) object:nil];
	NSTimeInterval delay = 30 * 60; // 30 minutes
	[self performSelector:@selector(checkServer) withObject:nil afterDelay:delay];
}

#pragma mark - ISMS Loader Delegate

- (void)loadingRedirected:(ISMSLoader *)theLoader redirectUrl:(NSURL *)url
{
    NSMutableString *redirectUrlString = [NSMutableString stringWithFormat:@"%@://%@", url.scheme, url.host];
	if (url.port)
		[redirectUrlString appendFormat:@":%@", url.port];
	
	if ([url.pathComponents count] > 3)
	{
		for (NSString *component in url.pathComponents)
		{
			if ([component isEqualToString:@"api"] || [component isEqualToString:@"rest"])
				break;
			
			if (![component isEqualToString:@"/"])
			{
				[redirectUrlString appendFormat:@"/%@", component];
			}
		}
	}
	
    DLog(@"redirectUrlString: %@", redirectUrlString);
	
	settingsS.redirectUrlString = [NSString stringWithString:redirectUrlString];
}

- (void)loadingFailed:(ISMSLoader *)theLoader withError:(NSError *)error
{
    if (theLoader.type == ISMSLoaderType_Status)
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
        
        self.statusLoader = nil;
        
        if ([theLoader isKindOfClass:[SUSStatusLoader class]])
        {
            settingsS.isNewSearchAPI = ((SUSStatusLoader *)theLoader).isNewSearchAPI;
            settingsS.isVideoSupported = ((SUSStatusLoader *)theLoader).isVideoSupported;
        }
        else if ([theLoader isKindOfClass:[PMSStatusLoader class]])
        {
            settingsS.isVideoSupported = YES;
        }
    }
}

- (void)loadingFinished:(ISMSLoader *)theLoader
{
    // This happens right on app launch
    if (theLoader.type == ISMSLoaderType_Status)
    {
        if ([theLoader isKindOfClass:[SUSStatusLoader class]])
        {
            settingsS.isNewSearchAPI = ((SUSStatusLoader *)theLoader).isNewSearchAPI;
            settingsS.isVideoSupported = ((SUSStatusLoader *)theLoader).isVideoSupported;
        }
        
        self.statusLoader = nil;
        
        //DLog(@"server verification passed, hiding loading screen");
        [viewObjectsS hideLoadingScreen];
        
        if (!IS_IPAD() && !settingsS.isOfflineMode)
            [viewObjectsS orderMainTabBarController];
        
        // Since the download queue has been a frequent source of crashes in the past, and we start this on launch automatically
        // potentially resulting in a crash loop, do NOT start the download queue automatically if the app crashed on last launch.
        if (![BITHockeyManager sharedHockeyManager].crashManager.didCrashInLastSession)
        {
            // Start the queued downloads if Wifi is available
            [cacheQueueManagerS startDownloadQueue];
        }
    }
}

#pragma mark -

- (void)loadFlurryAnalytics
{
	BOOL isSessionStarted = NO;
#if IS_RELEASE()
    #if IS_LITE()
        // Lite version key
        [Flurry startSession:@"MQV1D5WQYUTCDAD6PFLU"];
        isSessionStarted = YES;
    #else
        // Full version key
        [Flurry startSession:@"3KK4KKD2PSEU5APF7PNX"];
        isSessionStarted = YES;
    #endif
#elif IS_BETA()
    // Beta version key
    [Flurry startSession:@"KNN9DUXQEENZUG4Q12UA"];
    isSessionStarted = YES;
#endif
	
	if (isSessionStarted)
	{
		[Flurry setSecureTransportEnabled:YES];
		
		// These set to no as per Flurry support instructions to prevent crashes
		[Flurry setSessionReportsOnPauseEnabled:NO];
		[Flurry setSessionReportsOnCloseEnabled:NO];
		
		// Send the firmware version
		UIDevice *device = [UIDevice currentDevice];
		NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:[device completeVersionString], @"FirmwareVersion", 
																		  [device platform], @"HardwareVersion", nil];
		[Flurry logEvent:@"DeviceInfo" withParameters:params];
	}
}

- (void)loadHockeyApp
{
    BITHockeyManager *hockeyManager = [BITHockeyManager sharedHockeyManager];
    
	// HockyApp Kits
#if IS_BETA() && IS_ADHOC() && !IS_LITE()
    [hockeyManager configureWithBetaIdentifier:@"ada15ac4ffe3befbc66f0a00ef3d96af" liveIdentifier:@"ada15ac4ffe3befbc66f0a00ef3d96af" delegate:self];
    hockeyManager.updateManager.alwaysShowUpdateReminder = NO;
    [hockeyManager startManager];
#elif IS_RELEASE()
    #if IS_LITE()
        [hockeyManager configureWithBetaIdentifier:@"36cd77b2ee78707009f0a9eb9bbdbec7" liveIdentifier:@"36cd77b2ee78707009f0a9eb9bbdbec7" delegate:self];
    #else
        [hockeyManager configureWithBetaIdentifier:@"7c9cb46dad4165c9d3919390b651f6bb" liveIdentifier:@"7c9cb46dad4165c9d3919390b651f6bb" delegate:self];
    #endif
        [hockeyManager startManager];
#endif
    hockeyManager.crashManager.crashManagerStatus = BITCrashManagerStatusAutoSend;
	
    if (hockeyManager.crashManager.didCrashInLastSession)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Oh no! iSub crashed!" message:@"iSub support has received your anonymous crash logs and they will be investigated. \n\nWould you also like to send an email to support with more details?" delegate:self cancelButtonTitle:@"No Thanks" otherButtonTitles:@"Send Email", @"Visit iSub Forum", nil];
		alert.tag = 7;
		[alert performSelector:@selector(show) withObject:nil afterDelay:2.];
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

- (NSString *)applicationLogForCrashManager:(BITCrashManager *)crashManager
{
    NSString *logsFolder = [settingsS.cachesPath stringByAppendingPathComponent:@"Logs"];
	NSString *fileNameToUse = [self latestLogFileName];
	
	if (fileNameToUse)
	{
		NSString *logPath = [logsFolder stringByAppendingPathComponent:fileNameToUse];
		NSString *contents = [[NSString alloc] initWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil];
		//DLog(@"Sending contents with length %u from path %@", contents.length, logPath);
		return contents;
	}
	
	return nil;
}

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

/*- (void)loadCrittercism
{
	//if (IS_BETA() && IS_ADHOC() && !IS_LITE())
	if (1)
	{
		[Crittercism initWithAppID:@"4f504545b093157173000017" 
							andKey:@"4f504545b093157173000017lh4java7"
						 andSecret:@"trzmcvolbfqgnphhisc8jdvunqy2es5b" 
			 andMainViewController:nil];
	}
	else if (IS_RELEASE())
	{
		[Crittercism initWithAppID:@"4f1f9785b093150d5500008c" 
							andKey:@"4f1f9785b093150d5500008cpu3zoqbu" 
						 andSecret:@"2ayz0tlckhhu4jjsb8dzxuqmfnexcqkn"
			 andMainViewController:nil];
	}
	[Crittercism sharedInstance].delegate = (id<CrittercismDelegate>)self;
}

- (void)crittercismDidCrashOnLastLoad
{
//DLog(@"App crashed on last load. Do something here.");
	
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Oh no! :(" message:@"It looks like iSub crashed recently!\n\nWell never fear, iSub support is happy to help. \n\nWould you like to send an email to support?" delegate:self cancelButtonTitle:@"No Thanks" otherButtonTitles:@"Yes Please", nil];
	alert.tag = 7;
	[alert show];
	[alert release];
}*/

- (void)loadInAppPurchaseStore
{
#if IS_LITE()
    [MKStoreManager sharedManager];
    [MKStoreManager setDelegate:self];
    
    if (IS_DEBUG())
    {
        // Reset features
        [SFHFKeychainUtils storeUsername:kFeaturePlaylistsId andPassword:@"NO" forServiceName:kServiceName updateExisting:YES error:nil];
        [SFHFKeychainUtils storeUsername:kFeatureCacheId andPassword:@"NO" forServiceName:kServiceName updateExisting:YES error:nil];
        [SFHFKeychainUtils storeUsername:kFeatureVideoId andPassword:@"NO" forServiceName:kServiceName updateExisting:YES error:nil];
        [SFHFKeychainUtils storeUsername:kFeatureAllId andPassword:@"NO" forServiceName:kServiceName updateExisting:YES error:nil];
        
        //DLog(@"is kFeaturePlaylistsId enabled: %i", [MKStoreManager isFeaturePurchased:kFeaturePlaylistsId]);
        //DLog(@"is kFeatureJukeboxId enabled: %i", [MKStoreManager isFeaturePurchased:kFeatureJukeboxId]);
        //DLog(@"is kFeatureCacheId enabled: %i", [MKStoreManager isFeaturePurchased:kFeatureCacheId]);
        //DLog(@"is kFeatureAllId enabled: %i", [MKStoreManager isFeaturePurchased:kFeatureAllId]);
    }
#endif
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
    
    [self checkWaveBoxRelease];
}


- (void)applicationDidEnterBackground:(UIApplication *)application
{
	//DLog(@"applicationDidEnterBackground called");
	
	[settingsS saveState];
	
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	if ([[UIApplication sharedApplication] respondsToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)])
    {
		self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:
						  ^{
							  // App is about to be put to sleep, stop the cache download queue
							  if (cacheQueueManagerS.isQueueDownloading)
								  [cacheQueueManagerS stopDownloadQueue];
							  
							  // Make sure to end the background so we don't get killed by the OS
							  [application endBackgroundTask:self.backgroundTask];
							  self.backgroundTask = UIBackgroundTaskInvalid;
                              
                              // Cancel the next server check otherwise it will fire immediately on launch
                              [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkServer) object:nil];
						  }];
		
		// Check the remaining background time and alert the user if necessary
		dispatch_queue_t queue = dispatch_queue_create("isub.backgroundqueue", 0);
		dispatch_async(queue, 
		^{
			self.isInBackground = YES;
			UIApplication *application = [UIApplication sharedApplication];
			while ([application backgroundTimeRemaining] > 1.0 && self.isInBackground) 
			{
				@autoreleasepool 
				{
					//DLog(@"backgroundTimeRemaining: %f", [application backgroundTimeRemaining]);
					
					// Sleep early is nothing is happening after 500 seconds
					if ([application backgroundTimeRemaining] < 200.0 && !cacheQueueManagerS.isQueueDownloading)
					{
                        //DLog("Sleeping early, isQueueListDownloading: %i", cacheQueueManagerS.isQueueDownloading);
						[application endBackgroundTask:self.backgroundTask];
						self.backgroundTask = UIBackgroundTaskInvalid;
                        
                        // Cancel the next server check otherwise it will fire immediately on launch
                        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkServer) object:nil];
						break;
					}
					
					// Warn at 2 minute mark if cache queue is downloading
					if ([application backgroundTimeRemaining] < 120.0 && cacheQueueManagerS.isQueueDownloading)
					{
						UILocalNotification *localNotif = [[UILocalNotification alloc] init];
						if (localNotif) 
						{
							localNotif.alertBody = NSLocalizedString(@"Songs are still caching. Please return to iSub within 2 minutes, or it will be put to sleep and your song caching will be paused.", nil);
							localNotif.alertAction = NSLocalizedString(@"Open iSub", nil);
							[application presentLocalNotificationNow:localNotif];
							break;
						}
					}
					
					// Sleep for a second to avoid a fast loop eating all cpu cycles
					sleep(1);
				}
			}
		});
	}
}


- (void)applicationWillEnterForeground:(UIApplication *)application
{
	//DLog(@"applicationWillEnterForeground called");
	
	if ([[UIApplication sharedApplication] respondsToSelector:@selector(endBackgroundTask:)])
    {
		self.isInBackground = NO;
		if (self.backgroundTask != UIBackgroundTaskInvalid)
		{
			[[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
			self.backgroundTask = UIBackgroundTaskInvalid;
		}
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
    appDelegateS.window.backgroundColor = viewObjectsS.windowColor;
    [Flurry logEvent:@"JukeboxDisabled"];
    
	settingsS.isOfflineMode = YES;
		
	[audioEngineS.player stop];
	
	[streamManagerS cancelAllStreams];
	
	[cacheQueueManagerS stopDownloadQueue];

	if (IS_IPAD())
		[self.ipadRootViewController.menuViewController toggleOfflineMode];
	else
		[self.mainTabBarController.view removeFromSuperview];
	
	[databaseS closeAllDatabases];
	[databaseS setupDatabases];
	
	if (IS_IPAD())
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
	
	if (IS_IPAD())
		[self.ipadRootViewController.menuViewController toggleOfflineMode];
	else
		[self.offlineTabBarController.view removeFromSuperview];
	
	[databaseS closeAllDatabases];
	[databaseS setupDatabases];
	[self checkServer];
	[cacheQueueManagerS startDownloadQueue];
	
	if (IS_IPAD())
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

- (void)reachabilityChangedInternal:(EX2Reachability *)curReach
{	
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


- (void)reachabilityChanged: (NSNotification *)note
{
	if (settingsS.isForceOfflineMode)
		return;
	
	if ([note.object isKindOfClass:[EX2Reachability class]])
	{
		// Cancel any previous requests
		[EX2Dispatch cancelTimerBlockWithName:@"Reachability Changed"];
		
		// Perform the actual check in two seconds to make sure it's the last message received
		// this prevents a bug where the status changes from wifi to not reachable, but first it receives
		// some messages saying it's still on wifi, then gets the not reachable messages
		[EX2Dispatch timerInMainQueueAfterDelay:6.0 withName:@"Reachability Changed" repeats:NO performBlock:
		 ^{
			 [self reachabilityChangedInternal:note.object];
		 }];
	}
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
	if (IS_IPAD())
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
				
				/*if (IS_IPAD())
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
				if (IS_IPAD())
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
		case 7:
		{
			// Title: Oh no! :(
			if (buttonIndex == 1)
			{
				if ([MFMailComposeViewController canSendMail])
				{
					MFMailComposeViewController *mailer = [[MFMailComposeViewController alloc] init];
					[mailer setMailComposeDelegate:self];
					[mailer setToRecipients:@[@"support@isubapp.com"]];
					
					if ([[[BITHockeyManager sharedHockeyManager] crashManager] didCrashInLastSession])
					{
						// Set version label
						NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
						NSString *formattedVersion = nil;
                        #if IS_RELEASE()
                            formattedVersion = version;
                        #else
							NSString *build = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
							formattedVersion = [NSString stringWithFormat:@"%@ build %@", build, version];
                        #endif
						
						NSString *subject = [NSString stringWithFormat:@"I had a crash in iSub %@ :(", formattedVersion];
						[mailer setSubject:subject];
						
						[mailer setMessageBody:@"Here's what I was doing when iSub crashed..." isHTML:NO];
					}
					else 
					{
						[mailer setSubject:@"I need some help with iSub :)"];
					}
                    
                    NSString *zippedLogs = [self zipAllLogFiles];
                    if (zippedLogs)
                    {
                        NSError *fileError;
                        NSData *zipData = [NSData dataWithContentsOfFile:zippedLogs options:NSDataReadingMappedIfSafe error:&fileError];
                        if (!fileError)
                        {
                            [mailer addAttachmentData:zipData mimeType:@"application/x-zip-compressed" fileName:[zippedLogs lastPathComponent]];
                        }
                    }
					
					if (IS_IPAD())
						[self.ipadRootViewController presentViewController:mailer animated:YES completion:nil];
					else
						[self.currentTabBarController presentViewController:mailer animated:YES completion:nil];
					
				}
				else
				{
					UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Uh Oh!" message:@"It looks like you don't have an email account set up, but you can reach support from your computer by emailing support@isubapp.com" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
					[alert show];
				}
			}
			else if (buttonIndex == 2)
			{
				NSString *urlString = IS_IPAD() ? @"http://isubapp.com/forum" : @"http://isubapp.com/vanilla";
				NSURL *url = [NSURL URLWithString:urlString];
				[[UIApplication sharedApplication] openURL:url];
			}
		}
        case 10:
        {            
            // WaveBox Release message
            settingsS.isStopCheckingWaveboxRelease = YES;
            if (buttonIndex == 1)
            {
                // More Info
                NSString *moreInfoUrl = [alertView ex2CustomObjectForKey:@"moreInfoUrl"];
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:moreInfoUrl]];
            }
            else if (buttonIndex == 2)
            {
                // App Store
                NSString *appStoreUrl = [alertView ex2CustomObjectForKey:@"appStoreUrl"];
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:appStoreUrl]];
            }
        }
	}
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error 
{   
	if (IS_IPAD())
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

- (void)checkWaveBoxRelease
{
    if (!settingsS.isStopCheckingWaveboxRelease && !settingsS.isWaveBoxAlertShowing)
    {
        [EX2Dispatch runInBackgroundAsync:^
         {
             NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"http://isubapp.com/wavebox.json"]];
             if (data.length > 0)
             {
                 NSDictionary *dict = [[[SBJsonParser alloc] init] objectWithData:data];
                 NSString *title = dict[@"title"];
                 NSString *message = dict[@"message"];
                 NSString *moreInfoUrl = dict[@"moreInfoUrl"];
                 NSString *appStoreUrl = dict[@"appStoreUrl"];
                 if (title && message && moreInfoUrl && appStoreUrl)
                 {
                     if (!settingsS.isWaveBoxAlertShowing)
                     {
                         settingsS.isWaveBoxAlertShowing = YES;
                         [EX2Dispatch runInMainThreadAsync:^
                          {
                              UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:@"Not Now" otherButtonTitles:@"More Info", @"Install Now", nil];
                              alert.tag = 10;
                              [alert ex2SetCustomObject:moreInfoUrl forKey:@"moreInfoUrl"];
                              [alert ex2SetCustomObject:appStoreUrl forKey:@"appStoreUrl"];
                              [alert show];
                          }];
                     }
                 }
             }
         }];
    }
}

#pragma mark -
#pragma mark Music Streamer
#pragma mark -

/*- (NSString *)getStreamURLStringForSongId:(NSString *)songId
{	    
    NSString *encodedUserName = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)settings.username, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
	NSString *encodedPassword = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)settings.password, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
    
	if ([musicS maxBitrateSetting] != 0)
	{
		return [NSString stringWithFormat:@"%@/rest/stream.view?maxBitRate=%i&u=%@&p=%@&v=1.2.0&c=iSub&id=", settingsS.urlString, [musicS maxBitrateSetting], [encodedUserName autorelease], [encodedPassword autorelease]];
	}
    else
	{
		return [NSString stringWithFormat:@"%@/rest/stream.view?u=%@&p=%@&v=1.1.0&c=iSub&id=", settingsS.urlString, [encodedUserName autorelease], [encodedPassword autorelease]];
	}
}*/

/*- (NSString *)getBaseUrl:(NSString *)action
{	
	NSString *urlString = [[[NSString alloc] init] autorelease];

	urlString = defaultUrl;
	
	NSString *encodedUserName = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)defaultUserName, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
	NSString *encodedPassword = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)defaultPassword, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
    
	//DLog(@"username: %@    password: %@", encodedUserName, encodedPassword);
	
	// Return the base URL
	if ([action isEqualToString:@"getIndexes.view"] || [action isEqualToString:@"search.view"] || [action isEqualToString:@"search2.view"] || [action isEqualToString:@"getNowPlaying.view"] || [action isEqualToString:@"getPlaylists.view"] || [action isEqualToString:@"getMusicFolders.view"] || [action isEqualToString:@"createPlaylist.view"])
	{
		return [NSString stringWithFormat:@"%@/rest/%@?u=%@&p=%@&v=1.1.0&c=iSub", urlString, action, [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else if ([action isEqualToString:@"stream.view"] && [[settingsDictionary objectForKey:@"maxBitrateSetting"] intValue] != 7)
	{
		return [NSString stringWithFormat:@"%@/rest/stream.view?maxBitRate=%i&u=%@&p=%@&v=1.2.0&c=iSub&id=", urlString, [musicS maxBitrateSetting], [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else if ([action isEqualToString:@"addChatMessage.view"])
	{
		return [NSString stringWithFormat:@"%@/rest/addChatMessage.view?&u=%@&p=%@&v=1.2.0&c=iSub&message=", urlString, [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else if ([action isEqualToString:@"getLyrics.view"])
	{
		NSString *encodedArtist = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)musicS.currentSongObject.artist, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
		NSString *encodedTitle = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)musicS.currentSongObject.title, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
		
		return [NSString stringWithFormat:@"%@/rest/getLyrics.view?artist=%@&title=%@&u=%@&p=%@&v=1.2.0&c=iSub", urlString, [encodedArtist autorelease], [encodedTitle autorelease], [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else if ([action isEqualToString:@"getRandomSongs.view"] || [action isEqualToString:@"getAlbumList.view"] || [action isEqualToString:@"jukeboxControl.view"])
	{
		return [NSString stringWithFormat:@"%@/rest/%@?u=%@&p=%@&v=1.2.0&c=iSub", urlString, action, [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else
	{
		return [NSString stringWithFormat:@"%@/rest/%@?u=%@&p=%@&v=1.1.0&c=iSub&id=", urlString, action, [encodedUserName autorelease], [encodedPassword autorelease]];
	}
}*/


#pragma mark -
#pragma mark Store Manager delegate
#pragma mark -

/*- (void)productFetchComplete
 {
 CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Store" message:@"Product fetch complete" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
 [alert show];
 [alert release];
 }*/

- (void)productPurchased:(NSString *)productId
{
	NSString *message = nil;
	if ([productId isEqualToString:kFeatureAllId])
		message = @"You may now use all of the iSub features.";
	else if ([productId isEqualToString:kFeaturePlaylistsId])
		message = @"You may now use the playlist feature.";
	else if ([productId isEqualToString:kFeatureCacheId])
		message = @"You may now use the song caching feature.";
	else if ([productId isEqualToString:kFeatureVideoId])
		message = @"You may now stream videos.";
	else
		message = @"";
	
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Purchase Successful!" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
	[alert show];
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_StorePurchaseComplete];
}

- (void)transactionCanceled
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Store" message:@"Transaction canceled. Try again." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
	[alert show];
}

#pragma mark - Movie Playing

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
        
        if (IS_IPAD())
        {
            [appDelegateS.ipadRootViewController.menuViewController.playerHolder addSubview:self.moviePlayer.view];
            self.moviePlayer.view.frame = self.moviePlayer.view.superview.bounds;
        }
        else
        {
            [appDelegateS.mainTabBarController.view addSubview:self.moviePlayer.view];
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
    if (settingsS.isVideoUnlocked)
    {
        NSString *serverType = settingsS.serverType;
        if (!aSong.isVideo || (([serverType isEqualToString:SUBSONIC] || [serverType isEqualToString:UBUNTU_ONE]) && !settingsS.isVideoSupported))
            return;
        
        if (IS_IPAD())
        {
            // Turn off repeat one so user doesn't get stuck
            if (playlistS.repeatMode == ISMSRepeatMode_RepeatOne)
                playlistS.repeatMode = ISMSRepeatMode_Normal;
        }
        
        if ([serverType isEqualToString:SUBSONIC] || [serverType isEqualToString:UBUNTU_ONE])
        {
            [self playSubsonicVideo:aSong bitrates:settingsS.currentVideoBitrates];
        }
    }
    else
	{
		StoreViewController *store = [[StoreViewController alloc] init];
        if (IS_IPAD())
        {
            [store pushViewControllerCustom:store];
        }
        else
        {
            [self.currentTabBarController.selectedViewController pushViewControllerCustom:store];
        }
	}
}

- (void)playSubsonicVideo:(ISMSSong *)aSong bitrates:(NSArray *)bitrates
{
    [audioEngineS.player stop];
    
    if (!aSong.itemId || !bitrates)
        return;
    
    NSDictionary *parameters = @{ @"id" : aSong.itemId, @"bitRate" : bitrates };
    NSURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"hls" parameters:parameters];
    
    // If we're on HTTPS, use our proxy to allow for playback from a self signed server
    NSString *host = request.URL.absoluteString;
    host = [host.lowercaseString hasPrefix:@"https"] ? [NSString stringWithFormat:@"http://localhost:%u%@", self.hlsProxyServer.listeningPort, request.URL.relativePath] : host;
    NSString *urlString = [NSString stringWithFormat:@"%@?%@", host, [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]];
    DLog(@"HLS urlString: %@", urlString);
    
    [self createMoviePlayer];
    
    [self.moviePlayer stop]; // Doing this to prevent potential crash
    self.moviePlayer.contentURL = [NSURL URLWithString:urlString];
    //[moviePlayer prepareToPlay];
    [self.moviePlayer play];
}

- (void)moviePlayerExitedFullscreen:(NSNotification *)notification
{
    // Hack to fix broken navigation bar positioning
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    UIView *view = [window.subviews lastObject];
    if (view)
    {
        [view removeFromSuperview];
        [window addSubview:view];
    }
    
    if (!IS_IPAD())
    {
        [self removeMoviePlayer];
    }
}

- (void)moviePlayBackDidFinish:(NSNotification *)notification
{
    DLog(@"userInfo: %@", notification.userInfo);
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

