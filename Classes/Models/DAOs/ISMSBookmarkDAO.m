//
//  ISMSBookmarkDAO.m
//  iSub
//
//  Created by Benjamin Baron on 11/21/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "ISMSBookmarkDAO.h"
#import "FMDatabaseQueueAdditions.h"
#import "DatabaseSingleton.h"
#import "PlaylistSingleton.h"
#import "SavedSettings.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"

@implementation ISMSBookmarkDAO

+ (void)createBookmarkForSong:(ISMSSong *)song name:(NSString *)name bookmarkPosition:(NSUInteger)position bytePosition:(NSUInteger)bytePosition {
    // TODO: somehow this is saving the incorrect playlist index sometimes
    [databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db) {
        NSString *query = [NSString stringWithFormat:@"INSERT INTO bookmarks (playlistIndex, name, position, %@, bytes) VALUES (?, ?, ?, %@, ?)", [ISMSSong standardSongColumnNames], [ISMSSong standardSongColumnQMarks]];
        [db executeUpdate:query, @(playlistS.currentIndex), name, @(position), song.title, song.songId, song.artist, song.album, song.genre, song.coverArtId, song.path, song.suffix, song.transcodedSuffix, song.duration, song.bitRate, song.track, song.year, song.size, song.parentId, @(song.isVideo), song.discNumber, @(bytePosition)];

        NSInteger bookmarkId = [db intForQuery:@"SELECT MAX(bookmarkId) FROM bookmarks"];
        
        NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
        NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
        NSString *table = playlistS.isShuffle ? shufTable : currTable;
        //DLog(@"table: %@", table);
        
        // Save the playlist
        NSString *dbName = settingsS.isOfflineMode ? @"%@/offlineCurrentPlaylist.db" : @"%@/%@currentPlaylist.db";
        [db executeUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:dbName, settingsS.databasePath, settingsS.urlString.md5], @"currentPlaylistDb"];
        [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmark%li (%@)", (long)bookmarkId, [ISMSSong standardSongColumnSchema]]];
        [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO bookmark%li SELECT * FROM currentPlaylistDb.%@", (long)bookmarkId, table]];
        
        [db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
    }];
}

@end
