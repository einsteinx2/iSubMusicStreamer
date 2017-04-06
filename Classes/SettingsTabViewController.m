//
//  SettingsTabViewController.m
//  iSub
//
//  Created by Ben Baron on 6/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SettingsTabViewController.h"
#import "FoldersViewController.h"
#import "iPadRootViewController.h"
#import "MenuViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "iPadRootViewController.h"
#import "StackScrollViewController.h"
#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import "IDTwitterAccountChooserViewController.h"

@implementation SettingsTabViewController

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	// Fix for UISwitch/UISegment bug in iOS 4.3 beta 1 and 2
	//
	self.loadedTime = [NSDate date];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTwitterUIElements) name:@"twitterAuthenticated" object:nil];
	
	// Set version label
	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
#if DEBUG
	NSString *build = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
	self.versionLabel.text = [NSString stringWithFormat:@"iSub version %@ build %@", build, version];
#else
	self.versionLabel.text = [NSString stringWithFormat:@"iSub version %@", version];
#endif
	
	// Hide elements
	if (IS_IPAD())
	{
		self.swipeCellsLabel.hidden = self.tapHoldCellsLabel.hidden = YES;
		self.enableSwipeSwitch.hidden = self.enableTapAndHoldSwitch.hidden = YES;
		self.enableSwipeSwitch.enabled = self.enableTapAndHoldSwitch.enabled = NO;
		
		CGFloat y = self.autoReloadArtistSwitch.y;
		for (UIView *view in self.view.subviews)
		{
			if (view.y > y+10.) view.y -= 70.;
		}
	}
	if (![NSClassFromString(@"MPNowPlayingInfoCenter") class])
	{
		self.enableLockArtLabel.hidden = self.enableLockScreenArt.hidden = YES;
		self.enableLockScreenArt.enabled = NO;
		
		CGFloat y = self.enableCacheStatusSwitch.y;
		for (UIView *view in self.view.subviews)
		{
			if (view.y > y+10.) view.y -= 35.;
		}
	}
	
	// Main Settings
	self.enableScrobblingSwitch.on = settingsS.isScrobbleEnabled;
	
	//scrobblePercentSlider.value = [[appDelegateS.settingsDictionary objectForKey:@"scrobblePercentSetting"] floatValue];
	self.scrobblePercentSlider.value = settingsS.scrobblePercent;
	[self updateScrobblePercentLabel];
	
	self.manualOfflineModeSwitch.on = settingsS.isForceOfflineMode;
	
	self.checkUpdatesSwitch.on = settingsS.isUpdateCheckEnabled;
	
	self.autoReloadArtistSwitch.on = settingsS.isAutoReloadArtistsEnabled;

	self.disablePopupsSwitch.on = !settingsS.isPopupsEnabled;
	
	self.disableRotationSwitch.on = settingsS.isRotationLockEnabled;
	
	self.disableScreenSleepSwitch.on = !settingsS.isScreenSleepEnabled;
	
	self.enableBasicAuthSwitch.on = settingsS.isBasicAuthEnabled;
    
    self.disableCellUsageSwitch.on = settingsS.isDisableUsageOver3G;
	
	self.enableSongsTabSwitch.on = settingsS.isSongsTabEnabled;
