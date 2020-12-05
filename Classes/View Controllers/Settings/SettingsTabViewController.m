//
//  SettingsTabViewController.m
//  iSub
//
//  Created by Ben Baron on 6/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SettingsTabViewController.h"
#import "FoldersViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "FMDatabaseQueueAdditions.h"
#import "SavedSettings.h"
#import "CacheSingleton.h"
#import "DatabaseSingleton.h"
#import "EX2Kit.h"
#import "Swift.h"
#import "AsynchronousImageView.h"
#import <Accounts/Accounts.h>
#import <Social/Social.h>

LOG_LEVEL_ISUB_DEFAULT

@implementation SettingsTabViewController

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad  {
    [super viewDidLoad];
	
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
	self.enableSongsTabSwitch.on = settingsS.isSongsTabEnabled;
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
	self.enableNextSongPartialCacheSwitch.on = settingsS.isPartialCacheNextSong;
    self.enableBackupCacheSwitch.on = settingsS.isBackupCacheEnabled;
    [self.cacheSpaceSlider setThumbImage:[[UIImage imageNamed:@"controller-slider-thumb"] imageWithTintColor:UIColor.blackColor] forState:UIControlStateNormal];
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
	
	[self.cacheSpaceLabel2 addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    self.maxVideoBitrate3GSegmentedControl.selectedSegmentIndex = settingsS.maxVideoBitrate3G;
    self.maxVideoBitrateWifiSegmentedControl.selectedSegmentIndex = settingsS.maxVideoBitrateWifi;
    
    self.resetAlbumArtCacheButton.backgroundColor = UIColor.whiteColor;
    self.resetAlbumArtCacheButton.layer.cornerRadius = 8;
    self.shareLogsButton.backgroundColor = UIColor.whiteColor;
    self.shareLogsButton.layer.cornerRadius = 8;
}

- (void)cachingTypeToggle {
	if (self.cachingTypeSegmentedControl.selectedSegmentIndex == 0) {
		self.cacheSpaceLabel1.text = @"Minimum free space:";
		self.cacheSpaceLabel2.text = [NSString formatFileSize:settingsS.minFreeSpace];
		self.cacheSpaceSlider.value = ((float)settingsS.minFreeSpace / self.totalSpace);
	} else if (self.cachingTypeSegmentedControl.selectedSegmentIndex == 1) {
		self.cacheSpaceLabel1.text = @"Maximum cache size:";
		self.cacheSpaceLabel2.text = [NSString formatFileSize:settingsS.maxCacheSize];
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
			
            if (UIDevice.isIPad) {
                // Update the quick skip buttons in the player with the new values on iPad since player is always visible
                [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_QuickSkipSecondsSettingChanged];
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
				[appDelegateS enterOfflineModeForce];
			} else {
				[appDelegateS enterOnlineModeForce];
			}
			
			// Handle the moreNavigationController stupidity
			if (appDelegateS.currentTabBarController.selectedIndex == 4) {
				[appDelegateS.currentTabBarController.moreNavigationController popToViewController:[appDelegateS.currentTabBarController.moreNavigationController.viewControllers objectAtIndexSafe:1] animated:YES];
			} else {
				[(UINavigationController*)appDelegateS.currentTabBarController.selectedViewController popToRootViewControllerAnimated:YES];
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
		} else if (sender == self.enableNextSongPartialCacheSwitch) {
            if (self.enableNextSongPartialCacheSwitch.on) {
                // Prompt the warning
                NSString *message = @"Due to changes in Subsonic, this will cause audio corruption if transcoding is enabled.\n\nIf you're not sure what that means, choose cancel.";
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Warning"
                                                                               message:message
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                    settingsS.isPartialCacheNextSong = YES;
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                    // They canceled, turn off the switch
                    [self.enableNextSongPartialCacheSwitch setOn:NO animated:YES];
                }]];
                [self presentViewController:alert animated:YES completion:nil];
            } else {
                settingsS.isPartialCacheNextSong = NO;
            }
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
		} else if (sender == self.enableSongsTabSwitch) {
			if (self.enableSongsTabSwitch.on) {
				settingsS.isSongsTabEnabled = YES;
				if (UIDevice.isIPad) {
					[appDelegateS.padRootViewController.menuViewController loadCellContents];
				} else {
					NSMutableArray *controllers = [NSMutableArray arrayWithArray:appDelegateS.mainTabBarController.viewControllers];
					[controllers addObject:appDelegateS.allAlbumsNavigationController];
					[controllers addObject:appDelegateS.allSongsNavigationController];
					[controllers addObject:appDelegateS.genresNavigationController];
					appDelegateS.mainTabBarController.viewControllers = controllers;
				}
				[databaseS setupAllSongsDb];
			} else {
				settingsS.isSongsTabEnabled = NO;

                if (UIDevice.isIPad) {
					[appDelegateS.padRootViewController.menuViewController loadCellContents];
                } else {
					[viewObjectsS orderMainTabBarController];
                }
                
				[databaseS.allAlbumsDbQueue close];
				databaseS.allAlbumsDbQueue = nil;
				[databaseS.allSongsDbQueue close];
				databaseS.allSongsDbQueue = nil;
				[databaseS.genresDbQueue close];
				databaseS.genresDbQueue = nil;
			}
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
            if (!settingsS.isOfflineMode && settingsS.isDisableUsageOver3G && !EX2Reachability.isWifi) {
                // We're on 3G and we just disabled use on 3G, so go offline
                [appDelegateS enterOfflineModeForce];
                handleStupidity = YES;
            } else if (settingsS.isOfflineMode && !settingsS.isDisableUsageOver3G && !EX2Reachability.isWifi) {
                // We're on 3G and we just enabled use on 3G, so go online if we're offline
                [appDelegateS enterOfflineModeForce];
                handleStupidity = YES;
            }
            
            if (handleStupidity) {
                // Handle the moreNavigationController stupidity
                if (appDelegateS.currentTabBarController.selectedIndex == 4) {
                    [appDelegateS.currentTabBarController.moreNavigationController popToViewController:[appDelegateS.currentTabBarController.moreNavigationController.viewControllers objectAtIndexSafe:1] animated:YES];
                } else {
                    [(UINavigationController*)appDelegateS.currentTabBarController.selectedViewController popToRootViewControllerAnimated:YES];
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
        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Processing"];
        [self performSelector:@selector(resetAlbumArtCache) withObject:nil afterDelay:0.05];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)resetFolderCache {
	[databaseS resetFolderCache];
	[viewObjectsS hideLoadingScreen];
	[self popFoldersTab];
}

- (void)resetAlbumArtCache {
	[databaseS resetCoverArtCache];
	[viewObjectsS hideLoadingScreen];
	[self popFoldersTab];
}

- (IBAction)shareAppLogsAction {
    NSString *path = [appDelegateS zipAllLogFiles];
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
            DDLogError(@"Failed to remove log file at path %@ with error: %@", path, error.localizedDescription);
        }
    };
    [self presentViewController:shareSheet animated:YES completion:nil];
}

