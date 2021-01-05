//
//  CacheSingleton.m
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "CacheSingleton.h"
#import "FMDatabaseQueueAdditions.h"
#import "ISMSStreamManager.h"
#import "ISMSCacheQueueManager.h"
#import "SavedSettings.h"
#import "DatabaseSingleton.h"
#import "ISMSStreamManager.h"
#import "ISMSCacheQueueManager.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"

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

- (void)startCacheCheckTimerWithInterval:(NSTimeInterval)interval {
	self.cacheCheckInterval = interval;
	[self stopCacheCheckTimer];
	[self checkCache];
}

- (void)stopCacheCheckTimer {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkCache) object:nil];
}

- (NSUInteger)numberOfCachedSongs {
	return [databaseS.offlineSongsDbQueue intForQuery:@"SELECT COUNT(*) FROM offlineSongs WHERE finished = 1"];
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
                NSString *orderByField = settingsS.autoDeleteCacheType == 0 ? @"playedDate" : @"cachedDate";
                __block NSString *urlStringFilesystemSafe = nil;
                __block NSString *songId = nil;
                [databaseS.offlineSongsDbQueue inDatabase:^(FMDatabase *db) {
                    NSString *query = [NSString stringWithFormat:@"SELECT urlStringFilesystemSafe, songId FROM offlineSong WHERE finished = 1 ORDER BY %@ ASC LIMIT 1", orderByField];
                    FMResultSet *result = [db executeQuery:query];
                    if ([result next]) {
                        urlStringFilesystemSafe = [result stringForColumn:@"urlStringFilesystemSafe"];
                        songId = [result stringForColumn:@"songId"];
                    }
                }];
                
                if (urlStringFilesystemSafe && songId) {
                    DDLogInfo(@"[CacheSingleton] removeOldestCachedSongs: min space removing songId %@", songId);
                    [ISMSSong removeFromOfflineSongsWithUrlStringFilesystemSafe:urlStringFilesystemSafe songId:songId];
                }
			}
		}
	} else if (settingsS.cachingType == ISMSCachingType_maxSize) {
		// Remove the oldest songs based on either oldest played or oldest cached until cache size is less than maxCacheSize
		unsigned long long size = self.cacheSize;
		while (size > settingsS.maxCacheSize) {
			@autoreleasepool  {
                NSString *orderByField = settingsS.autoDeleteCacheType == 0 ? @"playedDate" : @"cachedDate";
                __block NSString *urlStringFilesystemSafe = nil;
                __block NSString *songId = nil;
                [databaseS.offlineSongsDbQueue inDatabase:^(FMDatabase *db) {
                    NSString *query = [NSString stringWithFormat:@"SELECT urlStringFilesystemSafe, songId FROM offlineSong WHERE finished = 1 ORDER BY %@ ASC LIMIT 1", orderByField];
                    FMResultSet *result = [db executeQuery:query];
                    if ([result next]) {
                        urlStringFilesystemSafe = [result stringForColumn:@"urlStringFilesystemSafe"];
                        songId = [result stringForColumn:@"songId"];
                    }
                }];
                ISMSSong *song = [ISMSSong downloadedSongWithUrlStringFilesystemSafe:urlStringFilesystemSafe songId:songId];
                NSString *songPath = [settingsS.songCachePath stringByAppendingPathComponent:song.path];
				unsigned long long songSize = [[NSFileManager.defaultManager attributesOfItemAtPath:songPath error:NULL] fileSize];
                
                DDLogInfo(@"[CacheSingleton] removeOldestCachedSongs: max size removing %@", song);
                [ISMSSong removeFromOfflineSongsWithUrlStringFilesystemSafe:urlStringFilesystemSafe songId:songId];
				size -= songSize;
			}
		}
	}
	
	[self findCacheSize];
	
    if (!cacheQueueManagerS.isQueueDownloading) {
		[cacheQueueManagerS startDownloadQueue];
    }
}

