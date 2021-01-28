//
//  OptionsViewController.m
//  iSub
//
//  Created by Ben Baron on 6/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "OptionsViewController.h"
#import "SavedSettings.h"
#import "Swift.h"
#import "UIView+ObjCFrameHelper.h"
#import <CocoaLumberjack/CocoaLumberjack.h>
#import <Accounts/Accounts.h>
#import <Social/Social.h>

LOG_LEVEL_ISUB_DEFAULT

@implementation OptionsViewController

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad  {
    [super viewDidLoad];
    
    self.scrollViewContents.width = self.view.width;
    
    self.scrollView.scrollEnabled = YES;
    self.scrollView.showsVerticalScrollIndicator = YES;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.contentSize = self.scrollViewContents.frame.size;
    [self.scrollView addSubview:self.scrollViewContents];
	
	// Fix for UISwitch/UISegment bug in iOS 4.3 beta 1 and 2
	// TODO: Confirm this is no longer an issue (presumably not lol)
	self.loadedTime = [NSDate date];
		
	// Set version label
    NSString *version = [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleShortVersionString"];
    NSString *build = [NSBundle.mainBundle.infoDictionary objectForKey:(NSString*)kCFBundleVersionKey];
	self.versionLabel.text = [NSString stringWithFormat:@"iSub %@ build %@", version, build];
	
	// Main Settings
	self.enableScrobblingSwitch.on = settingsS.isScrobbleEnabled;
	self.scrobblePercentSlider.value = settingsS.scrobblePercent;
	[self updateScrobblePercentLabel];
    self.manualOfflineModeSwitch.on = settingsS.isForceOfflineMode;
	self.autoReloadArtistSwitch.on = settingsS.isAutoReloadArtistsEnabled;
	self.disablePopupsSwitch.on = !settingsS.isPopupsEnabled;
	self.disableRotationSwitch.on = settingsS.isRotationLockEnabled;
	self.disableScreenSleepSwitch.on = !settingsS.isScreenSleepEnabled;
	self.enableBasicAuthSwitch.on = settingsS.isBasicAuthEnabled;
    self.disableCellUsageSwitch.on = settingsS.isDisableUsageOver3G;
	self.recoverSegmentedControl.selectedSegmentIndex = settingsS.recoverSetting;
	self.maxBitrateWifiSegmentedControl.selectedSegmentIndex = settingsS.maxBitrateWifi;
	self.maxBitrate3GSegmentedControl.selectedSegmentIndex = settingsS.maxBitrate3G;
	self.enableSwipeSwitch.on = settingsS.isSwipeEnabled;
	self.enableTapAndHoldSwitch.on = settingsS.isTapAndHoldEnabled;
	self.enableLockScreenArt.on = settingsS.isLockScreenArtEnabled;
	
	// Cache Settings
    self.enableManualCachingOnWWANSwitch.on = settingsS.isManualCachingOnWWANEnabled;
	self.enableSongCachingSwitch.on = settingsS.isSongCachingEnabled;
	self.enableNextSongCacheSwitch.on = settingsS.isNextSongCacheEnabled;
    self.enableBackupCacheSwitch.on = settingsS.isBackupCacheEnabled;
    [self.cacheSpaceSlider setThumbImage:[UIImage imageNamed:@"controller-slider-thumb"] forState:UIControlStateNormal];
	self.totalSpace = Cache.shared.totalSpace;
	self.freeSpace = Cache.shared.freeSpace;
	self.freeSpaceLabel.text = [NSString stringWithFormat:@"Free space: %@", [ObjCDeleteMe formatFileSizeWithBytes:self.freeSpace]];
	self.totalSpaceLabel.text = [NSString stringWithFormat:@"Total space: %@", [ObjCDeleteMe formatFileSizeWithBytes:self.totalSpace]];
	float percentFree = (float) self.freeSpace / (float) self.totalSpace;
	CGRect frame = self.freeSpaceBackground.frame;
	frame.size.width *= percentFree;
	self.freeSpaceBackground.frame = frame;
	self.cachingTypeSegmentedControl.selectedSegmentIndex = settingsS.cachingType;
	[self toggleCacheControlsVisibility];
	[self cachingTypeToggle];
	
	self.autoDeleteCacheSwitch.on = settingsS.isAutoDeleteCacheEnabled;
	self.autoDeleteCacheTypeSegmentedControl.selectedSegmentIndex = settingsS.autoDeleteCacheType;
	self.cacheSongCellColorSegmentedControl.selectedSegmentIndex = settingsS.cachedSongCellColorType;
    
	switch (settingsS.quickSkipNumberOfSeconds) {
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
    
    // Fix cut off text on small devices
    if (UIDevice.isSmall) {
        [self.quickSkipSegmentControl setTitleTextAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:11]} forState:UIControlStateNormal];
    }
	
	[self.cacheSpaceLabel2 addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    self.maxVideoBitrate3GSegmentedControl.selectedSegmentIndex = settingsS.maxVideoBitrate3G;
    self.maxVideoBitrateWifiSegmentedControl.selectedSegmentIndex = settingsS.maxVideoBitrateWifi;
    
    self.resetAlbumArtCacheButton.backgroundColor = UIColor.whiteColor;
    self.resetAlbumArtCacheButton.layer.cornerRadius = 8;
    
    self.shareLogsButton.backgroundColor = UIColor.whiteColor;
    self.shareLogsButton.layer.cornerRadius = 8;
    
    self.openSourceLicensesButton.backgroundColor = UIColor.whiteColor;
    self.openSourceLicensesButton.layer.cornerRadius = 8;
}

- (void)cachingTypeToggle {
	if (self.cachingTypeSegmentedControl.selectedSegmentIndex == 0) {
		self.cacheSpaceLabel1.text = @"Minimum free space:";
		self.cacheSpaceLabel2.text = [ObjCDeleteMe formatFileSizeWithBytes:settingsS.minFreeSpace];
		self.cacheSpaceSlider.value = ((float)settingsS.minFreeSpace / self.totalSpace);
	} else if (self.cachingTypeSegmentedControl.selectedSegmentIndex == 1) {
		self.cacheSpaceLabel1.text = @"Maximum cache size:";
		self.cacheSpaceLabel2.text = [ObjCDeleteMe formatFileSizeWithBytes:settingsS.maxCacheSize];
		self.cacheSpaceSlider.value = ((float)settingsS.maxCacheSize / self.totalSpace);
	}
}

- (IBAction)segmentAction:(id)sender {
	if ([[NSDate date] timeIntervalSinceDate:self.loadedTime] > 0.5) {
		if (sender == self.recoverSegmentedControl) {
			settingsS.recoverSetting = self.recoverSegmentedControl.selectedSegmentIndex;
		} else if (sender == self.maxBitrateWifiSegmentedControl) {
			settingsS.maxBitrateWifi = self.maxBitrateWifiSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == self.maxBitrate3GSegmentedControl) {
			settingsS.maxBitrate3G = self.maxBitrate3GSegmentedControl.selectedSegmentIndex;
		} else if (sender == self.cachingTypeSegmentedControl) {
			settingsS.cachingType = self.cachingTypeSegmentedControl.selectedSegmentIndex;
			[self cachingTypeToggle];
		} else if (sender == self.autoDeleteCacheTypeSegmentedControl) {
			settingsS.autoDeleteCacheType = self.autoDeleteCacheTypeSegmentedControl.selectedSegmentIndex;
		} else if (sender == self.cacheSongCellColorSegmentedControl) {
			settingsS.cachedSongCellColorType = self.cacheSongCellColorSegmentedControl.selectedSegmentIndex;
		} else if (sender == self.quickSkipSegmentControl) {
			switch (self.quickSkipSegmentControl.selectedSegmentIndex)  {
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
			
            if (UIDevice.isPad) {
                // Update the quick skip buttons in the player with the new values on iPad since player is always visible
                [NSNotificationCenter postOnMainThreadWithName:Notifications.quickSkipSecondsSettingChanged object:nil userInfo:nil];
            }
		} else if (sender == self.maxVideoBitrate3GSegmentedControl) {
            settingsS.maxVideoBitrate3G = self.maxVideoBitrate3GSegmentedControl.selectedSegmentIndex;
        } else if (sender == self.maxVideoBitrateWifiSegmentedControl) {
            settingsS.maxVideoBitrateWifi = self.maxVideoBitrateWifiSegmentedControl.selectedSegmentIndex;
        }
	}
}

- (void)toggleCacheControlsVisibility {
	if (self.enableSongCachingSwitch.on) {
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
		
		if (!self.enableNextSongCacheSwitch.on) {
			self.enableNextSongPartialCacheLabel.alpha = .5;
			self.enableNextSongPartialCacheSwitch.enabled = NO;
			self.enableNextSongPartialCacheSwitch.alpha = .5;
		}
	} else {
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

- (IBAction)switchAction:(id)sender {
	if ([[NSDate date] timeIntervalSinceDate:self.loadedTime] > 0.5) {
		if (sender == self.manualOfflineModeSwitch) {
			settingsS.isForceOfflineMode = self.manualOfflineModeSwitch.on;
			if (self.manualOfflineModeSwitch.on) {
				[AppDelegate.shared enterOfflineModeForce];
			} else {
				[AppDelegate.shared enterOnlineModeForce];
			}
			
			// Handle the moreNavigationController stupidity
            UITabBarController *tabBarController = SceneDelegate.shared.tabBarController;
			if (tabBarController.selectedIndex == 4) {
				[tabBarController.moreNavigationController popToViewController:tabBarController.moreNavigationController.viewControllers[1] animated:YES];
			} else {
				[(UINavigationController*)tabBarController.selectedViewController popToRootViewControllerAnimated:YES];
			}
		}
		else if (sender == self.enableScrobblingSwitch) {
			settingsS.isScrobbleEnabled = self.enableScrobblingSwitch.on;
		} else if (sender == self.enableManualCachingOnWWANSwitch) {
            if (self.enableManualCachingOnWWANSwitch.on) {
                // Prompt the warning
                NSString *message = @"This feature can use a large amount of data. Please be sure to monitor your data plan usage to avoid overage charges from your wireless provider.";
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Warning"
                                                                               message:message
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                    settingsS.isManualCachingOnWWANEnabled = YES;
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                    // They canceled, turn off the switch
                    [self.enableManualCachingOnWWANSwitch setOn:NO animated:YES];
                }]];
                [self presentViewController:alert animated:YES completion:nil];
            } else {
                settingsS.isManualCachingOnWWANEnabled = NO;
            }
        } else if (sender == self.enableSongCachingSwitch) {
			settingsS.isSongCachingEnabled = self.enableSongCachingSwitch.on;
			[self toggleCacheControlsVisibility];
		} else if (sender == self.enableNextSongCacheSwitch) {
			settingsS.isNextSongCacheEnabled = self.enableNextSongCacheSwitch.on;
			[self toggleCacheControlsVisibility];
		} else if (sender == self.enableBackupCacheSwitch) {
            if (self.enableBackupCacheSwitch.on) {
                // Prompt the warning
                NSString *message = @"This setting can take up a large amount of space on your computer or iCloud storage. Are you sure you want to backup your cached songs?";
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Warning"
                                                                               message:message
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                    settingsS.isBackupCacheEnabled = YES;
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                    // They canceled, turn off the switch
                    [self.enableBackupCacheSwitch setOn:NO animated:YES];
                }]];
                [self presentViewController:alert animated:YES completion:nil];
            } else {
                settingsS.isBackupCacheEnabled = NO;
            }
		} else if (sender == self.autoDeleteCacheSwitch) {
			settingsS.isAutoDeleteCacheEnabled = self.autoDeleteCacheSwitch.on;
		} else if (sender == self.enableSwipeSwitch) {
			settingsS.isSwipeEnabled = self.enableSwipeSwitch.on;
		} else if (sender == self.enableTapAndHoldSwitch) {
			settingsS.isTapAndHoldEnabled = self.enableTapAndHoldSwitch.on;
		} else if (sender == self.autoReloadArtistSwitch) {
			settingsS.isAutoReloadArtistsEnabled = self.autoReloadArtistSwitch.on;
		} else if (sender == self.disablePopupsSwitch) {
			settingsS.isPopupsEnabled = !self.disablePopupsSwitch.on;
		} else if (sender == self.disableRotationSwitch) {
			settingsS.isRotationLockEnabled = self.disableRotationSwitch.on;
		} else if (sender == self.disableScreenSleepSwitch) {
			settingsS.isScreenSleepEnabled = !self.disableScreenSleepSwitch.on;
			[UIApplication sharedApplication].idleTimerDisabled = self.disableScreenSleepSwitch.on;
		} else if (sender == self.enableBasicAuthSwitch) {
			settingsS.isBasicAuthEnabled = self.enableBasicAuthSwitch.on;
		} else if (sender == self.enableLockScreenArt) {
			settingsS.isLockScreenArtEnabled = self.enableLockScreenArt.on;
		} else if (sender == self.disableCellUsageSwitch) {
            settingsS.isDisableUsageOver3G = self.disableCellUsageSwitch.on;
            
            BOOL handleStupidity = NO;
            if (!settingsS.isOfflineMode && settingsS.isDisableUsageOver3G && !AppDelegate.shared.isWifi) {
                // We're on 3G and we just disabled use on 3G, so go offline
                [AppDelegate.shared enterOfflineModeForce];
                handleStupidity = YES;
            } else if (settingsS.isOfflineMode && !settingsS.isDisableUsageOver3G && !AppDelegate.shared.isWifi) {
                // We're on 3G and we just enabled use on 3G, so go online if we're offline
                [AppDelegate.shared enterOfflineModeForce];
                handleStupidity = YES;
            }
            
            if (handleStupidity) {
                // Handle the moreNavigationController stupidity
                UITabBarController *tabBarController = SceneDelegate.shared.tabBarController;
                if (tabBarController.selectedIndex == 4) {
                    [tabBarController.moreNavigationController popToViewController:tabBarController.moreNavigationController.viewControllers[1] animated:YES];
                } else {
                    [(UINavigationController*)tabBarController.selectedViewController popToRootViewControllerAnimated:YES];
                }
            }
        }
	}
}

