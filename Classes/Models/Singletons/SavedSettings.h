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
#import "PlaylistSingleton.h"
#import "Defines.h"

#define settingsS ((SavedSettings *)[SavedSettings sharedInstance])

typedef enum 
{
	ISMSCachingType_minSpace = 0,
	ISMSCachingType_maxSize = 1
} ISMSCachingType;

@class AudioEngine;
@interface SavedSettings : NSObject 
{    
	__strong NSUserDefaults *_userDefaults;
	
	__strong NSMutableArray *_serverList;
	__strong NSString *_serverType;
	__strong NSString *_urlString;
	__strong NSString *_username;
	__strong NSString *_password;
    __strong NSString *_uuid;
    __strong NSString *_lastQueryId;
    __strong NSString *_sessionId;
	
	BOOL _isPopupsEnabled;
	BOOL _isJukeboxEnabled;
	BOOL _isScreenSleepEnabled;
	float _gainMultiplier;
	BOOL _isPartialCacheNextSong;
	BOOL _isExtraPlayerControlsShowing;
	BOOL _isPlayerPlaylistShowing;
	NSUInteger _quickSkipNumberOfSeconds;
	NSUInteger _audioEngineStartNumberOfSeconds;
	NSUInteger _audioEngineBufferNumberOfSeconds;
	BOOL _isShowLargeSongInfoInPlayer;
	BOOL _isLockScreenArtEnabled;
	BOOL _isEqualizerOn;
	
	// State Saving
	BOOL _isPlaying;
	BOOL _isShuffle;
	NSInteger _normalPlaylistIndex;
	NSInteger _shufflePlaylistIndex;
	ISMSRepeatMode _repeatMode;
	NSInteger _bitRate;
	unsigned long long _byteOffset;
	double _secondsOffset;
	BOOL _isRecover;
	NSInteger _recoverSetting;
}

@property BOOL isCancelLoading;
@property BOOL isOfflineMode;

// Server Login Settings
@property (strong) NSMutableArray *serverList;
@property (copy) NSString *serverType;
@property (copy) NSString *urlString;
@property (copy) NSString *username;
@property (copy) NSString *password;
@property (copy) NSString *uuid;
@property (copy) NSString *lastQueryId;
@property (copy) NSString *sessionId;

// Root Folders Settings
@property (strong) NSDate *rootFoldersReloadTime;
@property (strong) NSNumber *rootFoldersSelectedFolderId;

@property BOOL isForceOfflineMode;
@property NSInteger recoverSetting;
@property NSInteger maxBitrateWifi;
@property NSInteger maxBitrate3G;
@property (readonly) NSInteger currentMaxBitrate;
@property NSInteger maxVideoBitrateWifi;
@property NSInteger maxVideoBitrate3G;
@property (readonly) NSArray *currentVideoBitrates;
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
@property BOOL isSongsTabEnabled;
@property BOOL isAutoReloadArtistsEnabled;
@property float scrobblePercent;
@property BOOL isScrobbleEnabled;
@property BOOL isRotationLockEnabled;
@property BOOL isJukeboxEnabled;
@property BOOL isScreenSleepEnabled;
@property BOOL isPopupsEnabled;
@property BOOL isUpdateCheckEnabled;
@property BOOL isUpdateCheckQuestionAsked;
@property BOOL isNewSearchAPI;
@property BOOL isVideoSupported;
@property (readonly) BOOL isTestServer;
@property BOOL isBasicAuthEnabled;
@property BOOL isTapAndHoldEnabled;
@property BOOL isSwipeEnabled;
@property float gainMultiplier;
@property BOOL isPartialCacheNextSong;
@property ISMSBassVisualType currentVisualizerType;
@property NSUInteger quickSkipNumberOfSeconds;

@property BOOL isExtraPlayerControlsShowing;
@property BOOL isPlayerPlaylistShowing;

@property BOOL isShouldShowEQViewInstructions;

@property BOOL isShowLargeSongInfoInPlayer;

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
- (NSString *)databasePath;
- (NSString *)cachesPath;
- (NSString *)songCachePath;
- (NSString *)tempCachePath;

/*- (BOOL)isSelectedIndexForBassEffectADefault:(BassEffectType)type;
- (NSUInteger)selectedIndexForBassEffect:(BassEffectType)type;
- (void)selectedIndexForBassEffect:(BassEffectType)type index:(NSUInteger)index isDefault:(BOOL)isDefault;*/

//- (NSString *)formatFileSize:(unsigned long long int)size;

- (void)setupSaveState;
- (void)loadState;
- (void)saveState;

+ (instancetype)sharedInstance;

@end

#endif
