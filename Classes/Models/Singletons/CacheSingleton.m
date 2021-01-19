//
//  CacheSingleton.m
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "CacheSingleton.h"
#import "ISMSStreamManager.h"
#import "ISMSCacheQueueManager.h"
#import "SavedSettings.h"
#import "ISMSStreamManager.h"
#import "ISMSCacheQueueManager.h"
#import "EX2Kit.h"
#import "Swift.h"

LOG_LEVEL_ISUB_DEFAULT

@implementation CacheSingleton

- (unsigned long long)totalSpace {
	NSDictionary *attributes = [NSFileManager.defaultManager attributesOfFileSystemForPath:settingsS.songCachePath error:NULL];
    return [attributes[NSFileSystemSize] unsignedLongLongValue];
}

- (unsigned long long)freeSpace {
	NSString *path = settingsS.cachesPath;
	NSDictionary *attributes = [NSFileManager.defaultManager attributesOfFileSystemForPath:path error:NULL];
	return [attributes[NSFileSystemFreeSize] unsignedLongLongValue];
}

// TODO: Run this in background thread
- (void)startCacheCheckTimerWithInterval:(NSTimeInterval)interval {
	self.cacheCheckInterval = interval;
	[self stopCacheCheckTimer];
	[self checkCache];
}

- (void)stopCacheCheckTimer {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkCache) object:nil];
}

- (NSUInteger)numberOfCachedSongs {
    return [Store.shared downloadedSongsCount];
}

// If the available space has dropped below the max cache size since last app load, adjust it.
- (void)adjustCacheSize {
	// Only adjust if the user is using max cache size as option
	if (settingsS.cachingType == ISMSCachingType_maxSize) {
		unsigned long long possibleSize = self.freeSpace + self.cacheSize;
		unsigned long long maxCacheSize = settingsS.maxCacheSize;
		DDLogInfo(@"[CacheSingleton] adjustCacheSize:  possibleSize = %llu  maxCacheSize = %llu", possibleSize, maxCacheSize);
		if (possibleSize < maxCacheSize) {
			// Set the max cache size to 25MB less than the free space
			settingsS.maxCacheSize = possibleSize - (25 * 1024 * 1024);
		}
	}
}

- (void)removeOldestCachedSongs {
	if (settingsS.cachingType == ISMSCachingType_minSpace) {
		// Remove the oldest songs based on either oldest played or oldest cached until free space is more than minFreeSpace
		while (self.freeSpace < settingsS.minFreeSpace) {
			@autoreleasepool {
                DownloadedSong *downloadedSong = nil;
                if (settingsS.autoDeleteCacheType == 0) {
                    downloadedSong = [Store.shared oldestDownloadedSongByPlayedDate];
                } else {
                    downloadedSong = [Store.shared oldestDownloadedSongByCachedDate];
                }
                DDLogInfo(@"[CacheSingleton] removeOldestCachedSongs: min space removing %@", downloadedSong);
                if (downloadedSong) {
                    (void)[Store.shared deleteWithDownloadedSong:downloadedSong];
                }
			}
		}
	} else if (settingsS.cachingType == ISMSCachingType_maxSize) {
		// Remove the oldest songs based on either oldest played or oldest cached until cache size is less than maxCacheSize
		unsigned long long size = self.cacheSize;
		while (size > settingsS.maxCacheSize) {
			@autoreleasepool  {
                DownloadedSong *downloadedSong = nil;
				if (settingsS.autoDeleteCacheType == 0) {
                    downloadedSong = [Store.shared oldestDownloadedSongByPlayedDate];
				} else {
                    downloadedSong = [Store.shared oldestDownloadedSongByCachedDate];
				}
                
                ISMSSong *song = [Store.shared songWithServerId:downloadedSong.serverId songId:downloadedSong.songId];
				unsigned long long songSize = [[NSFileManager.defaultManager attributesOfItemAtPath:song.localPath error:NULL] fileSize];

                DDLogInfo(@"[CacheSingleton] removeOldestCachedSongs: max size removing %@", song);
                if ([Store.shared deleteWithDownloadedSong:downloadedSong]) {
                    size -= songSize;
                }
			}
		}
	}

	[self findCacheSize];

    if (!cacheQueueManagerS.isQueueDownloading) {
		[cacheQueueManagerS startDownloadQueue];
    }
}