//DLog(@"isSongsTabEnabled: %i", settingsS.isSongsTabEnabled);
	
	self.recoverSegmentedControl.selectedSegmentIndex = settingsS.recoverSetting;
	
	self.maxBitrateWifiSegmentedControl.selectedSegmentIndex = settingsS.maxBitrateWifi;
	self.maxBitrate3GSegmentedControl.selectedSegmentIndex = settingsS.maxBitrate3G;
		
	self.enableSwipeSwitch.on = settingsS.isSwipeEnabled;
	self.enableTapAndHoldSwitch.on = settingsS.isTapAndHoldEnabled;
	
	self.showLargeSongInfoSwitch.on = settingsS.isShowLargeSongInfoInPlayer;
	self.enableLyricsSwitch.on = settingsS.isLyricsEnabled;
	self.enableCacheStatusSwitch.on = settingsS.isCacheStatusEnabled;
	self.enableLockScreenArt.on = settingsS.isLockScreenArtEnabled;
	
	// Cache Settings
    self.enableManualCachingOnWWANSwitch.on = settingsS.isManualCachingOnWWANEnabled;
	self.enableSongCachingSwitch.on = settingsS.isSongCachingEnabled;
	self.enableNextSongCacheSwitch.on = settingsS.isNextSongCacheEnabled;
	self.enableNextSongPartialCacheSwitch.on = settingsS.isPartialCacheNextSong;
    self.enableBackupCacheSwitch.on = settingsS.isBackupCacheEnabled;
    
    if (SYSTEM_VERSION_LESS_THAN(@"5.0.1"))
    {
        self.enableBackupCacheSwitch.enabled = NO;
    }
		
	self.totalSpace = cacheS.totalSpace;
	self.freeSpace = cacheS.freeSpace;
	self.freeSpaceLabel.text = [NSString stringWithFormat:@"Free space: %@", [NSString formatFileSize:self.freeSpace]];
	self.totalSpaceLabel.text = [NSString stringWithFormat:@"Total space: %@", [NSString formatFileSize:self.totalSpace]];
	float percentFree = (float) self.freeSpace / (float) self.totalSpace;
	CGRect frame = self.freeSpaceBackground.frame;
	frame.size.width = frame.size.width * percentFree;
	self.freeSpaceBackground.frame = frame;
	self.cachingTypeSegmentedControl.selectedSegmentIndex = settingsS.cachingType;
	[self toggleCacheControlsVisibility];
	[self cachingTypeToggle];
	
	self.autoDeleteCacheSwitch.on = settingsS.isAutoDeleteCacheEnabled;
	
	self.autoDeleteCacheTypeSegmentedControl.selectedSegmentIndex = settingsS.autoDeleteCacheType;
	
	self.cacheSongCellColorSegmentedControl.selectedSegmentIndex = settingsS.cachedSongCellColorType;
	
	switch (settingsS.quickSkipNumberOfSeconds) 
	{
		case 5: self.quickSkipSegmentControl.selectedSegmentIndex = 0; break;
		case 15: self.quickSkipSegmentControl.selectedSegmentIndex = 1; break;
		case 30: self.quickSkipSegmentControl.selectedSegmentIndex = 2; break;
		case 45: self.quickSkipSegmentControl.selectedSegmentIndex = 3; break;
		case 60: self.quickSkipSegmentControl.selectedSegmentIndex = 4; break;
		case 120: self.quickSkipSegmentControl.selectedSegmentIndex = 5; break;
		case 300: self.quickSkipSegmentControl.selectedSegmentIndex = 6; break;
		case 600: self.quickSkipSegmentControl.selectedSegmentIndex = 7; break;
		case 1200: self.quickSkipSegmentControl.selectedSegmentIndex = 8; break;
		default: break;
	}
	
	// Twitter settings
	if (settingsS.currentTwitterAccount)
	{
        ACAccountStore *store = [[ACAccountStore alloc] init];
        ACAccount *account = [store accountWithIdentifier:settingsS.currentTwitterAccount];
		self.twitterEnabledSwitch.enabled = YES;
		if (settingsS.isTwitterEnabled)
			self.twitterEnabledSwitch.on = YES;
		else
			self.twitterEnabledSwitch.on = NO;
		
		self.twitterSigninButton.imageView.image = [UIImage imageNamed:@"twitter-signout.png"];
		
		self.twitterStatusLabel.text = [NSString stringWithFormat:@"%@ signed in", [account username]];
	}
	else
	{
		self.twitterEnabledSwitch.on = NO;
		self.twitterEnabledSwitch.enabled = NO;
		
		self.twitterSigninButton.imageView.image = [UIImage imageNamed:@"twitter-signin.png"];
		
		self.twitterStatusLabel.text = @"Signed out";
	}
	
	// Handle In App Purchase settings
	if (settingsS.isCacheUnlocked == NO)
	{
		// Caching is disabled, so disable the controls
        self.enableBackupCacheSwitch.enabled = NO; self.enableBackupCacheLabel.alpha = 0.5;
        self.enableManualCachingOnWWANSwitch.enabled = NO; self.enableManualCachingOnWWANLabel.alpha = 0.5;
        self.enableSongCachingLabel.alpha = 0.5;
		self.enableSongCachingSwitch.enabled = NO; self.enableSongCachingSwitch.alpha = 0.5;
		self.enableNextSongCacheSwitch.enabled = NO; self.enableNextSongCacheSwitch.alpha = 0.5;
		self.cachingTypeSegmentedControl.enabled = NO; self.cachingTypeSegmentedControl.alpha = 0.5;
		self.cacheSpaceSlider.enabled = NO; self.cacheSpaceSlider.alpha = 0.5;
		self.autoDeleteCacheSwitch.enabled = NO; self.autoDeleteCacheSwitch.alpha = 0.5;
		self.autoDeleteCacheTypeSegmentedControl.enabled = NO; self.autoDeleteCacheTypeSegmentedControl.alpha = 0.5;
		self.cacheSongCellColorSegmentedControl.enabled = NO; self.cacheSongCellColorSegmentedControl.alpha = 0.5;
	}
	
	[self.cacheSpaceLabel2 addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    self.maxVideoBitrate3GSegmentedControl.selectedSegmentIndex = settingsS.maxVideoBitrate3G;
    self.maxVideoBitrateWifiSegmentedControl.selectedSegmentIndex = settingsS.maxVideoBitrateWifi;
    
    // Fix switch positions for iOS 7
    if (IS_IOS7())
    {
        for (UISwitch *sw in self.switches)
        {
            sw.x += 5.;
        }
        
        self.autoDeleteCacheSwitch.x -= 10.;
    }
}

