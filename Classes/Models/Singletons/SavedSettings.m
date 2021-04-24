//
//  SavedSettings.m
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SavedSettings.h"
#import "ISMSServer.h"
#import "Defines.h"
#import "Swift.h"
#import "ZipKit.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

LOG_LEVEL_ISUB_DEFAULT

@interface SavedSettings() {
    NSUserDefaults *_userDefaults;
    
    // State Saving
    BOOL _isPlaying;
    BOOL _isShuffle;
    NSInteger _normalPlaylistIndex;
    NSInteger _shufflePlaylistIndex;
    RepeatMode _repeatMode;
    NSInteger _kiloBitrate;
    NSInteger _byteOffset;
    double _secondsOffset;
    BOOL _isRecover;
    NSInteger _recoverSetting;
    Server *_currentServer;
}
@end

@implementation SavedSettings

- (void)loadState {
    BassPlayer *player = BassPlayer.shared;
    PlayQueue *playQueue = PlayQueue.shared;
    
    if (self.isJukeboxEnabled) {
		_isPlaying = NO;
    } else {
		_isPlaying = [_userDefaults boolForKey:@"isPlaying"];
    }
    
	_isShuffle = [_userDefaults boolForKey:@"isShuffle"];
    playQueue.isShuffle = _isShuffle;
	
	_normalPlaylistIndex = [_userDefaults integerForKey:@"normalPlaylistIndex"];
    playQueue.normalIndex = _normalPlaylistIndex;
	
	_shufflePlaylistIndex = [_userDefaults integerForKey:@"shufflePlaylistIndex"];
    playQueue.shuffleIndex = _shufflePlaylistIndex;
    
	_repeatMode = (RepeatMode)[_userDefaults integerForKey:@"repeatMode"];
    playQueue.repeatMode = _repeatMode;
	
	_kiloBitrate = [_userDefaults integerForKey:@"kiloBitrate"];
	_byteOffset = self.byteOffset;
	_secondsOffset = self.seekTime;
	_isRecover = self.isRecover;
	_recoverSetting = self.recoverSetting;
	
    player.startByteOffset = _byteOffset;
    player.startSecondsOffset = _secondsOffset;
}

- (void)setupSaveState
{	
	// Load saved state first
	[self loadState];
	
	// Start the timer
	[NSTimer scheduledTimerWithTimeInterval:3.3 target:self selector:@selector(saveState) userInfo:nil repeats:YES];
}

- (void)saveState {
	@autoreleasepool {
        BassPlayer *player = BassPlayer.shared;
        PlayQueue *playQueue = PlayQueue.shared;
		
        BOOL isDefaultsDirty = NO;

		if (player.isPlaying != _isPlaying) {
            if (self.isJukeboxEnabled) {
				_isPlaying = NO;
            } else {
				_isPlaying = player.isPlaying;
            }
            
			[_userDefaults setBool:_isPlaying forKey:@"isPlaying"];
			isDefaultsDirty = YES;
		}
		
		if (playQueue.isShuffle != _isShuffle) {
			_isShuffle = playQueue.isShuffle;
			[_userDefaults setBool:_isShuffle forKey:@"isShuffle"];
			isDefaultsDirty = YES;
		}
		
		if (playQueue.normalIndex != _normalPlaylistIndex) {
			_normalPlaylistIndex = playQueue.normalIndex;
			[_userDefaults setInteger:_normalPlaylistIndex forKey:@"normalPlaylistIndex"];
			isDefaultsDirty = YES;
		}
		
		if (playQueue.shuffleIndex != _shufflePlaylistIndex) {
			_shufflePlaylistIndex = playQueue.shuffleIndex;
			[_userDefaults setInteger:_shufflePlaylistIndex forKey:@"shufflePlaylistIndex"];
			isDefaultsDirty = YES;
		}
		
		if (playQueue.repeatMode != _repeatMode) {
			_repeatMode = playQueue.repeatMode;
			[_userDefaults setInteger:_repeatMode forKey:@"repeatMode"];
			isDefaultsDirty = YES;
		}
		
		if (player.kiloBitrate != _kiloBitrate && player.kiloBitrate >= 0) {
			_kiloBitrate = player.kiloBitrate;
			[_userDefaults setInteger:_kiloBitrate forKey:@"kiloBitrate"];
			isDefaultsDirty = YES;
		}
		
		if (_secondsOffset != player.progress) {
			_secondsOffset = player.progress;
			[_userDefaults setDouble:_secondsOffset forKey:@"seekTime"];
			isDefaultsDirty = YES;
		}
		
		if (_byteOffset != player.currentByteOffset) {
			_byteOffset = player.currentByteOffset;
			[_userDefaults setObject:@(_byteOffset) forKey:@"byteOffset"];
			isDefaultsDirty = YES;
		}
				
		BOOL newIsRecover = NO;
		if (_isPlaying) {
            newIsRecover = (_recoverSetting == 0);
		} else {
			newIsRecover = NO;
		}
		
		if (_isRecover != newIsRecover) {
			_isRecover = newIsRecover;
			[_userDefaults setBool:_isRecover forKey:@"recover"];
			isDefaultsDirty = YES;
		}
		
		// Only synchronize to disk if necessary
        if (isDefaultsDirty) {
            [_userDefaults synchronize];
        }
	}	
}