- (void)findCacheSize {
    [databaseS.offlineSongsDbQueue inDatabase:^(FMDatabase *db) {
        unsigned long long size = [[db stringForQuery:@"SELECT sum(size) FROM offlineSong"] longLongValue];
        FMResultSet *result = [db executeQuery:@"SELECT md5 FROM cachedSongs WHERE finished = 'NO'"];
        while ([result next]) {
            NSString *path = [settingsS.songCachePath stringByAppendingPathComponent:[result stringForColumn:@"md5"]];
            NSDictionary *attr = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
            size += [attr fileSize];
        }
        
        DDLogVerbose(@"[CacheSingleton] Total cache size was found to be: %llu", size);
        self->_cacheSize = size;
    }];
//	unsigned long long size = 0;
//	NSFileManager *fileManager = NSFileManager.defaultManager;
//	NSArray *subpaths = [fileManager subpathsAtPath:settingsS.songCachePath];
//	for (NSString *path in subpaths) 
//	{
//		NSString *fullPath = [settingsS.songCachePath stringByAppendingPathComponent:path];
//		NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:NULL];
//		size += [attributes fileSize];
//	}
//	
//	_cacheSize = size;
	
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
	NSFileManager *defaultManager = NSFileManager.defaultManager;
        
	// Make sure songCache directory exists, if not create it
	if (![defaultManager fileExistsAtPath:settingsS.songCachePath]) {
        // First check to see if it's in the old Library/Caches location
        NSString *oldPath = [settingsS.cachesPath stringByAppendingPathComponent:@"songCache"];
        if ([defaultManager fileExistsAtPath:oldPath]) {
            // It exists there, so move it to the new location
            NSError *error;
            [defaultManager moveItemAtPath:oldPath toPath:settingsS.songCachePath error:&error];
            if (error) {
                DDLogError(@"[CacheSingleton] Error moving cache path from %@ to %@", oldPath, settingsS.songCachePath);
            } else {
                DDLogInfo(@"[CacheSingleton] Moved cache path from %@ to %@", oldPath, settingsS.songCachePath);
                
                // Now set all of the files to not be backed up
                if (!settingsS.isBackupCacheEnabled) {
                    NSArray *cachedSongNames = [defaultManager contentsOfDirectoryAtPath:settingsS.songCachePath error:nil];
                    for (NSString *songName in cachedSongNames) {
                        NSURL *fileUrl = [NSURL fileURLWithPath:[settingsS.songCachePath stringByAppendingPathComponent:songName]];
                        [fileUrl addSkipBackupAttribute];
                    }
                }
            }
        } else {
            // It doesn't exist in the old location, so just create it in the new one
            [defaultManager createDirectoryAtPath:settingsS.songCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
        }
	}
    
    // Rename any cache files that still have extensions
    NSDirectoryEnumerator *direnum = [NSFileManager.defaultManager enumeratorAtPath:settingsS.songCachePath];
    NSString *filename;
    while ((filename = direnum.nextObject)) {
        // Check if it contains an extension
        NSRange range = [filename rangeOfString:@"."];
        if (range.location != NSNotFound) {
            NSString *filenameNew = [[filename componentsSeparatedByString:@"."] firstObject];
            DDLogInfo(@"[CacheSingleton] Moving filename: %@ to new filename: %@", filename, filenameNew);
            if (filenameNew) {
                NSString *fromPath = [settingsS.songCachePath stringByAppendingPathComponent:filename];
                NSString *toPath = [settingsS.songCachePath stringByAppendingPathComponent:filenameNew];
                NSError *error;
                if (![NSFileManager.defaultManager moveItemAtPath:fromPath toPath:toPath error:&error]) {
                    DDLogError(@"[CacheSingleton] ERROR Moving filename: %@ to new filename: %@", filename, filenameNew);
                }
            }
        }
    }
    
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
		[sharedInstance setup];
	});
    return sharedInstance;
}

+ (void) setAllCachedSongsToBackup {
    // Now set all of the files to be backed up
    NSArray *cachedSongNames = [NSFileManager.defaultManager contentsOfDirectoryAtPath:settingsS.songCachePath error:nil];
    for (NSString *songName in cachedSongNames)
    {
        NSURL *fileUrl = [NSURL fileURLWithPath:[settingsS.songCachePath stringByAppendingPathComponent:songName]];
        [fileUrl removeSkipBackupAttribute];
    }
}

+ (void) setAllCachedSongsToNotBackup {
    // Now set all of the files to be backed up
    NSArray *cachedSongNames = [NSFileManager.defaultManager contentsOfDirectoryAtPath:settingsS.songCachePath error:nil];
    for (NSString *songName in cachedSongNames)
    {
        NSURL *fileUrl = [NSURL fileURLWithPath:[settingsS.songCachePath stringByAppendingPathComponent:songName]];
        
        [fileUrl addSkipBackupAttribute];
    }
}

@end