- (void)reloadTwitterUIElements
{
    void (^enableTwitterUI)(ACAccount*) = ^(ACAccount *acct)
    {
        // Get account and communicate with Twitter API
        self.twitterEnabledSwitch.enabled = YES;
        if (settingsS.isTwitterEnabled)
            self.twitterEnabledSwitch.on = YES;
        else
            self.twitterEnabledSwitch.on = NO;
        
        [self.twitterSigninButton setImage:[UIImage imageNamed:@"twitter-signout.png"] forState:UIControlStateNormal];
        
        self.twitterStatusLabel.text = [NSString stringWithFormat:@"%@ signed in", [acct username]];
    };
    
    void (^disableTwitterUI)(void) = ^()
    {
        self.twitterEnabledSwitch.on = NO;
		self.twitterEnabledSwitch.enabled = NO;
		
        [self.twitterSigninButton setImage:[UIImage imageNamed:@"twitter-signin.png"] forState:UIControlStateNormal];
                
		self.twitterStatusLabel.text = @"Signed out";
    };
    
    if (settingsS.currentTwitterAccount)
    {
        ACAccount *account = [[[ACAccountStore alloc] init] accountWithIdentifier:settingsS.currentTwitterAccount];
        enableTwitterUI(account);
    }
    else
    {
        disableTwitterUI();
    }
}

- (void)cachingTypeToggle
{
	if (self.cachingTypeSegmentedControl.selectedSegmentIndex == 0)
	{
		self.cacheSpaceLabel1.text = @"Minimum free space:";
		//self.cacheSpaceLabel2.text = [settings formatFileSize:[[appDelegateS.settingsDictionary objectForKey:@"minFreeSpace"] unsignedLongLongValue]];
		self.cacheSpaceLabel2.text = [NSString formatFileSize:settingsS.minFreeSpace];
		//self.cacheSpaceSlider.value = [[appDelegateS.settingsDictionary objectForKey:@"minFreeSpace"] floatValue] / totalSpace;
		self.cacheSpaceSlider.value = (float)settingsS.minFreeSpace / self.totalSpace;
	}
	else if (self.cachingTypeSegmentedControl.selectedSegmentIndex == 1)
	{
		self.cacheSpaceLabel1.text = @"Maximum cache size:";
		//self.cacheSpaceLabel2.text = [settings formatFileSize:[[appDelegateS.settingsDictionary objectForKey:@"maxCacheSize"] unsignedLongLongValue]];
		self.cacheSpaceLabel2.text = [NSString formatFileSize:settingsS.maxCacheSize];
		//self.cacheSpaceSlider.value = [[appDelegateS.settingsDictionary objectForKey:@"maxCacheSize"] floatValue] / totalSpace;
		self.cacheSpaceSlider.value = (float)settingsS.maxCacheSize / self.totalSpace;
	}
}