#pragma mark - Settings Setup

- (void)createInitialSettings {
	if (![_userDefaults boolForKey:@"areSettingsSetup"]) {
		[_userDefaults setBool:YES forKey:@"areSettingsSetup"];
		[_userDefaults setBool:NO forKey:@"manualOfflineModeSetting"];
		[_userDefaults setInteger:0 forKey:@"recoverSetting"];
		[_userDefaults setInteger:7 forKey:@"maxBitrateWifiSetting"];
		[_userDefaults setInteger:7 forKey:@"maxBitrate3GSetting"];
		[_userDefaults setBool:YES forKey:@"enableSongCachingSetting"];
		[_userDefaults setBool:YES forKey:@"enableNextSongCacheSetting"];
		[_userDefaults setInteger:0 forKey:@"cachingTypeSetting"];
		[_userDefaults setObject:@(1073741824) forKey:@"maxCacheSize"];
		[_userDefaults setObject:@(268435456) forKey:@"minFreeSpace"];
		[_userDefaults setBool:YES forKey:@"autoDeleteCacheSetting"];
		[_userDefaults setInteger:0 forKey:@"autoDeleteCacheTypeSetting"];
		[_userDefaults setInteger:3 forKey:@"cacheSongCellColorSetting"];
		[_userDefaults setBool:NO forKey:@"lyricsEnabledSetting"];
		[_userDefaults setBool:NO forKey:@"enableSongsTabSetting"];
		[_userDefaults setBool:NO forKey:@"autoPlayerInfoSetting"];
		[_userDefaults setBool:NO forKey:@"autoReloadArtistsSetting"];
		[_userDefaults setFloat:0.5 forKey:@"scrobblePercentSetting"];
		[_userDefaults setBool:NO forKey:@"enableScrobblingSetting"];
		[_userDefaults setBool:NO forKey:@"disablePopupsSetting"];
		[_userDefaults setBool:NO forKey:@"lockRotationSetting"];
		[_userDefaults setBool:NO forKey:@"isJukeboxEnabled"];
		[_userDefaults setBool:YES forKey:@"isScreenSleepEnabled"];
		[_userDefaults setBool:YES forKey:@"isPopupsEnabled"];
		[_userDefaults setBool:NO forKey:@"checkUpdatesSetting"];
		[_userDefaults setBool:NO forKey:@"isUpdateCheckQuestionAsked"];
		[_userDefaults setBool:NO forKey:@"isBasicAuthEnabled"];
		[_userDefaults setBool:YES forKey:@"checkUpdatesSetting"];
	}
	
	// New settings 3.0.5 beta 18
	if (![_userDefaults objectForKey:@"gainMultiplier"]) {
		[_userDefaults setBool:YES forKey:@"isTapAndHoldEnabled"];
		[_userDefaults setBool:YES forKey:@"isSwipeEnabled"];
		[_userDefaults setFloat:1.0 forKey:@"gainMultiplier"];
	}
	
	// Removal of 3rd recovery type option
	if (self.recoverSetting == 2) {
		// "Never" option removed, change to "Paused" option if set
		self.recoverSetting = 1;
	}
	
	// Visualizer Type
	if (![_userDefaults objectForKey:@"currentVisualizerType"]) {
		self.currentVisualizerType = ISMSBassVisualType_none;
	}
	
	// Quick Skip
	if (![_userDefaults objectForKey:@"quickSkipNumberOfSeconds"]) {
		self.quickSkipNumberOfSeconds = 30;
	}
	
	if (![_userDefaults objectForKey:@"isShouldShowEQViewInstructions"]) {
		self.isShouldShowEQViewInstructions = YES;
	}
	
	if (![_userDefaults objectForKey:@"isLockScreenArtEnabled"]) {
		self.isLockScreenArtEnabled = YES;
	}
    
    if (![_userDefaults objectForKey:@"maxVideoBitrateWifi"]) {
        self.maxVideoBitrateWifi = 5;
        self.maxVideoBitrate3G = 5;
    }
	
	[_userDefaults synchronize];
}