- (IBAction)resetAlbumArtCacheAction {
    NSString *message = @"Are you sure you want to do this? This will clear all saved album art.";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset Album Art Cache"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
//        [HUD showWithMessage:@"Processing"];
        [self performSelector:@selector(resetAlbumArtCache) withObject:nil afterDelay:0.05];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)resetFolderCache {
//    [HUD showWithMessage:@"Processing"];
    NSInteger serverId = settingsS.currentServerId;
    (void)[Store.shared resetFolderAlbumCacheWithServerId:serverId];
    (void)[Store.shared deleteTagAlbumsWithServerId:serverId];
//	[HUD hide];
	[self popFoldersTab];
}

- (void)resetAlbumArtCache {
//    [HUD showWithMessage:@"Processing"];
    NSInteger serverId = settingsS.currentServerId;
    (void)[Store.shared resetCoverArtCacheWithServerId:serverId];
    (void)[Store.shared resetArtistArtCacheWithServerId:serverId];
//	[HUD hide];
	[self popFoldersTab];
}

- (IBAction)shareAppLogsAction {
    NSString *path = [settingsS zipAllLogFiles];
    NSURL *pathURL = [NSURL fileURLWithPath:path];
    UIActivityViewController *shareSheet = [[UIActivityViewController alloc] initWithActivityItems:@[pathURL] applicationActivities:nil];
    if (shareSheet.popoverPresentationController) {
        // Fix exception on iPad
        shareSheet.popoverPresentationController.sourceView = self.shareLogsButton;
        shareSheet.popoverPresentationController.sourceRect = self.shareLogsButton.bounds;
    }
    shareSheet.completionWithItemsHandler = ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        // Delete the zip file since we're done with it
        NSError *error = nil;
        BOOL success = [NSFileManager.defaultManager removeItemAtURL:pathURL error:&error];
        if (!success || error) {
            DDLogError(@"[SettingsTabViewController] Failed to remove log file at path %@ with error: %@", path, error.localizedDescription);
        }
    };
    [self presentViewController:shareSheet animated:YES completion:nil];
}