- (IBAction)segmentAction:(id)sender
{
	if ([[NSDate date] timeIntervalSinceDate:self.loadedTime] > 0.5)
	{
		if (sender == self.recoverSegmentedControl)
		{
			settingsS.recoverSetting = self.recoverSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == self.maxBitrateWifiSegmentedControl)
		{
			settingsS.maxBitrateWifi = self.maxBitrateWifiSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == self.maxBitrate3GSegmentedControl)
		{
			settingsS.maxBitrate3G = self.maxBitrate3GSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == self.cachingTypeSegmentedControl)
		{
			settingsS.cachingType = self.cachingTypeSegmentedControl.selectedSegmentIndex;
			[self cachingTypeToggle];
		}
		else if (sender == self.autoDeleteCacheTypeSegmentedControl)
		{
			settingsS.autoDeleteCacheType = self.autoDeleteCacheTypeSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == self.cacheSongCellColorSegmentedControl)
		{
			settingsS.cachedSongCellColorType = self.cacheSongCellColorSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == self.quickSkipSegmentControl)
		{
			switch (self.quickSkipSegmentControl.selectedSegmentIndex) 
			{
				case 0: settingsS.quickSkipNumberOfSeconds = 5; break;
				case 1: settingsS.quickSkipNumberOfSeconds = 15; break;
				case 2: settingsS.quickSkipNumberOfSeconds = 30; break;
				case 3: settingsS.quickSkipNumberOfSeconds = 45; break;
				case 4: settingsS.quickSkipNumberOfSeconds = 60; break;
				case 5: settingsS.quickSkipNumberOfSeconds = 120; break;
				case 6: settingsS.quickSkipNumberOfSeconds = 300; break;
				case 7: settingsS.quickSkipNumberOfSeconds = 600; break;
				case 8: settingsS.quickSkipNumberOfSeconds = 1200; break;
				default: break;
			}
			
			if (IS_IPAD())
				[appDelegateS.ipadRootViewController.menuViewController.playerController quickSecondsSetLabels];
		}
        else if (sender == self.maxVideoBitrate3GSegmentedControl)
        {
            settingsS.maxVideoBitrate3G = self.maxVideoBitrate3GSegmentedControl.selectedSegmentIndex;
        }
        else if (sender == self.maxVideoBitrateWifiSegmentedControl)
        {
            settingsS.maxVideoBitrateWifi = self.maxVideoBitrateWifiSegmentedControl.selectedSegmentIndex;
        }
	}
}

- (void)toggleCacheControlsVisibility
{
	if (self.enableSongCachingSwitch.on)
	{
		self.enableNextSongCacheLabel.alpha = 1;
		self.enableNextSongCacheSwitch.enabled = YES;
		self.enableNextSongCacheSwitch.alpha = 1;
		self.enableNextSongPartialCacheLabel.alpha = 1;
		self.enableNextSongPartialCacheSwitch.enabled = YES;
		self.enableNextSongPartialCacheSwitch.alpha = 1;
		self.cachingTypeSegmentedControl.enabled = YES;
		self.cachingTypeSegmentedControl.alpha = 1;
		self.cacheSpaceLabel1.alpha = 1;
		self.cacheSpaceLabel2.alpha = 1;
		self.freeSpaceLabel.alpha = 1;
		self.totalSpaceLabel.alpha = 1;
		self.totalSpaceBackground.alpha = .7;
		self.freeSpaceBackground.alpha = .7;
		self.cacheSpaceSlider.enabled = YES;
		self.cacheSpaceSlider.alpha = 1;
		self.cacheSpaceDescLabel.alpha = 1;
		
		if (!self.enableNextSongCacheSwitch.on)
		{
			self.enableNextSongPartialCacheLabel.alpha = .5;
			self.enableNextSongPartialCacheSwitch.enabled = NO;
			self.enableNextSongPartialCacheSwitch.alpha = .5;
		}
	}
	else
	{
		self.enableNextSongCacheLabel.alpha = .5;
		self.enableNextSongCacheSwitch.enabled = NO;
		self.enableNextSongCacheSwitch.alpha = .5;
		self.enableNextSongPartialCacheLabel.alpha = .5;
		self.enableNextSongPartialCacheSwitch.enabled = NO;
		self.enableNextSongPartialCacheSwitch.alpha = .5;
		self.cachingTypeSegmentedControl.enabled = NO;
		self.cachingTypeSegmentedControl.alpha = .5;
		self.cacheSpaceLabel1.alpha = .5;
		self.cacheSpaceLabel2.alpha = .5;
		self.freeSpaceLabel.alpha = .5;
		self.totalSpaceLabel.alpha = .5;
		self.totalSpaceBackground.alpha = .3;
		self.freeSpaceBackground.alpha = .3;
		self.cacheSpaceSlider.enabled = NO;
		self.cacheSpaceSlider.alpha = .5;
		self.cacheSpaceDescLabel.alpha = .5;
	}
}

