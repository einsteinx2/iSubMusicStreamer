//
//  SUSSubFolderLoader.m
//  iSub
//
//  Created by Benjamin Baron on 11/6/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSSubFolderLoader.h"

@implementation ISMSSubFolderLoader

- (ISMSLoaderType)type
{
    return ISMSLoaderType_SubFolders;
}

+ (id)loaderWithDelegate:(NSObject<ISMSLoaderDelegate> *)theDelegate
{
	if ([settingsS.serverType isEqualToString:SUBSONIC] || [settingsS.serverType isEqualToString:UBUNTU_ONE])
	{
		return [[SUSSubFolderLoader alloc] initWithDelegate:theDelegate];
	}
	else if ([settingsS.serverType isEqualToString:WAVEBOX]) 
	{
		return [[PMSSubFolderLoader alloc] initWithDelegate:theDelegate];
	}
	return nil;
}

+ (id)loaderWithCallbackBlock:(LoaderCallback)theBlock
{
	if ([settingsS.serverType isEqualToString:SUBSONIC] || [settingsS.serverType isEqualToString:UBUNTU_ONE])
	{
		return [[SUSSubFolderLoader alloc] initWithCallbackBlock:theBlock];
	}
	else if ([settingsS.serverType isEqualToString:WAVEBOX])
	{
		return [[PMSSubFolderLoader alloc] initWithCallbackBlock:theBlock];
	}
	return nil;
}

#pragma mark - Private DB Methods

- (FMDatabaseQueue *)dbQueue
{
    return databaseS.albumListCacheDbQueue;
}

- (BOOL)resetDb
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		//Initialize the arrays.
		[db beginTransaction];
		[db executeUpdate:@"DELETE FROM albumsCache WHERE folderId = ?", self.myId.md5];
		[db executeUpdate:@"DELETE FROM songsCache WHERE folderId = ?", self.myId.md5];
		[db executeUpdate:@"DELETE FROM albumsCacheCount WHERE folderId = ?", self.myId.md5];
		[db executeUpdate:@"DELETE FROM songsCacheCount WHERE folderId = ?", self.myId.md5];
		[db executeUpdate:@"DELETE FROM folderLength WHERE folderId = ?", self.myId.md5];
		[db commit];
		
		hadError = [db hadError];
		if (hadError)
			DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
    
	return !hadError;
}

- (BOOL)insertAlbumIntoFolderCache:(ISMSAlbum *)anAlbum
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"INSERT INTO albumsCache (folderId, title, albumId, coverArtId, artistName, artistId) VALUES (?, ?, ?, ?, ?, ?)", self.myId.md5, anAlbum.title, anAlbum.albumId, anAlbum.coverArtId, anAlbum.artistName, anAlbum.artistId];
		
		hadError = [db hadError];
		if (hadError)
			DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
	
	return !hadError;
}

- (BOOL)insertSongIntoFolderCache:(ISMSSong *)aSong
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO songsCache (folderId, %@) VALUES (?, %@)", [ISMSSong standardSongColumnNames], [ISMSSong standardSongColumnQMarks]], self.myId.md5, aSong.title, aSong.songId, aSong.artist, aSong.album, aSong.genre, aSong.coverArtId, aSong.path, aSong.suffix, aSong.transcodedSuffix, aSong.duration, aSong.bitRate, aSong.track, aSong.year, aSong.size, aSong.parentId, NSStringFromBOOL(aSong.isVideo), aSong.discNumber];
        
        ALog(@"Added to folderCache with discNumber: %@", aSong.discNumber);
		
		hadError = [db hadError];
		if (hadError)
			DLog(@"Err inserting song %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
	
	return !hadError;
}

- (BOOL)insertAlbumsCount
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"INSERT INTO albumsCacheCount (folderId, count) VALUES (?, ?)", self.myId.md5, @(self.albumsCount)];
		
		hadError = [db hadError];
		if ([db hadError])
			DLog(@"Err inserting album count %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
    
	return !hadError;
}

- (BOOL)insertSongsCount
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"INSERT INTO songsCacheCount (folderId, count) VALUES (?, ?)", self.myId.md5, @(self.songsCount)];
		
		hadError = [db hadError];
		if (hadError)
			DLog(@"Err inserting song count %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
    	
	return !hadError;
}

- (BOOL)insertFolderLength
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"INSERT INTO folderLength (folderId, length) VALUES (?, ?)", self.myId.md5, @(self.folderLength)];
		
		hadError = [db hadError];
		if ([db hadError])
			DLog(@"Err inserting folder length %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
   
	return !hadError;
}
@end
