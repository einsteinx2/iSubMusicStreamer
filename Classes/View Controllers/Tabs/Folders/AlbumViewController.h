//
//  AlbumViewController.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SUSLoaderDelegate.h"

@class ISMSArtist, ISMSAlbum, SUSSubFolderDAO;

@interface AlbumViewController : UITableViewController <SUSLoaderDelegate>

@property (nonatomic) BOOL isReloading;
@property (nonatomic, copy) NSString *myId;
@property (nonatomic, strong) ISMSArtist *myArtist;
@property (nonatomic, strong) ISMSAlbum *myAlbum;
@property (nonatomic, strong) NSArray *sectionInfo;
@property (nonatomic, strong) SUSSubFolderDAO *dataModel;

- (AlbumViewController *)initWithArtist:(ISMSArtist *)anArtist orAlbum:(ISMSAlbum *)anAlbum;

- (void)cancelLoad;

@end