- (IBAction)switchAction:(id)sender
{
	if ([[NSDate date] timeIntervalSinceDate:self.loadedTime] > 0.5)
	{
		if (sender == self.manualOfflineModeSwitch)
		{
			settingsS.isForceOfflineMode = self.manualOfflineModeSwitch.on;
			if (self.manualOfflineModeSwitch.on)
			{
				[appDelegateS enterOfflineModeForce];
			}
			else
			{
				[appDelegateS enterOnlineModeForce];
			}
			
			// Handle the moreNavigationController stupidity
			if (appDelegateS.currentTabBarController.selectedIndex == 4)
			{
				[appDelegateS.currentTabBarController.moreNavigationController popToViewController:[appDelegateS.currentTabBarController.moreNavigationController.viewControllers objectAtIndexSafe:1] animated:YES];
			}
			else
			{
				[(UINavigationController*)appDelegateS.currentTabBarController.selectedViewController popToRootViewControllerAnimated:YES];
			}
		}
		else if (sender == self.enableScrobblingSwitch)
		{
			settingsS.isScrobbleEnabled = self.enableScrobblingSwitch.on;
		}
        else if (sender == self.enableManualCachingOnWWANSwitch)
        {
            if (self.enableManualCachingOnWWANSwitch.on)
            {
                // Prompt the warning
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"This feature can use a large amount of data. Please be sure to monitor your data plan usage to avoid overage charges from your wireless provider." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
                alert.tag = 2;
                [alert show];
            }
            else
            {
                settingsS.isManualCachingOnWWANEnabled = NO;
            }
        }
		else if (sender == self.enableSongCachingSwitch)
		{
			settingsS.isSongCachingEnabled = self.enableSongCachingSwitch.on;
			[self toggleCacheControlsVisibility];
		}
		else if (sender == self.enableNextSongCacheSwitch)
		{
			settingsS.isNextSongCacheEnabled = self.enableNextSongCacheSwitch.on;
			[self toggleCacheControlsVisibility];
		}
		else if (sender == self.enableNextSongPartialCacheSwitch)
		{
            if (self.enableNextSongPartialCacheSwitch.on)
            {
                // Prompt the warning
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"Due to changes in Subsonic, this will cause audio corruption if transcoding is enabled.\n\nIf you're not sure what that means, choose cancel." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
                alert.tag = 3;
                [alert show];
            }
            else
            {
                settingsS.isPartialCacheNextSong = NO;
            }
		}
        else if (sender == self.enableBackupCacheSwitch)
		{
            if (self.enableBackupCacheSwitch.on)
            {
                // Prompt the warning
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"This setting can take up a large amount of space on your computer or iCloud storage. Are you sure you want to backup your cached songs?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
                alert.tag = 4;
                [alert show];
            }
            else
            {
                settingsS.isBackupCacheEnabled = NO;
            }
		}
		else if (sender == self.autoDeleteCacheSwitch)
		{
			settingsS.isAutoDeleteCacheEnabled = self.autoDeleteCacheSwitch.on;
		}
		else if (sender == self.twitterEnabledSwitch)
		{
			settingsS.isTwitterEnabled = self.twitterEnabledSwitch.on;
		}
		else if (sender == self.checkUpdatesSwitch)
		{
			settingsS.isUpdateCheckEnabled = self.checkUpdatesSwitch.on;
		}
		else if (sender == self.showLargeSongInfoSwitch)
		{
			settingsS.isShowLargeSongInfoInPlayer = self.showLargeSongInfoSwitch.on;
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LargeSongInfoToggle];
		}
		else if (sender == self.enableLyricsSwitch)
		{
			settingsS.isLyricsEnabled = self.enableLyricsSwitch.on;
		}
		else if (sender == self.enableCacheStatusSwitch)
		{
			settingsS.isCacheStatusEnabled = self.enableCacheStatusSwitch.on;
		}
		else if (sender == self.enableSwipeSwitch)
		{
			settingsS.isSwipeEnabled = self.enableSwipeSwitch.on;
		}
		else if (sender == self.enableTapAndHoldSwitch)
		{
			settingsS.isTapAndHoldEnabled = self.enableTapAndHoldSwitch.on;
		}
		else if (sender == self.autoReloadArtistSwitch)
		{
			settingsS.isAutoReloadArtistsEnabled = self.autoReloadArtistSwitch.on;
		}
		else if (sender == self.disablePopupsSwitch)
		{
			settingsS.isPopupsEnabled = !self.disablePopupsSwitch.on;
		}
		else if (sender == self.enableSongsTabSwitch)
		{
			if (self.enableSongsTabSwitch.on)
			{
				settingsS.isSongsTabEnabled = YES;
				
				if (IS_IPAD())
				{
					[appDelegateS.ipadRootViewController.menuViewController loadCellContents];
				}
				else
				{
					NSMutableArray *controllers = [NSMutableArray arrayWithArray:appDelegateS.mainTabBarController.viewControllers];
					[controllers addObject:appDelegateS.allAlbumsNavigationController];
					[controllers addObject:appDelegateS.allSongsNavigationController];
					[controllers addObject:appDelegateS.genresNavigationController];
					appDelegateS.mainTabBarController.viewControllers = controllers;
				}
				
				[databaseS setupAllSongsDb];
			}
			else
			{
				settingsS.isSongsTabEnabled = NO;

				if (IS_IPAD())
					[appDelegateS.ipadRootViewController.menuViewController loadCellContents];
				else
					[viewObjectsS orderMainTabBarController];
				
				[databaseS.allAlbumsDbQueue close];
				databaseS.allAlbumsDbQueue = nil;
				[databaseS.allSongsDbQueue close];
				databaseS.allSongsDbQueue = nil;
				[databaseS.genresDbQueue close];
				databaseS.genresDbQueue = nil;
			}
		}
		else if (sender == self.disableRotationSwitch)
		{
			settingsS.isRotationLockEnabled = self.disableRotationSwitch.on;
		}
		else if (sender == self.disableScreenSleepSwitch)
		{
			settingsS.isScreenSleepEnabled = !self.disableScreenSleepSwitch.on;
			[UIApplication sharedApplication].idleTimerDisabled = self.disableScreenSleepSwitch.on;
		}
		else if (sender == self.enableBasicAuthSwitch)
		{
			settingsS.isBasicAuthEnabled = self.enableBasicAuthSwitch.on;
		}
		else if (sender == self.enableLockScreenArt)
		{
			settingsS.isLockScreenArtEnabled = self.enableLockScreenArt.on;
		}
        else if (sender == self.disableCellUsageSwitch)
        {
            settingsS.isDisableUsageOver3G = self.disableCellUsageSwitch.on;
            
            BOOL handleStupidity = NO;
            if (!settingsS.isOfflineMode && settingsS.isDisableUsageOver3G && ![LibSub isWifi])
            {
                // We're on 3G and we just disabled use on 3G, so go offline
                [appDelegateS enterOfflineModeForce];
                
                handleStupidity = YES;
            }
            else if (settingsS.isOfflineMode && !settingsS.isDisableUsageOver3G && ![LibSub isWifi])
            {
                // We're on 3G and we just enabled use on 3G, so go online if we're offline
                [appDelegateS enterOfflineModeForce];
                
                handleStupidity = YES;
            }
            
            if (handleStupidity)
            {
                // Handle the moreNavigationController stupidity
                if (appDelegateS.currentTabBarController.selectedIndex == 4)
                {
                    [appDelegateS.currentTabBarController.moreNavigationController popToViewController:[appDelegateS.currentTabBarController.moreNavigationController.viewControllers objectAtIndexSafe:1] animated:YES];
                }
                else
                {
                    [(UINavigationController*)appDelegateS.currentTabBarController.selectedViewController popToRootViewControllerAnimated:YES];
                }
            }
        }
	}
}