- (BOOL)showPlayerIcon {
    return !UIDevice.isPad;
}

#pragma mark - Login Settings

- (NSInteger)currentServerId {
    return _currentServer != nil ? _currentServer.serverId : -1;
}

- (Server *)currentServer {
    return _currentServer;
}

- (void)setCurrentServer:(Server *)currentServer {
    _currentServerRedirectUrlString = nil;
    _currentServer = currentServer;
    [_userDefaults setInteger:currentServer.serverId forKey:@"currentServerId"];
    [_userDefaults synchronize];
}

#pragma mark - Document Folder Paths

- (void)createDirectoryIfNotExists:(NSString *)path {
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
        NSError *error = nil;
        [NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            DDLogError(@"[SavedSettings] Failed to create path %@, %@", path, error.localizedDescription);
        }
    }
}

- (NSString *)documentsPath {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
}

- (NSString *)applicationSupportPath {
    NSString *path = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"iSub"];
    [self createDirectoryIfNotExists:path];
    return path;
}

- (NSString *)databasePath {
	NSString *path = [self.documentsPath stringByAppendingPathComponent:@"database"];
    [self createDirectoryIfNotExists:path];
    return path;
}

- (NSString *)updatedDatabasePath {
    NSString *path = [self.applicationSupportPath stringByAppendingPathComponent:@"database"];
    [self createDirectoryIfNotExists:path];
    return path;
}

- (NSString *)cachesPath {
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
}

- (NSString *)songCachePath {
	NSString *path = [self.documentsPath stringByAppendingPathComponent:@"songCache"];
    [self createDirectoryIfNotExists:path];
    return path;
}

- (NSString *)tempCachePath {
	NSString *path = [self.documentsPath stringByAppendingPathComponent:@"tempCache"];
    [self createDirectoryIfNotExists:path];
    return path;
}

#pragma mark - Root Folders Settings

- (NSNumber *)rootFoldersSelectedFolderId {
    NSString *key = [NSString stringWithFormat:@"rootFoldersSelectedFolder%ld", (long)self.currentServer.serverId];
    return [_userDefaults objectForKey:key];
}

- (void)setRootFoldersSelectedFolderId:(NSNumber *)folderId {
    NSString *key = [NSString stringWithFormat:@"rootFoldersSelectedFolder%ld", (long)self.currentServer.serverId];
    [_userDefaults setObject:folderId forKey:key];
    [_userDefaults synchronize];
}

#pragma mark - Root Artists Settings

- (NSNumber *)rootArtistsSelectedFolderId {
    NSString *key = [NSString stringWithFormat:@"rootArtistsSelectedFolder%ld", (long)self.currentServer.serverId];
    return [_userDefaults objectForKey:key];
}

- (void)setRootArtistsSelectedFolderId:(NSNumber *)folderId {
    NSString *key = [NSString stringWithFormat:@"rootArtistsSelectedFolder%ld", (long)self.currentServer.serverId];
    [_userDefaults setObject:folderId forKey:key];
    [_userDefaults synchronize];
}

#pragma mark - Other Settings

- (BOOL)appTerminatedCleanly {
    return [_userDefaults boolForKey:@"appTerminatedCleanly"];
}

