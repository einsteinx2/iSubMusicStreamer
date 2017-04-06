//
//  AlbumUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "GenresAlbumUITableViewCell.h"
#import "CellOverlay.h"


@implementation GenresAlbumUITableViewCell

@synthesize segment, seg1, genre, coverArtView, albumNameScrollView, albumNameLabel;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{		
		coverArtView = [[AsynchronousImageView alloc] init];
		coverArtView.isLarge = NO;
		[self.contentView addSubview:coverArtView];
		
		albumNameScrollView = [[UIScrollView alloc] init];
		albumNameScrollView.frame = CGRectMake(65, 0, 230, 60);
		albumNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		albumNameScrollView.showsVerticalScrollIndicator = NO;
		albumNameScrollView.showsHorizontalScrollIndicator = NO;
		albumNameScrollView.userInteractionEnabled = NO;
		albumNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:albumNameScrollView];
		
		albumNameLabel = [[UILabel alloc] init];
		albumNameLabel.backgroundColor = [UIColor clearColor];
		albumNameLabel.textAlignment = NSTextAlignmentLeft; // default
		albumNameLabel.font = ISMSAlbumFont;
		[albumNameScrollView addSubview:albumNameLabel];
	}
	
	return self;
}

- (void)layoutSubviews
{	
    [super layoutSubviews];
	
	// Automatically set the width based on the width of the text
	self.albumNameLabel.frame = CGRectMake(0, 0, 230, 60);
    CGSize expectedLabelSize = [self.albumNameLabel.text boundingRectWithSize:CGSizeMake(1000,60)
                                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                                  attributes:@{NSFontAttributeName:self.albumNameLabel.font}
                                                                     context:nil].size;
	CGRect newFrame = albumNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	self.albumNameLabel.frame = newFrame;
	
	self.coverArtView.frame = CGRectMake(0, 0, 60, 60);
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
		query = [NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND seg%li = ? AND genre = ? ORDER BY seg%li COLLATE NOCASE", (long)self.segment, (long)(self.segment + 1)];
	}
	else
	{
		dbQueue = databaseS.genresDbQueue;
		query = [NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE seg1 = ? AND seg%li = ? AND genre = ? ORDER BY seg%li COLLATE NOCASE", (long)self.segment, (long)(self.segment + 1)];
	}
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:query, self.seg1, self.albumNameLabel.text, self.genre];
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
		query = [NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND seg%li = ? AND genre = ? ORDER BY seg%li COLLATE NOCASE", (long)self.segment, (long)(self.segment + 1)];
	}
	else
	{
		dbQueue = databaseS.genresDbQueue;
		query = [NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE seg1 = ? AND seg%li = ? AND genre = ? ORDER BY seg%li COLLATE NOCASE", (long)self.segment, (long)(self.segment + 1)];
	}
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:0];
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:query, self.seg1, self.albumNameLabel.text, self.genre];
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
	if (self.albumNameLabel.frame.size.width > self.albumNameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:self.albumNameLabel.frame.size.width/(float)150];
		self.albumNameScrollView.contentOffset = CGPointMake(self.albumNameLabel.frame.size.width - self.albumNameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:self.albumNameLabel.frame.size.width/(float)150];
	self.albumNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