- (IBAction)resetAlbumArtCacheAction
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Reset Album Art Cache" message:@"Are you sure you want to do this? This will clear all saved album art." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
	alert.tag = 1;
	[alert show];
}

- (void)resetFolderCache
{
	[databaseS resetFolderCache];
	[viewObjectsS hideLoadingScreen];
	[self popFoldersTab];
}

- (void)resetAlbumArtCache
{
	[databaseS resetCoverArtCache];
	[viewObjectsS hideLoadingScreen];
	[self popFoldersTab];
}

- (void)popFoldersTab
{
	if (IS_IPAD())
		[appDelegateS.artistsNavigationController popToRootViewControllerAnimated:NO];
	else
		[appDelegateS.rootViewController.navigationController popToRootViewControllerAnimated:NO];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView.tag == 0 && buttonIndex == 1)
	{
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Processing"];
		[self performSelector:@selector(resetFolderCache) withObject:nil afterDelay:0.05];
	}
	else if (alertView.tag == 1 && buttonIndex == 1)
	{
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Processing"];
		[self performSelector:@selector(resetAlbumArtCache) withObject:nil afterDelay:0.05];
	}
    else if (alertView.tag == 2)
    {
        if (buttonIndex == 0)
        {
            // They canceled, turn off the switch
            [self.enableManualCachingOnWWANSwitch setOn:NO animated:YES];
        }
        else
        {
            settingsS.isManualCachingOnWWANEnabled = YES;
        }
    }
    else if (alertView.tag == 3)
    {
        if (buttonIndex == 0)
        {
            [self.enableNextSongPartialCacheSwitch setOn:NO animated:YES];
        }
        else
        {
            settingsS.isPartialCacheNextSong = YES;
        }
    }
    else if (alertView.tag == 4)
    {
        if (buttonIndex == 0)
        {
            [self.enableBackupCacheSwitch setOn:NO animated:YES];
        }
        else
        {
            settingsS.isBackupCacheEnabled = YES;
        }
    }
}