- (void)setAppTerminatedCleanly:(BOOL)appTerminatedCleanly {
    [_userDefaults setBool:appTerminatedCleanly forKey:@"appTerminatedCleanly"];
    [_userDefaults synchronize];
}

- (BOOL)isForceOfflineMode {
    return [_userDefaults boolForKey:@"manualOfflineModeSetting"];
}

- (void)setIsForceOfflineMode:(BOOL)isForceOfflineMode {
	[_userDefaults setBool:isForceOfflineMode forKey:@"manualOfflineModeSetting"];
    [_userDefaults synchronize];
}

- (NSInteger)recoverSetting {
    return [_userDefaults integerForKey:@"recoverSetting"];
}

- (void)setRecoverSetting:(NSInteger)setting {
    [_userDefaults setInteger:setting forKey:@"recoverSetting"];
    [_userDefaults synchronize];
}

- (NSInteger)maxBitrateWifi {
    return [_userDefaults integerForKey:@"maxBitrateWifiSetting"];
}

- (void)setMaxBitrateWifi:(NSInteger)maxBitrateWifi {
    [_userDefaults setInteger:maxBitrateWifi forKey:@"maxBitrateWifiSetting"];
    [_userDefaults synchronize];
}

- (NSInteger)maxBitrate3G {
    return [_userDefaults integerForKey:@"maxBitrate3GSetting"];
}

- (void)setMaxBitrate3G:(NSInteger)maxBitrate3G {
    [_userDefaults setInteger:maxBitrate3G forKey:@"maxBitrate3GSetting"];
    [_userDefaults synchronize];
}

- (NSInteger)currentMaxBitrate {
    switch (SceneDelegate.shared.isWifi ? self.maxBitrateWifi : self.maxBitrate3G) {
        case 0: return 64;
        case 1: return 96;
        case 2: return 128;
        case 3: return 160;
        case 4: return 192;
        case 5: return 256;
        case 6: return 320;
        default: return 0;
    }
}

- (NSInteger)maxVideoBitrateWifi {
    return [_userDefaults integerForKey:@"maxVideoBitrateWifi"];
}

- (void)setMaxVideoBitrateWifi:(NSInteger)maxVideoBitrateWifi {
    [_userDefaults setInteger:maxVideoBitrateWifi forKey:@"maxVideoBitrateWifi"];
    [_userDefaults synchronize];
}

- (NSInteger)maxVideoBitrate3G {
    return [_userDefaults integerForKey:@"maxVideoBitrate3G"];
}

- (void)setMaxVideoBitrate3G:(NSInteger)maxVideoBitrate3G {
    [_userDefaults setInteger:maxVideoBitrate3G forKey:@"maxVideoBitrate3G"];
    [_userDefaults synchronize];
}

- (NSArray *)currentVideoBitrates {
    if (SceneDelegate.shared.isWifi) {
        switch (self.maxVideoBitrateWifi) {
            case 0: return @[@512];
            case 1: return @[@1024, @512];
            case 2: return @[@1536, @1024, @512];
            case 3: return @[@2048, @1536, @1024, @512];
            case 4: return @[@4096, @2048, @1536, @1024, @512];
            case 5: return @[@"8192@1920x1080", @4096, @2048, @1536, @1024, @512];
            default: return nil;
        }
    } else {
        switch (self.maxVideoBitrate3G) {
            case 0: return @[@192];
            case 1: return @[@512, @192];
            case 2: return @[@1024, @512, @192];
            case 3: return @[@1536, @1024, @512, @192];
            case 4: return @[@2048, @1536, @1024, @512, @192];
            case 5: return @[@4096, @2048, @1536, @1024, @512, @192];
            default: return nil;
        }
    }
}

- (BOOL)isSongCachingEnabled {
    return [_userDefaults boolForKey:@"enableSongCachingSetting"];
}

- (void)setIsSongCachingEnabled:(BOOL)isSongCachingEnabled {
    [_userDefaults setBool:isSongCachingEnabled forKey:@"enableSongCachingSetting"];
    [_userDefaults synchronize];
}

