//
//  TagAlbumViewController.h
//  iSub
//
//  Created by Benjamin Baron on 12/23/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SUSLoaderDelegate.h"

@class ISMSTagAlbum, TagAlbumDAO;

@interface TagAlbumViewController : UITableViewController <SUSLoaderDelegate>

@property (nonatomic) BOOL isReloading;
@property (nonatomic, strong) ISMSTagAlbum *tagAlbum;
@property (nonatomic, strong) NSArray *sectionInfo;
@property (nonatomic, strong) TagAlbumDAO *dataModel;

- (instancetype)initWithTagAlbum:(ISMSTagAlbum *)tagAlbum;

- (void)cancelLoad;

@end