- (void)updateCacheSpaceSlider
{
	self.cacheSpaceSlider.value = ((double)[self.cacheSpaceLabel2.text fileSizeFromFormat] / (double)self.totalSpace);
}

- (IBAction)updateMinFreeSpaceLabel
{
	self.cacheSpaceLabel2.text = [NSString formatFileSize:(unsigned long long int) (self.cacheSpaceSlider.value * self.totalSpace)];
}

- (IBAction)updateMinFreeSpaceSetting
{
	if (self.cachingTypeSegmentedControl.selectedSegmentIndex == 0)
	{
		// Check if the user is trying to assing a higher min free space than is available space - 50MB
		if (self.cacheSpaceSlider.value * self.totalSpace > self.freeSpace - 52428800)
		{
			settingsS.minFreeSpace = self.freeSpace - 52428800;
			self.cacheSpaceSlider.value = ((float)settingsS.minFreeSpace / (float)self.totalSpace); // Leave 50MB space
		}
		else if (self.cacheSpaceSlider.value * self.totalSpace < 52428800)
		{
			settingsS.minFreeSpace = 52428800;
			self.cacheSpaceSlider.value = ((float)settingsS.minFreeSpace / (float)self.totalSpace); // Leave 50MB space
		}
		else 
		{
			settingsS.minFreeSpace = (unsigned long long int) (self.cacheSpaceSlider.value * (float)self.totalSpace);
		}
		//cacheSpaceLabel2.text = [NSString formatFileSize:settingsS.minFreeSpace];
	}
	else if (self.cachingTypeSegmentedControl.selectedSegmentIndex == 1)
	{
		
		// Check if the user is trying to assign a larger max cache size than there is available space - 50MB
		if (self.cacheSpaceSlider.value * self.totalSpace > self.freeSpace - 52428800)
		{
			settingsS.maxCacheSize = self.freeSpace - 52428800;
			self.cacheSpaceSlider.value = ((float)settingsS.maxCacheSize / (float)self.totalSpace); // Leave 50MB space
		}
		else if (self.cacheSpaceSlider.value * self.totalSpace < 52428800)
		{
			settingsS.maxCacheSize = 52428800;
			self.cacheSpaceSlider.value = ((float)settingsS.maxCacheSize / (float)self.totalSpace); // Leave 50MB space
		}
		else
		{
			settingsS.maxCacheSize = (unsigned long long int) (self.cacheSpaceSlider.value * self.totalSpace);
		}
		//cacheSpaceLabel2.text = [NSString formatFileSize:settingsS.maxCacheSize];
	}
	[self updateMinFreeSpaceLabel];
}

