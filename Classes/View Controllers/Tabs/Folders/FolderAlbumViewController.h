//
//  AlbumViewController.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SUSLoaderDelegate.h"

@class ISMSFolderArtist, ISMSFolderAlbum, SubfolderDAO;

@interface FolderAlbumViewController : UITableViewController <SUSLoaderDelegate>

@property (nonatomic) BOOL isReloading;
@property (nonatomic, copy) NSString *folderId;
@property (nonatomic, strong) ISMSFolderArtist *folderArtist;
@property (nonatomic, strong) ISMSFolderAlbum *folderAlbum;
@property (nonatomic, strong) NSArray *sectionInfo;
@property (nonatomic, strong) SubfolderDAO *dataModel;

- (instancetype)initWithFolderArtist:(ISMSFolderArtist *)folderArtist orFolderAlbum:(ISMSFolderAlbum *)folderAlbum;

- (void)cancelLoad;

@end