- (void)findCacheSize {
    NSDirectoryEnumerator *directoryEnumerator = [NSFileManager.defaultManager enumeratorAtURL:FileSystem.downloadsDirectory
                                                                    includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                                       options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                  errorHandler:nil];
    unsigned long long size = 0;
    for (NSURL *url in directoryEnumerator) {
        NSNumber *isDirectory = nil;
        [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        if (!isDirectory.boolValue) {
            size += [[NSFileManager.defaultManager attributesOfItemAtPath:url.path error:nil] fileSize];
        }
    }
        
    DDLogVerbose(@"[CacheSingleton] Total cache size was found to be: %llu", size);
	_cacheSize = size;
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CacheSizeChecked];
}

- (void)checkCache {
	[self findCacheSize];
	
	// Adjust the cache size if needed
	[self adjustCacheSize];
	
	if (settingsS.cachingType == ISMSCachingType_minSpace && settingsS.isSongCachingEnabled) {
		// Check to see if the free space left is lower than the setting
		if (self.freeSpace < settingsS.minFreeSpace) {
			// Check to see if the cache size + free space is still less than minFreeSpace
			unsigned long long size = self.cacheSize;
			if (size + self.freeSpace < settingsS.minFreeSpace) {
				// Looks like even removing all of the cache will not be enough so turn off caching
				settingsS.isSongCachingEnabled = NO;
                
                NSString *message = @"Free space is running low, but even deleting the entire cache will not bring the free space up higher than your minimum setting. Automatic song caching has been turned off.\n\nYou can re-enable it in the Settings menu (tap the gear, tap Settings at the top)";
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IMPORTANT"
                                                                               message:message
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                [UIApplication.keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
			} else {
				// Remove the oldest cached songs until freeSpace > minFreeSpace or pop the free space low alert
				if (settingsS.isAutoDeleteCacheEnabled) {
					[self removeOldestCachedSongs];
				} else {
                    NSString *message = @"Free space is running low. Delete some cached songs or lower the minimum free space setting.";
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Notice"
                                                                                   message:message
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                    [UIApplication.keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
				}
			}
		}
	} else if (settingsS.cachingType == ISMSCachingType_maxSize && settingsS.isSongCachingEnabled) {
		// Check to see if the cache size is higher than the max
		if (self.cacheSize > settingsS.maxCacheSize) {
			if (settingsS.isAutoDeleteCacheEnabled) {
                [self removeOldestCachedSongs];
			} else {
				settingsS.isSongCachingEnabled = NO;
                NSString *message = @"The song cache is full. Automatic song caching has been disabled.\n\nYou can re-enable it in the Settings menu (tap the gear on the Home tab, tap Settings at the top)";
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Notice"
                                                                               message:message
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                [UIApplication.keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
			}			
		}
	}
	
	[self stopCacheCheckTimer];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkCache) object:nil];
	[self performSelector:@selector(checkCache) withObject:nil afterDelay:self.cacheCheckInterval];
}

- (void)clearTempCache {
	// Clear the temp cache directory
	[NSFileManager.defaultManager removeItemAtPath:settingsS.tempCachePath error:NULL];
	[NSFileManager.defaultManager createDirectoryAtPath:settingsS.tempCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
	streamManagerS.lastTempCachedSong = nil;
}

#pragma mark Singleton methods
			
- (void)setup {
    // TODO: implement this
    // TODO: Move old cached songs to new location
    
    // Clear the temp cache
    [self clearTempCache];

	// Setup the cache check interval
	_cacheCheckInterval = 60.0;
	
	// Do the first check sooner
	[self performSelector:@selector(checkCache) withObject:nil afterDelay:0.05];
}

+ (instancetype)sharedInstance {
    static CacheSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
	});
    return sharedInstance;
}

+ (void)setAllCachedSongsToBackup {
    [FileSystem.downloadsDirectory removeSkipBackupAttribute];
}

+ (void)setAllCachedSongsToNotBackup {
    // TODO: Handle clearing cached songs DB after iCloud restore
    // TODO: implement this
    [FileSystem.downloadsDirectory addSkipBackupAttribute];
}

@end
