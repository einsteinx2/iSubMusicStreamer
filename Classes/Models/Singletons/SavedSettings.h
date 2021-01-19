//
//  SavedSettings.h
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#ifndef iSub_SavedSettings_h
#define iSub_SavedSettings_h

#import "BassEffectDAO.h"
#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import "Defines.h"
#import "ISMSBassVisualType.h"

#define settingsS ((SavedSettings *)[SavedSettings sharedInstance])

typedef enum 
{
	ISMSCachingType_minSpace = 0,
	ISMSCachingType_maxSize = 1
} ISMSCachingType;

NS_ASSUME_NONNULL_BEGIN

@class AudioEngine, Server;
NS_SWIFT_NAME(Settings)
@interface SavedSettings : NSObject 

@property BOOL isCancelLoading;
@property BOOL isOfflineMode;

@property (readonly) BOOL showPlayerIcon;

@property (readonly) NSInteger currentServerId;
//@property (readonly) BOOL currentServerIsVideoSupported;
//@property (readonly) BOOL currentServerIsNewSearchSupported;
@property (nullable, strong) Server *currentServer;

// Root Folders Settings
@property (nullable, strong) NSDate *rootFoldersReloadTime;
@property (nullable, strong) NSNumber *rootFoldersSelectedFolderId;

// Root Artists Settings
@property (nullable, strong) NSNumber *rootArtistsSelectedFolderId;

// Check if app crashed on last run (read any time during app session)
@property BOOL appCrashedOnLastRun;

@property BOOL appTerminatedCleanly; // NO on launch if app crashed, only read on app launch
@property BOOL isForceOfflineMode;
@property NSInteger recoverSetting;
@property NSInteger maxBitrateWifi;
@property NSInteger maxBitrate3G;
@property (readonly) NSInteger currentMaxBitrate;
@property NSInteger maxVideoBitrateWifi;
@property NSInteger maxVideoBitrate3G;
@property (readonly) NSArray<NSNumber*> *currentVideoBitrates;
@property BOOL isSongCachingEnabled;
@property BOOL isNextSongCacheEnabled;
@property BOOL isBackupCacheEnabled;
@property BOOL isManualCachingOnWWANEnabled;
@property NSInteger cachingType;
@property unsigned long long maxCacheSize;
@property unsigned long long minFreeSpace;
@property BOOL isAutoDeleteCacheEnabled;
@property NSInteger autoDeleteCacheType;
@property NSInteger cachedSongCellColorType;
@property BOOL isAutoReloadArtistsEnabled;
@property float scrobblePercent;
@property BOOL isScrobbleEnabled;
@property BOOL isRotationLockEnabled;
@property BOOL isJukeboxEnabled;
@property BOOL isScreenSleepEnabled;
@property BOOL isPopupsEnabled;
@property BOOL isUpdateCheckEnabled;
@property BOOL isUpdateCheckQuestionAsked;
@property BOOL isBasicAuthEnabled;
@property BOOL isTapAndHoldEnabled;
@property BOOL isSwipeEnabled;
@property float gainMultiplier;
@property BOOL isPartialCacheNextSong;
@property ISMSBassVisualType currentVisualizerType;
@property NSUInteger quickSkipNumberOfSeconds;
@property BOOL isShouldShowEQViewInstructions;
@property BOOL isLockScreenArtEnabled;
@property BOOL isEqualizerOn;
@property NSUInteger oneTimeRunIncrementor;
@property BOOL isDisableUsageOver3G;
@property BOOL isCacheSizeTableFinished;

// State Saving
@property BOOL isRecover;
@property double seekTime;
@property unsigned long long byteOffset;
@property NSInteger bitRate;

// Document Paths
- (NSString *)documentsPath;
- (NSString *)applicationSupportPath;
- (NSString *)databasePath;
- (NSString *)updatedDatabasePath;
- (NSString *)cachesPath;
- (NSString *)songCachePath;
- (NSString *)tempCachePath;

//- (void)setupSaveState;
- (void)loadState;
- (void)saveState;

//- (void)oneTimeRun;

// Log all app settings except for some unnecessary or sensitive information such as the username, password, and server URL
- (void)logAppSettings;

- (NSString *)latestLogFileName;
- (NSString *)zipAllLogFiles;

- (void)setup;

+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());

@end

NS_ASSUME_NONNULL_END

#endif
