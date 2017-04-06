//
//  ArtistUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 5/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "GenresArtistUITableViewCell.h"
#import "CellOverlay.h"


@implementation GenresArtistUITableViewCell

@synthesize genre, artistNameScrollView, artistNameLabel;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
	if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{		
		artistNameScrollView = [[UIScrollView alloc] init];
		artistNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		artistNameScrollView.showsVerticalScrollIndicator = NO;
		artistNameScrollView.showsHorizontalScrollIndicator = NO;
		artistNameScrollView.userInteractionEnabled = NO;
		artistNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:artistNameScrollView];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = NSTextAlignmentLeft; // default
		artistNameLabel.font = ISMSArtistFont;
		[artistNameScrollView addSubview:artistNameLabel];
	}
	
	return self;
}

- (void)layoutSubviews 
{	
    [super layoutSubviews];
	
	self.contentView.frame = CGRectMake(0, 0, 320, 44);
	self.artistNameScrollView.frame = CGRectMake(5, 0, 250, 44);
	
	// Automatically set the width based on the width of the text
	self.artistNameLabel.frame = CGRectMake(0, 0, 250, 44);
    CGSize expectedLabelSize = [self.artistNameLabel.text boundingRectWithSize:CGSizeMake(1000,44)
                                                                      options:NSStringDrawingUsesLineFragmentOrigin
                                                                   attributes:@{NSFontAttributeName:self.artistNameLabel.font}
                                                                      context:nil].size;
	CGRect newFrame = self.artistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	self.artistNameLabel.frame = newFrame;
}


#pragma mark - Overlay

- (void)showOverlay
{
	[super showOverlay];
	
	self.overlayView.downloadButton.alpha = (float)!settingsS.isOfflineMode;
	self.overlayView.downloadButton.enabled = !settingsS.isOfflineMode;
    
    if (!settingsS.isCacheUnlocked)
    {
        self.overlayView.downloadButton.enabled = NO;
    }
}

- (void)downloadAllSongs
{
	FMDatabaseQueue *dbQueue;
	NSString *query;
	
	if (settingsS.isOfflineMode)
	{
		dbQueue = databaseS.songCacheDbQueue;
		query = @"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND genre = ? ORDER BY seg2 COLLATE NOCASE";
	}
	else
	{
		dbQueue = databaseS.genresDbQueue;
		query = @"SELECT md5 FROM genresLayout WHERE seg1 = ? AND genre = ? ORDER BY seg2 COLLATE NOCASE";
	}
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:query, self.artistNameLabel.text, self.genre];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSString *md5 = [result stringForColumnIndex:0];
				if (md5) [songMd5s addObject:md5];
			}
		}
		[result close];
	}];
	
	for (NSString *md5 in songMd5s)
	{
		@autoreleasepool 
		{
			ISMSSong *aSong = [ISMSSong songFromGenreDbQueue:md5];
			[aSong addToCacheQueueDbQueue];
		}
	}
	
	// Hide the loading screen
	[viewObjectsS hideLoadingScreen];
}

- (void)downloadAction
{
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	[self performSelector:@selector(downloadAllSongs) withObject:nil afterDelay:0.05];
	
	self.overlayView.downloadButton.alpha = .3;
	self.overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}

- (void)queueAllSongs
{
	FMDatabaseQueue *dbQueue;
	NSString *query;
	
	if (settingsS.isOfflineMode)
	{
		dbQueue = databaseS.songCacheDbQueue;
		query = @"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND genre = ? ORDER BY seg2 COLLATE NOCASE";
	}
	else
	{
		dbQueue = databaseS.genresDbQueue;
		query = @"SELECT md5 FROM genresLayout WHERE seg1 = ? AND genre = ? ORDER BY seg2 COLLATE NOCASE";
	}
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:query, self.artistNameLabel.text, self.genre];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSString *md5 = [result stringForColumnIndex:0];
				if (md5) [songMd5s addObject:md5];
			}
		}
		[result close];
	}];
	
	for (NSString *md5 in songMd5s)
	{
		@autoreleasepool 
		{
			ISMSSong *aSong = [ISMSSong songFromGenreDbQueue:md5];
			[aSong addToCurrentPlaylistDbQueue];
		}
	}
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	
	[viewObjectsS hideLoadingScreen];
}

- (void)queueAction
{
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	[self performSelector:@selector(queueAllSongs) withObject:nil afterDelay:0.05];
	[self hideOverlay];
}

#pragma mark - Scrolling

- (void)scrollLabels
{
	if (self.artistNameLabel.frame.size.width > self.artistNameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:self.artistNameLabel.frame.size.width/(float)150];
		self.artistNameScrollView.contentOffset = CGPointMake(self.artistNameLabel.frame.size.width - self.artistNameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:self.artistNameLabel.frame.size.width/(float)150];
	self.artistNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