- (IBAction)revertMinFreeSpaceSlider
{
	self.cacheSpaceLabel2.text = [NSString formatFileSize:settingsS.minFreeSpace];
	self.cacheSpaceSlider.value = (float)settingsS.minFreeSpace / self.totalSpace;
}

- (IBAction)twitterButtonAction
{
    ACAccountStore *account = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [account accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    if (settingsS.currentTwitterAccount)
    {
        settingsS.currentTwitterAccount = nil;
        [self reloadTwitterUIElements];
    }
    else
    {
        [account requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error)
        {
            if (granted == YES)
            {
                [EX2Dispatch runInMainThreadAsync:^
                 {
                     if ([[account accounts] count] == 1)
                     {
                         settingsS.currentTwitterAccount = [[[account accounts] firstObjectSafe] identifier];
                         [self reloadTwitterUIElements];
                     }
                     else if ([[account accounts] count] > 1)
                     {
                         // more than one account, use Chooser
                         IDTwitterAccountChooserViewController *chooser = [[IDTwitterAccountChooserViewController alloc] initWithRootViewController:nil];
                         [chooser setTwitterAccounts:[account accounts]];
                         [chooser setCompletionHandler:^(ACAccount *account)
                          {
                              if (account)
                              {
                                  settingsS.currentTwitterAccount = [account identifier];
                                  [self reloadTwitterUIElements];
                              }
                          }];
                         [self.parentController.navigationController presentViewController:chooser animated:YES completion:nil];
                     }
                     else
                     {
                         [[[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"To use this feature, please add a Twitter account in the iOS Settings app.", @"No twitter accounts alert") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                     }
                 }];
            }
        }];
    }
}

//	if (socialS.twitterEngine.isAuthorized)
//	{
//		[socialS destroyTwitterEngine];
//		[self reloadTwitterUIElements];
//	}
//	else
//	{
//		if (!socialS.twitterEngine)
//			[socialS createTwitterEngine];
//		
//		UIViewController *controller = [SA_OAuthTwitterController controllerToEnterCredentialsWithTwitterEngine:socialS.twitterEngine delegate:(id)socialS];
//		if (controller) 
//		{
//			if (IS_IPAD())
//				[appDelegateS.ipadRootViewController presentModalViewController:controller animated:YES];
//			else
//				[self.parentController presentModalViewController:controller animated:YES];
//		}
//	}
//}

- (IBAction)updateScrobblePercentLabel
{
	NSUInteger percentInt = self.scrobblePercentSlider.value * 100;
	self.scrobblePercentLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)percentInt];
}

- (IBAction)updateScrobblePercentSetting;
{
	settingsS.scrobblePercent = self.scrobblePercentSlider.value;
}

- (void)didReceiveMemoryWarning 
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
	UITableView *tableView = (UITableView *)self.view.superview;
	CGRect rect = CGRectMake(0, 500, 320, 5);
	[tableView scrollRectToVisible:rect animated:NO];
	rect = UIInterfaceOrientationIsPortrait(self.interfaceOrientation) ? CGRectMake(0, 1600, 320, 5) : CGRectMake(0, 1455, 320, 5);
	[tableView scrollRectToVisible:rect animated:NO];
}

// This dismisses the keyboard when the "done" button is pressed
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[self updateMinFreeSpaceSetting];
	[textField resignFirstResponder];
	return YES;
}

- (void)textFieldDidChange:(UITextField *)textField
{
	[self updateCacheSpaceSlider];
//DLog(@"file size: %llu   formatted: %@", [textField.text fileSizeFromFormat], [NSString formatFileSize:[textField.text fileSizeFromFormat]]);
}

// Fix for panel sliding on iPad while using sliders
- (IBAction)touchDown:(id)sender
{
    appDelegateS.ipadRootViewController.stackScrollViewController.isSlidingEnabled = NO;
}
- (IBAction)touchUpInside:(id)sender
{
    appDelegateS.ipadRootViewController.stackScrollViewController.isSlidingEnabled = YES;
}
- (IBAction)touchUpOutside:(id)sender
{
    appDelegateS.ipadRootViewController.stackScrollViewController.isSlidingEnabled = YES;
}

@end