- (BOOL)isNextSongCacheEnabled {
    return [_userDefaults boolForKey:@"enableNextSongCacheSetting"];
}

- (void)setIsNextSongCacheEnabled:(BOOL)isNextSongCacheEnabled {
    [_userDefaults setBool:isNextSongCacheEnabled forKey:@"enableNextSongCacheSetting"];
    [_userDefaults synchronize];
}

- (BOOL)isBackupCacheEnabled {
    return [_userDefaults boolForKey:@"isBackupCacheEnabled"];
}

- (void)setIsBackupCacheEnabled:(BOOL)isBackupCacheEnabled {
    [_userDefaults setBool:isBackupCacheEnabled forKey:@"isBackupCacheEnabled"];
    [_userDefaults synchronize];
    
    if (isBackupCacheEnabled) {
        //Set all cached songs to removeSkipBackup
        [Cache_ObjCDeleteMe setAllCachedSongsToBackup];
 
    } else {
        // Set all cached songs to removeSkipBackup
        [Cache_ObjCDeleteMe setAllCachedSongsToNotBackup];
    }
}


- (BOOL)isManualCachingOnWWANEnabled {
    return [_userDefaults boolForKey:@"isManualCachingOnWWANEnabled"];
}

- (void)setIsManualCachingOnWWANEnabled:(BOOL)isManualCachingOnWWANEnabled {
    [_userDefaults setBool:isManualCachingOnWWANEnabled forKey:@"isManualCachingOnWWANEnabled"];
    [_userDefaults synchronize];
    
    if (!SceneDelegate.shared.isWifi) {
        isManualCachingOnWWANEnabled ? [CacheQueue_ObjCDeleteMe start] : [CacheQueue_ObjCDeleteMe stop];
    }
}

- (NSInteger)cachingType {
    return [_userDefaults integerForKey:@"cachingTypeSetting"];
}

- (void)setCachingType:(NSInteger)cachingType {
    [_userDefaults setInteger:cachingType forKey:@"cachingTypeSetting"];
    [_userDefaults synchronize];
}

- (NSInteger)maxCacheSize {
    return [_userDefaults integerForKey:@"maxCacheSize"];
}

- (void)setMaxCacheSize:(NSInteger)maxCacheSize {
    [_userDefaults setInteger:maxCacheSize forKey:@"maxCacheSize"];
    [_userDefaults synchronize];
}

- (NSInteger)minFreeSpace {
    return [_userDefaults integerForKey:@"minFreeSpace"];
}

- (void)setMinFreeSpace:(NSInteger)minFreeSpace {
    [_userDefaults setInteger:minFreeSpace forKey:@"minFreeSpace"];
    [_userDefaults synchronize];
}

- (BOOL)isAutoDeleteCacheEnabled {
    return [_userDefaults boolForKey:@"autoDeleteCacheSetting"];
}

- (void)setIsAutoDeleteCacheEnabled:(BOOL)isAutoDeleteCacheEnabled {
    [_userDefaults setBool:isAutoDeleteCacheEnabled forKey:@"autoDeleteCacheSetting"];
    [_userDefaults synchronize];
}

- (NSInteger)autoDeleteCacheType {
    return [_userDefaults integerForKey:@"autoDeleteCacheTypeSetting"];
}

- (void)setAutoDeleteCacheType:(NSInteger)autoDeleteCacheType {
    [_userDefaults setInteger:autoDeleteCacheType forKey:@"autoDeleteCacheTypeSetting"];
    [_userDefaults synchronize];
}

- (NSInteger)cachedSongCellColorType {
    return [_userDefaults integerForKey:@"cacheSongCellColorSetting"];
}

- (void)setCachedSongCellColorType:(NSInteger)cachedSongCellColorType {
    [_userDefaults setInteger:cachedSongCellColorType forKey:@"cacheSongCellColorSetting"];
    [_userDefaults synchronize];
}

- (BOOL)isAutoReloadArtistsEnabled {
    return [_userDefaults boolForKey:@"autoReloadArtistsSetting"];
}

- (void)setIsAutoReloadArtistsEnabled:(BOOL)isAutoReloadArtistsEnabled {
    [_userDefaults setBool:isAutoReloadArtistsEnabled forKey:@"autoReloadArtistsSetting"];
    [_userDefaults synchronize];
}

