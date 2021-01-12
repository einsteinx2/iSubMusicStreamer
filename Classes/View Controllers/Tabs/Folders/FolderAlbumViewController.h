//
//  AlbumViewController.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ISMSFolderArtist, ISMSFolderAlbum, SubfolderDAO;

@interface FolderAlbumViewController: UITableViewController

@property (nonatomic) BOOL isReloading;
@property (nonatomic) NSInteger folderId;
@property (nonatomic, strong) ISMSFolderArtist *folderArtist;
@property (nonatomic, strong) ISMSFolderAlbum *folderAlbum;
@property (nonatomic, strong) NSArray *sectionInfo;
@property (nonatomic, strong) SubfolderDAO *dataModel;

- (instancetype)initWithFolderArtist:(ISMSFolderArtist *)folderArtist orFolderAlbum:(ISMSFolderAlbum *)folderAlbum;

- (void)cancelLoad;

@end
