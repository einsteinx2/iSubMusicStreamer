//
//  CacheAlbumsViewController.h
//  iSub
//
//  Created by Ben Baron on 6/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ISMSFolderAlbum, ISMSSong, DownloadedFolderAlbum, DownloadedSong;
@interface CacheAlbumViewController : UITableViewController 

//@property (nonatomic, copy) NSString *artistName;
//@property (nonatomic, strong) NSMutableArray<NSArray*> *albums;
//@property (nonatomic, strong) NSMutableArray<NSArray*> *songs;
//@property (nonatomic, strong) NSArray *sectionInfo;
//@property (nonatomic, strong) NSArray *segments;


@property (nonatomic) NSInteger level;
@property (nonatomic) NSString *parentPathComponent;
@property (nonatomic, strong) NSArray<DownloadedFolderAlbum*> *downloadedFolderAlbums;
@property (nonatomic, strong) NSArray<DownloadedSong*> *downloadedSongs;

- (instancetype)initWithLevel:(NSInteger)level parentPathComponent:(NSString *)parentPathComponent;

@end