- (float)scrobblePercent {
    return [_userDefaults floatForKey:@"scrobblePercentSetting"];
}

- (void)setScrobblePercent:(float)scrobblePercent {
    [_userDefaults setFloat:scrobblePercent forKey:@"scrobblePercentSetting"];
    [_userDefaults synchronize];
}

- (BOOL)isScrobbleEnabled {
    return [_userDefaults boolForKey:@"enableScrobblingSetting"];
}

- (void)setIsScrobbleEnabled:(BOOL)isScrobbleEnabled {
    [_userDefaults setBool:isScrobbleEnabled forKey:@"enableScrobblingSetting"];
    [_userDefaults synchronize];
}

- (BOOL)isRotationLockEnabled {
    return [_userDefaults boolForKey:@"lockRotationSetting"];
}

- (void)setIsRotationLockEnabled:(BOOL)isRotationLockEnabled {
    [_userDefaults setBool:isRotationLockEnabled forKey:@"lockRotationSetting"];
    [_userDefaults synchronize];
}

- (BOOL)isJukeboxEnabled {
    return [_userDefaults boolForKey:@"isJukeboxEnabled"];
}

- (void)setIsJukeboxEnabled:(BOOL)enabled {
    [_userDefaults setBool:enabled forKey:@"isJukeboxEnabled"];
    [_userDefaults synchronize];
}

- (BOOL)isScreenSleepEnabled {
    return [_userDefaults boolForKey:@"isScreenSleepEnabled"];
}

- (void)setIsScreenSleepEnabled:(BOOL)enabled {
    [_userDefaults setBool:enabled forKey:@"isScreenSleepEnabled"];
    [_userDefaults synchronize];
}

- (BOOL)isPopupsEnabled {
    return [_userDefaults boolForKey:@"isPopupsEnabled"];
}

- (void)setIsPopupsEnabled:(BOOL)enabled {
    [_userDefaults setBool:enabled forKey:@"isPopupsEnabled"];
    [_userDefaults synchronize];
}

- (BOOL)isUpdateCheckEnabled {
    return [_userDefaults boolForKey:@"checkUpdatesSetting"];
}

- (void)setIsUpdateCheckEnabled:(BOOL)isUpdateCheckEnabled {
    [_userDefaults setBool:isUpdateCheckEnabled forKey:@"checkUpdatesSetting"];
    [_userDefaults synchronize];
}

- (BOOL)isUpdateCheckQuestionAsked {
    return [_userDefaults boolForKey:@"isUpdateCheckQuestionAsked"];
}

- (void)setIsUpdateCheckQuestionAsked:(BOOL)isUpdateCheckQuestionAsked {
    [_userDefaults setBool:isUpdateCheckQuestionAsked forKey:@"isUpdateCheckQuestionAsked"];
    [_userDefaults synchronize];
}

- (BOOL)isRecover {
    return [_userDefaults boolForKey:@"recover"];
}

- (void)setIsRecover:(BOOL)recover {
    [_userDefaults setBool:recover forKey:@"recover"];
    [_userDefaults synchronize];
}

- (double)seekTime {
    return [_userDefaults doubleForKey:@"seekTime"];
}

- (void)setSeekTime:(double)seekTime
{
    [_userDefaults setDouble:seekTime forKey:@"seekTime"];
    [_userDefaults synchronize];
}

- (NSInteger)byteOffset {
    return [_userDefaults integerForKey:@"byteOffset"];
}

- (void)setByteOffset:(NSInteger)byteOffset {
    [_userDefaults setInteger:byteOffset forKey:@"byteOffset"];
    [_userDefaults synchronize];
}

- (NSInteger)bitRate {
    NSInteger rate = [_userDefaults integerForKey:@"bitRate"];
    return rate < 0 ? 128 : rate;
}

- (void)setBitRate:(NSInteger)rate {
    [_userDefaults setInteger:rate forKey:@"bitRate"];
    [_userDefaults synchronize];
}

- (BOOL)isBasicAuthEnabled {
    return [_userDefaults boolForKey:@"isBasicAuthEnabled"];
}

