//
//  SUSAllSongsLoader.h
//  iSub
//
//  Created by Ben Baron on 9/23/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoader.h"

#define READ_BUFFER_AMOUNT 400
#define WRITE_BUFFER_AMOUNT 400

@class ISMSArtist, ISMSAlbum, SUSRootFoldersDAO;

@interface SUSAllSongsLoader : ISMSLoader

@property NSInteger iteration;
@property NSUInteger albumCount;
@property NSUInteger artistCount;
@property NSUInteger currentRow;

@property NSUInteger tempAlbumsCount;
@property NSUInteger tempSongsCount;
@property NSUInteger tempGenresCount;
@property NSUInteger tempGenresLayoutCount;

@property NSUInteger totalAlbumsProcessed;
@property NSUInteger totalSongsProcessed;

@property (strong) ISMSArtist *currentArtist;
@property (strong) ISMSAlbum *currentAlbum;
@property (strong) SUSRootFoldersDAO *rootFolders;
@property (strong) NSDate *notificationTimeArtist;
@property (strong) NSDate *notificationTimeAlbum;
@property (strong) NSDate *notificationTimeSong;
@property (strong) NSDate *notificationTimeArtistAlbum;

+ (BOOL)isLoading;
+ (void)setIsLoading:(BOOL)isLoading;

@end
