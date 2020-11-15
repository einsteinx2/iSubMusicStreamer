//
//  SearchAllViewController.h
//  iSub
//
//  Created by Ben Baron on 4/6/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ISMSArtist, ISMSAlbum, ISMSSong;
@interface SearchAllViewController : UITableViewController

@property (nullable, strong) NSMutableArray *cellNames;
@property (nullable, strong) NSArray<ISMSArtist*> *listOfArtists;
@property (nullable, strong) NSArray<ISMSAlbum*> *listOfAlbums;
@property (nullable, strong) NSArray<ISMSSong*> *listOfSongs;
@property (nullable, strong) NSString *query;

@end

NS_ASSUME_NONNULL_END
