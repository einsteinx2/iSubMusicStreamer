//
//  SUSTagAlbumDAO.m
//  iSub
//
//  Created by Benjamin Baron on 12/23/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "SUSTagAlbumDAO.h"
#import "SUSTagAlbumLoader.h"
#import "MusicSingleton.h"
#import "FMDatabaseQueueAdditions.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "JukeboxSingleton.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "Swift.h"

@implementation SUSTagAlbumDAO

#pragma mark Lifecycle

- (void)setup {
    _songStartRow = [self.dbQueue intForQuery:@"SELECT ROWID FROM tagSong WHERE albumId = ? LIMIT 1", self.tagAlbum.albumId];
    _songsCount = [self.dbQueue intForQuery:@"SELECT count(*) FROM tagSong WHERE albumId = ?", self.tagAlbum.albumId];
}

- (instancetype)init {
    NSAssert(NO, @"[SUSTagAlbumDAO] init should never be called");
    if (self = [super init]) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithDelegate:(NSObject<SUSLoaderDelegate> *)delegate {
    NSAssert(NO, @"[SUSTagAlbumDAO] initWithDelegate should never be called");
    if (self = [super init]) {
        _delegate = delegate;
        [self setup];
    }
    return self;
}

- (instancetype)initWithDelegate:(NSObject<SUSLoaderDelegate> *)delegate andTagAlbum:(ISMSTagAlbum *)tagAlbum {
    if (self = [super init]) {
        _delegate = delegate;
        _tagAlbum = tagAlbum;
        [self setup];
    }
    return self;
}

- (void)dealloc {
    [_loader cancelLoad];
    _loader.delegate = nil;
}

- (FMDatabaseQueue *)dbQueue {
    return databaseS.serverDbQueue;
}

#pragma mark Public DAO Methods

- (BOOL)hasLoaded {
    if (self.songsCount > 0)
        return YES;
    
    return NO;
}

- (ISMSSong *)songForTableViewRow:(NSUInteger)row {
    NSUInteger dbRow = self.songStartRow + row;
    return [ISMSSong songFromDbRow:dbRow-1 inTable:@"tagSong"];
}

- (ISMSSong *)playSongAtTableViewRow:(NSUInteger)row {
    NSUInteger dbRow = self.songStartRow + row;
    
    // Clear the current playlist
    if (settingsS.isJukeboxEnabled) {
        [databaseS resetJukeboxPlaylist];
        [jukeboxS clearRemotePlaylist];
    } else {
        [databaseS resetCurrentPlaylistDb];
    }
    
    // Add the songs to the playlist
    for (int i = 0; i < self.songsCount; i++) {
        @autoreleasepool  {
            [[self songForTableViewRow:i] addToCurrentPlaylistDbQueue];
        }
    }
    
    // Set player defaults
    playlistS.isShuffle = NO;
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
    
    // Start the song
    return [musicS playSongAtPosition:(dbRow - self.songStartRow)];
}

#pragma mark Loader Manager Methods

- (void)restartLoad {
    [self startLoad];
}

- (void)startLoad {
    self.loader = [[SUSTagAlbumLoader alloc] initWithDelegate:self];
    self.loader.albumId = self.tagAlbum.albumId;
    [self.loader startLoad];
}

- (void)cancelLoad {
    [self.loader cancelLoad];
    self.loader.delegate = nil;
    self.loader = nil;
}

#pragma mark Loader Delegate Methods

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error {
    self.loader.delegate = nil;
    self.loader = nil;
    
    if ([self.delegate respondsToSelector:@selector(loadingFailed:withError:)]) {
        [self.delegate loadingFailed:nil withError:error];
    }
}

- (void)loadingFinished:(SUSLoader *)theLoader {
    self.loader.delegate = nil;
    self.loader = nil;
    
    [self setup];
    
    if ([self.delegate respondsToSelector:@selector(loadingFinished:)]) {
        [self.delegate loadingFinished:nil];
    }
}

@end