- (IBAction)viewOpenSourceLicensesAction {
    LicensesViewController *controller = [[LicensesViewController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:controller];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)popFoldersTab {
    [SceneDelegate.shared.foldersTab popToRootViewControllerAnimated:NO];
    [SceneDelegate.shared.artistsTab popToRootViewControllerAnimated:NO];
}

- (void)updateCacheSpaceSlider {
    NSInteger fileSize = [ObjCDeleteMe fileSizeFromFormat:self.cacheSpaceLabel2.text];
	self.cacheSpaceSlider.value = ((double)fileSize / (double)self.totalSpace);
}

- (IBAction)updateMinFreeSpaceLabel {
	self.cacheSpaceLabel2.text = [ObjCDeleteMe formatFileSizeWithBytes:(self.cacheSpaceSlider.value * self.totalSpace)];
}

- (IBAction)updateMinFreeSpaceSetting {
	if (self.cachingTypeSegmentedControl.selectedSegmentIndex == 0) {
		// Check if the user is trying to assing a higher min free space than is available space - 50MB
		if (self.cacheSpaceSlider.value * self.totalSpace > self.freeSpace - 52428800) {
			settingsS.minFreeSpace = self.freeSpace - 52428800;
			self.cacheSpaceSlider.value = ((float)settingsS.minFreeSpace / (float)self.totalSpace); // Leave 50MB space
		} else if (self.cacheSpaceSlider.value * self.totalSpace < 52428800) {
			settingsS.minFreeSpace = 52428800;
			self.cacheSpaceSlider.value = ((float)settingsS.minFreeSpace / (float)self.totalSpace); // Leave 50MB space
		} else {
			settingsS.minFreeSpace = (self.cacheSpaceSlider.value * (float)self.totalSpace);
		}
		//cacheSpaceLabel2.text = [ObjCDeleteMe formatFileSizeWithBytes:settingsS.minFreeSpace];
	} else if (self.cachingTypeSegmentedControl.selectedSegmentIndex == 1) {
		
		// Check if the user is trying to assign a larger max cache size than there is available space - 50MB
		if (self.cacheSpaceSlider.value * self.totalSpace > self.freeSpace - 52428800) {
			settingsS.maxCacheSize = self.freeSpace - 52428800;
			self.cacheSpaceSlider.value = ((float)settingsS.maxCacheSize / (float)self.totalSpace); // Leave 50MB space
		} else if (self.cacheSpaceSlider.value * self.totalSpace < 52428800) {
			settingsS.maxCacheSize = 52428800;
			self.cacheSpaceSlider.value = ((float)settingsS.maxCacheSize / (float)self.totalSpace); // Leave 50MB space
		} else {
			settingsS.maxCacheSize = (self.cacheSpaceSlider.value * self.totalSpace);
		}
		//cacheSpaceLabel2.text = [ObjCDeleteMe formatFileSizeWithBytes:settingsS.maxCacheSize];
	}
	[self updateMinFreeSpaceLabel];
}

- (IBAction)revertMinFreeSpaceSlider {
	self.cacheSpaceLabel2.text = [ObjCDeleteMe formatFileSizeWithBytes:settingsS.minFreeSpace];
	self.cacheSpaceSlider.value = (float)settingsS.minFreeSpace / self.totalSpace;
}

- (IBAction)updateScrobblePercentLabel {
	NSInteger percentInt = self.scrobblePercentSlider.value * 100;
	self.scrobblePercentLabel.text = [NSString stringWithFormat:@"%ld", (long)percentInt];
}

- (IBAction)updateScrobblePercentSetting {
	settingsS.scrobblePercent = self.scrobblePercentSlider.value;
}

- (void)dealloc {
	[NSNotificationCenter removeObserverOnMainThread:self];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
	UITableView *tableView = (UITableView *)self.view.superview;
	CGRect rect = CGRectMake(0, 500, 320, 5);
	[tableView scrollRectToVisible:rect animated:NO];
	rect = UIInterfaceOrientationIsPortrait(UIApplication.orientation) ? CGRectMake(0, 1600, 320, 5) : CGRectMake(0, 1455, 320, 5);
	[tableView scrollRectToVisible:rect animated:NO];
}

// This dismisses the keyboard when the "done" button is pressed
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[self updateMinFreeSpaceSetting];
	[textField resignFirstResponder];
	return YES;
}

- (void)textFieldDidChange:(UITextField *)textField {
	[self updateCacheSpaceSlider];
//DLog(@"file size: %llu   formatted: %@", [ObjCDeleteMe fileSizeFromFormat:textField.text], [ObjCDeleteMe formatFileSizeWithBytes:[ObjCDeleteMe fileSizeFromFormat:textField.text]]);
}

@end