- (void)popFoldersTab {
    if (UIDevice.isIPad) {
		[appDelegateS.artistsNavigationController popToRootViewControllerAnimated:NO];
    } else {
		[appDelegateS.rootViewController.navigationController popToRootViewControllerAnimated:NO];
    }
}

- (void)updateCacheSpaceSlider {
	self.cacheSpaceSlider.value = ((double)[self.cacheSpaceLabel2.text fileSizeFromFormat] / (double)self.totalSpace);
}

- (IBAction)updateMinFreeSpaceLabel {
	self.cacheSpaceLabel2.text = [NSString formatFileSize:(unsigned long long int) (self.cacheSpaceSlider.value * self.totalSpace)];
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
			settingsS.minFreeSpace = (unsigned long long int) (self.cacheSpaceSlider.value * (float)self.totalSpace);
		}
		//cacheSpaceLabel2.text = [NSString formatFileSize:settingsS.minFreeSpace];
	} else if (self.cachingTypeSegmentedControl.selectedSegmentIndex == 1) {
		
		// Check if the user is trying to assign a larger max cache size than there is available space - 50MB
		if (self.cacheSpaceSlider.value * self.totalSpace > self.freeSpace - 52428800) {
			settingsS.maxCacheSize = self.freeSpace - 52428800;
			self.cacheSpaceSlider.value = ((float)settingsS.maxCacheSize / (float)self.totalSpace); // Leave 50MB space
		} else if (self.cacheSpaceSlider.value * self.totalSpace < 52428800) {
			settingsS.maxCacheSize = 52428800;
			self.cacheSpaceSlider.value = ((float)settingsS.maxCacheSize / (float)self.totalSpace); // Leave 50MB space
		} else {
			settingsS.maxCacheSize = (unsigned long long int) (self.cacheSpaceSlider.value * self.totalSpace);
		}
		//cacheSpaceLabel2.text = [NSString formatFileSize:settingsS.maxCacheSize];
	}
	[self updateMinFreeSpaceLabel];
}

- (IBAction)revertMinFreeSpaceSlider {
	self.cacheSpaceLabel2.text = [NSString formatFileSize:settingsS.minFreeSpace];
	self.cacheSpaceSlider.value = (float)settingsS.minFreeSpace / self.totalSpace;
}

- (IBAction)updateScrobblePercentLabel {
	NSUInteger percentInt = self.scrobblePercentSlider.value * 100;
	self.scrobblePercentLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)percentInt];
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
//DLog(@"file size: %llu   formatted: %@", [textField.text fileSizeFromFormat], [NSString formatFileSize:[textField.text fileSizeFromFormat]]);
}

@end
