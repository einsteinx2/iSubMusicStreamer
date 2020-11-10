//
//  WBServerShuffleLoader.m
//  libSub
//
//  Created by Justin Hill on 2/6/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "WBServerShuffleLoader.h"

@implementation WBServerShuffleLoader

- (void)startLoad
{
    if (settingsS.isJukeboxEnabled)
    {
        [databaseS resetJukeboxPlaylist];
        [jukeboxS jukeboxClearRemotePlaylist];
    }
    else
    {
        [databaseS resetCurrentPlaylistDb];
    }
    
    NSDictionary *userInfo = [self.notification userInfo];
    NSString *folderId = [NSString stringWithFormat:@"%i", [[userInfo objectForKey:@"folderId"] intValue]];
    
    NSString *query;
    
    // We should shuffle all songs
    if ([folderId intValue] < 0)
    {
        query = @"SELECT song.*, album_name, artist_name, art_item.art_id FROM song LEFT JOIN folder ON song_folder_id = folder_id LEFT JOIN album ON song_album_id = album_id LEFT JOIN art_item ON art_item.item_id = song_id LEFT JOIN artist ON artist.artist_id = song_artist_id ORDER BY random() LIMIT 100";
    }
    
    // We should shuffle only the folder with the id given
    else
    {
        query = @"SELECT song.*, album_name, artist_name, art_item.art_id FROM song LEFT JOIN folder ON song_folder_id = folder_id LEFT JOIN album ON song_album_id = album_id LEFT JOIN art_item ON art_item.item_id = song_id LEFT JOIN artist ON artist.artist_id = song_artist_id WHERE folder_media_folder_id = ? ORDER BY random() LIMIT 100";
    }
    
    [databaseS.metadataDbQueue inDatabase:^(FMDatabase *db)
     {
         FMResultSet *result = [db executeQuery:query, folderId];
         
         while ([result next])
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
             [s addToCurrentPlaylistDbQueue];
         }
         
         playlistS.isShuffle = NO;
         
         [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
         [self informDelegateLoadingFinished];
     }];
}

@end
