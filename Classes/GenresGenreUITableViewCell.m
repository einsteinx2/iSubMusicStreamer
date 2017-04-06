//
//  ArtistUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 5/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "GenresGenreUITableViewCell.h"
#import "CellOverlay.h"

@implementation GenresGenreUITableViewCell

@synthesize genreNameScrollView, genreNameLabel;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
	if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{
		genreNameScrollView = [[UIScrollView alloc] init];
		genreNameScrollView.frame = CGRectMake(5, 0, 300, 44);
		genreNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		genreNameScrollView.showsVerticalScrollIndicator = NO;
		genreNameScrollView.showsHorizontalScrollIndicator = NO;
		genreNameScrollView.userInteractionEnabled = NO;
		genreNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:genreNameScrollView];
		
		genreNameLabel = [[UILabel alloc] init];
		genreNameLabel.backgroundColor = [UIColor clearColor];
		genreNameLabel.textAlignment = NSTextAlignmentLeft; // default
		genreNameLabel.font = ISMSBoldFont(20);
		[genreNameScrollView addSubview:genreNameLabel];
	}
	
	return self;
}


- (void)layoutSubviews 
{	
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
		query = [NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE"];
	}
	else
	{
		dbQueue = databaseS.genresDbQueue;
		query = [NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE"];
	}
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:query, self.genreNameLabel.text];
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
		query = @"SELECT md5 FROM cachedSongsLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE";
	}
	else
	{
		dbQueue = databaseS.genresDbQueue;
		query = @"SELECT md5 FROM genresLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE";
	}
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:query, self.genreNameLabel.text];
		
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
	if (self.genreNameLabel.frame.size.width > self.genreNameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:self.genreNameLabel.frame.size.width/(float)150];
		self.genreNameScrollView.contentOffset = CGPointMake(self.genreNameLabel.frame.size.width - self.genreNameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:self.genreNameLabel.frame.size.width/(float)150];
	self.genreNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
