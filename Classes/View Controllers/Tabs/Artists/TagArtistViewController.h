//
//  TagArtistViewController.h
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SUSLoaderDelegate.h"

@class ISMSTagArtist, ISMSTagAlbum, SUSTagArtistDAO;

@interface TagArtistViewController : UITableViewController <SUSLoaderDelegate>

@property (nonatomic) BOOL isReloading;
@property (nonatomic, strong) ISMSTagArtist *tagArtist;
@property (nonatomic, strong) SUSTagArtistDAO *dataModel;

- (instancetype)initWithTagArtist:(ISMSTagArtist *)tagArtist;

- (void)cancelLoad;

@end
