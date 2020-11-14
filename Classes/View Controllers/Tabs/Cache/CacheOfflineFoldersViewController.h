//
//  CacheOfflineFoldersViewController.h
//  iSub
//
//  Created by Benjamin Baron on 11/13/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CacheOfflineFoldersViewController : UITableViewController

@property (nonatomic) BOOL isNoSongsScreenShowing;
@property (nonatomic, strong) UIImageView *noSongsScreen;
@property (nonatomic) BOOL showIndex;
@property (nonatomic, strong) NSMutableArray *listOfArtists;
@property (nonatomic, strong) NSMutableArray *listOfArtistsSections;
@property (nonatomic, strong) NSArray *sectionInfo;

- (void)playAllPlaySong;
- (void)reloadTable;

@end
