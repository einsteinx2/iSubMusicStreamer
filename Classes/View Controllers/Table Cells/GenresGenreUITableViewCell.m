//
//  ArtistUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 5/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "GenresGenreUITableViewCell.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "FMDatabaseQueueAdditions.h"
#import "SavedSettings.h"
#import "DatabaseSingleton.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"

@implementation GenresGenreUITableViewCell

#pragma mark Lifecycle

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier  {
	if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
		_genreNameScrollView = [[UIScrollView alloc] init];
		_genreNameScrollView.frame = CGRectMake(5, 0, 300, 44);
		_genreNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		_genreNameScrollView.showsVerticalScrollIndicator = NO;
		_genreNameScrollView.showsHorizontalScrollIndicator = NO;
		_genreNameScrollView.userInteractionEnabled = NO;
		_genreNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:_genreNameScrollView];
		
		_genreNameLabel = [[UILabel alloc] init];
		_genreNameLabel.backgroundColor = [UIColor clearColor];
		_genreNameLabel.textAlignment = NSTextAlignmentLeft; // default
		_genreNameLabel.font = ISMSBoldFont(20);
		[_genreNameScrollView addSubview:_genreNameLabel];
	}
	
	return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
		
	// Automatically set the width based on the width of the text
	self.genreNameLabel.frame = CGRectMake(0, 0, 270, 44);
    CGSize expectedLabelSize = [self.genreNameLabel.text boundingRectWithSize:CGSizeMake(1000,44)
                                                                      options:NSStringDrawingUsesLineFragmentOrigin
                                                                   attributes:@{NSFontAttributeName:self.genreNameLabel.font}
                                                                      context:nil].size;
	CGRect newFrame = self.genreNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	self.genreNameLabel.frame = newFrame;
}

#pragma mark Overlay

- (void)showOverlay
{
//	[super showOverlay];
//
//	self.overlayView.downloadButton.alpha = (float)!settingsS.isOfflineMode;
//	self.overlayView.downloadButton.enabled = !settingsS.isOfflineMode;
}

- (void)downloadAllSongs {
	FMDatabaseQueue *dbQueue;
	NSString *query;
	
	if (settingsS.isOfflineMode) {
		dbQueue = databaseS.songCacheDbQueue;
		query = [NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE"];
	} else {
		dbQueue = databaseS.genresDbQueue;
		query = [NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE"];
	}
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
	[dbQueue inDatabase:^(FMDatabase *db) {
		FMResultSet *result = [db executeQuery:query, self.genreNameLabel.text];
		while ([result next]) {
			@autoreleasepool {
				NSString *md5 = [result stringForColumnIndex:0];
				if (md5) [songMd5s addObject:md5];
			}
		}
		[result close];
	}];
	
	for (NSString *md5 in songMd5s) {
		@autoreleasepool {
			ISMSSong *aSong = [ISMSSong songFromGenreDbQueue:md5];
			[aSong addToCacheQueueDbQueue];
		}
	}
	
	// Hide the loading screen
	[viewObjectsS hideLoadingScreen];
}

- (void)downloadAction {
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	[self performSelector:@selector(downloadAllSongs) withObject:nil afterDelay:0.05];
	
//	self.overlayView.downloadButton.alpha = .3;
//	self.overlayView.downloadButton.enabled = NO;
//
//	[self hideOverlay];
}

- (void)queueAllSongs {
	FMDatabaseQueue *dbQueue;
	NSString *query;
	
	if (settingsS.isOfflineMode) {
		dbQueue = databaseS.songCacheDbQueue;
		query = @"SELECT md5 FROM cachedSongsLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE";
	} else {
		dbQueue = databaseS.genresDbQueue;
		query = @"SELECT md5 FROM genresLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE";
	}
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
	[dbQueue inDatabase:^(FMDatabase *db) {
		FMResultSet *result = [db executeQuery:query, self.genreNameLabel.text];
		
		while ([result next]) {
			@autoreleasepool {
				NSString *md5 = [result stringForColumnIndex:0];
				if (md5) [songMd5s addObject:md5];
			}
		}
		[result close];
	}];
	
	for (NSString *md5 in songMd5s) {
		@autoreleasepool {
			ISMSSong *aSong = [ISMSSong songFromGenreDbQueue:md5];
			[aSong addToCurrentPlaylistDbQueue];
		}
	}
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	
	[viewObjectsS hideLoadingScreen];
}

- (void)queueAction {
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	[self performSelector:@selector(queueAllSongs) withObject:nil afterDelay:0.05];
//	[self hideOverlay];
}

#pragma mark Scrolling

- (void)scrollLabels{
	if (self.genreNameLabel.frame.size.width > self.genreNameScrollView.frame.size.width){
        [UIView animateWithDuration:self.genreNameLabel.frame.size.width/150. animations:^{
            self.genreNameScrollView.contentOffset = CGPointMake(self.genreNameLabel.frame.size.width - self.genreNameScrollView.frame.size.width + 10, 0);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:self.genreNameLabel.frame.size.width/150. animations:^{
                self.genreNameScrollView.contentOffset = CGPointZero;
            }];
        }];
	}
}

@end
