//
//  PMSQueueAllLoader.m
//  iSub
//
//  Created by Benjamin Baron on 6/14/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "PMSQueueAllLoader.h"

@implementation PMSQueueAllLoader


- (void)loadAlbumFolder
{
	if (self.isCancelled)
		return;
	
	NSString *folderId = [self.folderIds objectAtIndexSafe:0];
    [self queueFolderMediaRecursively:folderId];
    
    // Do post-adding stuff
    if (self.isShuffleButton)
    {
        // Perform the shuffle
        if (settingsS.isJukeboxEnabled)
            [jukeboxS jukeboxClearRemotePlaylist];
        
        [databaseS shufflePlaylist];
        
        if (settingsS.isJukeboxEnabled)
            [jukeboxS jukeboxReplacePlaylistWithLocal];
    }
    
    if (self.isQueue)
    {
        if (settingsS.isJukeboxEnabled)
        {
            //[jukeboxS jukeboxReplacePlaylistWithLocal];
        }
        else
        {
            [streamManagerS fillStreamQueue:audioEngineS.player.isStarted];
        }
    }
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_HideLoadingScreen];
    
    if (self.doShowPlayer)
    {
        [musicS showPlayer];
    }
    
    //DLog(@"Loading folderid: %@", folderId);
    
//    NSMutableURLRequest *request = [NSMutableURLRequest requestWithPMSAction:@"folders" itemId:folderId];
//	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
//	if (self.connection)
//	{
//		self.receivedData = [NSMutableData data];
//	}
}

- (void)queueFolderMediaRecursively:(NSString *)folderId
{
    NSDictionary *folderContents = [self folderWithFolderId:folderId];
    if([[folderContents objectForKey:@"folders"] count] != 0)
    {
        for (ISMSAlbum *f in [folderContents objectForKey:@"folders"]) {
            [self queueFolderMediaRecursively:f.albumId];
        }
    }
    
    for(ISMSSong *s in [folderContents objectForKey:@"songs"])
    {
        if (self.isQueue)
        {
            [s addToCurrentPlaylistDbQueue];
        }
        else
        {
            [s addToCacheQueueDbQueue];
        }
    }
}

- (NSDictionary *)folderWithFolderId:(NSString *)folderId
{
    NSMutableArray *folders = [[NSMutableArray alloc] init];
    NSMutableArray *songs = [[NSMutableArray alloc] init];
    [databaseS.metadataDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *query = @"SELECT folder.*, art.art_id FROM folder LEFT JOIN art_item ON art_item.item_id = folder.folder_id LEFT JOIN art ON art_item.art_id = art.art_id WHERE parent_folder_id = ?";
         FMResultSet *result = [db executeQuery:query, folderId];
                  
         while ([result next])
         {
             @autoreleasepool
             {
                 NSDictionary *dict = @{
                                        @"folderName" : [result stringForColumn:@"folder_name"] ? [result stringForColumn:@"folder_name"] : [NSNull null],
                                        @"folderId" : [result stringForColumn:@"folder_id"] ? [result stringForColumn:@"folder_id"] : [NSNull null],
                                        @"artId" : [result stringForColumn:@"art_id"] ? [result stringForColumn:@"art_id"] : [NSNull null]
                                        };
                 
                 ISMSAlbum *a = [[ISMSAlbum alloc] initWithPMSDictionary:dict];
                 [folders addObject:a];
             }
         }
         [result close];
     }];
	
    [databaseS.metadataDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *query = @"SELECT song.*, art.art_id, artist.artist_name, album.album_name FROM song LEFT JOIN artist ON artist.artist_id = song.song_artist_id LEFT JOIN album ON album.album_id = song.song_album_id LEFT JOIN art_item ON song.song_id = art_item.item_id LEFT JOIN art ON art.art_id = art_item.art_id WHERE song.song_folder_id = ?";
         FMResultSet *result = [db executeQuery:query, folderId];
         
         while ([result next])
         {
             @autoreleasepool
             {
                 NSDictionary *dict = @{
                                        @"songName" : [result stringForColumn:@"song_name"] ? [result stringForColumn:@"song_name"] : [NSNull null],
                                        @"itemId" : [result stringForColumn:@"song_id"] ? [result stringForColumn:@"song_id"] : [NSNull null],
                                        @"folderId" : [result stringForColumn:@"song_folder_id"] ? [result stringForColumn:@"song_folder_id"] : [NSNull null],
                                        @"artistName" : [result stringForColumn:@"artist_name"] ? [result stringForColumn:@"artist_name"] : [NSNull null],
                                        @"albumName" : [result stringForColumn:@"album_name"] ? [result stringForColumn:@"album_name"] : [NSNull null],
                                        //@"genreName" : [result stringForColumn:@"genre_name"],
                                        @"artId" : [result stringForColumn:@"art_id"] ? [result stringForColumn:@"art_id"] : [NSNull null],
                                        @"fileType" : [result stringForColumn:@"song_file_type_id"] ? [result stringForColumn:@"song_file_type_id"] : [NSNull null],
                                        @"duration" : [result stringForColumn:@"song_duration"] ? [result stringForColumn:@"song_duration"] : [NSNull null],
                                        @"bitrate" : [result stringForColumn:@"song_bitrate"] ? [result stringForColumn:@"song_bitrate"] : [NSNull null],
                                        @"trackNumber" : [result stringForColumn:@"song_track_num"] ? [result stringForColumn:@"song_track_num"] : [NSNull null],
                                        @"year" : [result stringForColumn:@"song_release_year"] ? [result stringForColumn:@"song_release_year"] : [NSNull null],
                                        @"fileSize" : [result stringForColumn:@"song_file_size"] ? [result stringForColumn:@"song_file_size"] : [NSNull null]
                                        };
                 
                 ISMSSong *s = [[ISMSSong alloc] initWithPMSDictionary:dict];
                 [songs addObject:s];
             }
         }
         [result close];
     }];
    
    NSDictionary *retVal = @{
                             @"songs": songs,
                             @"folders": folders
                             };
    return retVal;
}

- (void)process
{
	NSString *responseString = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
    //DLog(@"queue all: %@", responseString);
	NSDictionary *response = [[[SBJsonParser alloc] init] objectWithString:responseString];
	
	NSArray *folders = [response objectForKey:@"folders"];
	NSArray *songs = [response objectForKey:@"songs"];
	
	for (NSDictionary *folder in folders)
	{
		@autoreleasepool 
		{
			ISMSAlbum *anAlbum = [[ISMSAlbum alloc] initWithPMSDictionary:folder];
			[self.listOfAlbums addObject:anAlbum];
		}
	}
    //DLog(@"folders: %@", folders);
    //DLog(@"listOfAlbums: %@", self.listOfAlbums);

	for (NSDictionary *song in songs)
	{
		@autoreleasepool 
		{
			ISMSSong *aSong = [[ISMSSong alloc] initWithPMSDictionary:song];
			[self.listOfSongs addObject:aSong];
		}
	}
}

@end