- (void)setIsBasicAuthEnabled:(BOOL)isBasicAuthEnabled {
    [_userDefaults setBool:isBasicAuthEnabled forKey:@"isBasicAuthEnabled"];
    [_userDefaults synchronize];
}

- (BOOL)isTapAndHoldEnabled {
    return [_userDefaults boolForKey:@"isTapAndHoldEnabled"];
}

- (void)setIsTapAndHoldEnabled:(BOOL)isTapAndHoldEnabled {
    [_userDefaults setBool:isTapAndHoldEnabled forKey:@"isTapAndHoldEnabled"];
    [_userDefaults synchronize];
}

- (BOOL)isSwipeEnabled {
    return [_userDefaults boolForKey:@"isSwipeEnabled"];
}

- (void)setIsSwipeEnabled:(BOOL)isSwipeEnabled {
    [_userDefaults setBool:isSwipeEnabled forKey:@"isSwipeEnabled"];
    [_userDefaults synchronize];
}

- (float)gainMultiplier {
    return [_userDefaults floatForKey:@"gainMultiplier"];
}

- (void)setGainMultiplier:(float)multiplier {
    [_userDefaults setFloat:multiplier forKey:@"gainMultiplier"];
    [_userDefaults synchronize];
}

- (ISMSBassVisualType)currentVisualizerType {
    return (ISMSBassVisualType)[_userDefaults integerForKey:@"currentVisualizerType"];
}

- (void)setCurrentVisualizerType:(ISMSBassVisualType)currentVisualizerType {
    [_userDefaults setInteger:currentVisualizerType forKey:@"currentVisualizerType"];
    [_userDefaults synchronize];
}

- (NSInteger)quickSkipNumberOfSeconds {
    return [_userDefaults integerForKey:@"quickSkipNumberOfSeconds"];
}

- (void)setQuickSkipNumberOfSeconds:(NSInteger)numSeconds {
    [_userDefaults setInteger:numSeconds forKey:@"quickSkipNumberOfSeconds"];
    [_userDefaults synchronize];
}

- (BOOL)isShouldShowEQViewInstructions {
    return [_userDefaults boolForKey:@"isShouldShowEQViewInstructions"];
}

- (void)setIsShouldShowEQViewInstructions:(BOOL)isShouldShowEQViewInstructions {
    [_userDefaults setBool:isShouldShowEQViewInstructions forKey:@"isShouldShowEQViewInstructions"];
    [_userDefaults synchronize];
}

- (BOOL)isLockScreenArtEnabled {
    return [_userDefaults boolForKey:@"isLockScreenArtEnabled"];
}

- (void)setIsLockScreenArtEnabled:(BOOL)isEnabled {
    [_userDefaults setBool:isEnabled forKey:@"isLockScreenArtEnabled"];
    [_userDefaults synchronize];
}

- (BOOL)isEqualizerOn {
    return [_userDefaults boolForKey:@"isEqualizerOn"];
}

- (void)setIsEqualizerOn:(BOOL)isOn {
    [_userDefaults setBool:isOn forKey:@"isEqualizerOn"];
    [_userDefaults synchronize];
}

- (BOOL)isDisableUsageOver3G {
    return [_userDefaults boolForKey:@"isDisableUsageOver3G"];
}

- (void)setIsDisableUsageOver3G:(BOOL)isDisableUsageOver3G {
    [_userDefaults setBool:isDisableUsageOver3G forKey:@"isDisableUsageOver3G"];
    [_userDefaults synchronize];
}

//- (BOOL)isTestServer {
//	return [self.urlString isEqualToString:DEFAULT_URL];
//}

- (NSInteger)migrateIncrementor {
    return [_userDefaults integerForKey:@"migrateIncrementor"];
}

- (void)setMigrateIncrementor:(NSInteger)migrateIncrementor {
    [_userDefaults setInteger:migrateIncrementor forKey:@"migrateIncrementor"];
    [_userDefaults synchronize];
}

- (BOOL)isCacheSizeTableFinished {
    return [_userDefaults boolForKey:@"isCacheSizeTableFinished"];
}

- (void)setIsCacheSizeTableFinished:(BOOL)isCacheSizeTableFinished {
    [_userDefaults setBool:isCacheSizeTableFinished forKey:@"isCacheSizeTableFinished"];
    [_userDefaults synchronize];
}

- (void)migrate {
    // In the future, when settings migrations are required, check the migrateIncrementor number and perform the necessary migrations in order based on the incrementor number
}

#pragma mark App Logs

- (void)logAppSettings {
    NSArray *keysToSkip = @[@"handlerStack", @"rootFolders", @"password", @"servers", @"url", @"username"];
    NSMutableDictionary *settings = [[[NSUserDefaults standardUserDefaults] dictionaryRepresentation] mutableCopy];
    
    NSMutableArray *keysToDelete = [[NSMutableArray alloc] initWithCapacity:20];
    for (NSString *key in settings.allKeys) {
        for (NSString *keyToSkip in keysToSkip) {
            if ([key containsString:keyToSkip]) {
                [keysToDelete addObject:key];
            }
        }
    }
    [settings removeObjectsForKeys:keysToDelete];
    
    DDLogInfo(@"App Settings:\n%@", settings);
}

- (NSString *)latestLogFileName {
    NSString *logsFolder = [self.cachesPath stringByAppendingPathComponent:@"Logs"];
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
    // Log the app settings, excluding sensitive info
    [settingsS logAppSettings];
    
    // Flush all logs to disk
    [DDLog flushLog];
    
    NSString *zipFileName = @"iSub Logs.zip";
    NSString *zipFilePath = [self.cachesPath stringByAppendingPathComponent:zipFileName];
    NSString *logsFolder = [self.cachesPath stringByAppendingPathComponent:@"Logs"];
    
    // Delete the old zip if exists
    [[NSFileManager defaultManager] removeItemAtPath:zipFilePath error:nil];
    
    // Zip the logs
    ZKFileArchive *archive = [ZKFileArchive archiveWithArchivePath:zipFilePath];
    NSInteger result = [archive deflateDirectory:logsFolder relativeToPath:self.cachesPath usingResourceFork:NO];
    if (result == zkSucceeded) {
        return zipFilePath;
    }
    return nil;
}

#pragma mark - Singleton methods

- (void)setup {
	// Disable screen sleep if necessary
    if (!self.isScreenSleepEnabled) {
		[UIApplication sharedApplication].idleTimerDisabled = YES;
    }
    
    // Store a reference to standard user defaults to save a message pass, surely a pointless optimization lol
	_userDefaults = [NSUserDefaults standardUserDefaults];
	
    // If the settings are not set up, create the defaults
	[self createInitialSettings];
    
    // Run settings migrations
    [self migrate];
    
    NSNumber *currentServerId = [_userDefaults objectForKey:@"currentServerId"];
    if (Store_ObjCDeleteMe.servers.count > 0 && currentServerId) {
        // Load the new server object
        _currentServer = [Store_ObjCDeleteMe serverWithId:[_userDefaults integerForKey:@"currentServerId"]];
    } else {
        // Load the old server objects
        NSData *servers = [_userDefaults objectForKey:@"servers"];
        if (servers) {
            // Previous selected server info
            NSString *urlString = [_userDefaults stringForKey:@"url"];
            NSString *username = [_userDefaults stringForKey:@"username"];
            
            NSSet *classes = [NSSet setWithArray:@[NSArray.class, ISMSServer.class]];
            NSArray *serverList = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:servers error:nil];
            for (ISMSServer *oldServer in serverList) {
                Server *server = [[Server alloc] initWithId:Store_ObjCDeleteMe.nextServerId type:ServerTypeSubsonic url:[NSURL URLWithString:oldServer.url] username:oldServer.username password:oldServer.password];
                (void)[Store_ObjCDeleteMe addWithServer:server];
                if ([oldServer.url isEqual:urlString] && [oldServer.username isEqual:username]) {
                    self.currentServer = server;
                }
            }
            // TODO: Delete the following user defaults keys: servers, url, username, serverType, password, uuid, lastQueryId
        }
    }
    
    // Start saving state
    [self setupSaveState];
}

+ (instancetype)sharedInstance {
    static SavedSettings *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
//		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
