//
//  ArtistUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 5/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CacheArtistUITableViewCell.h"
#import "CellOverlay.h"

@implementation CacheArtistUITableViewCell

@synthesize artistNameScrollView, artistNameLabel;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
	if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{		
		artistNameScrollView = [[UIScrollView alloc] init];
		artistNameScrollView.frame = CGRectMake(14, 0, 310, 44);
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

	// Automatically set the width based on the width of the text
	self.artistNameLabel.frame = CGRectMake(0, 0, 290, 44);
    CGSize expectedLabelSize = [self.artistNameLabel.text boundingRectWithSize:CGSizeMake(1000,44)
                                                                       options:NSStringDrawingUsesLineFragmentOrigin
                                                                    attributes:@{NSFontAttributeName:self.artistNameLabel.font}
                                                                       context:nil].size;
	CGRect newFrame = artistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	self.artistNameLabel.frame = newFrame;

}

- (void)toggleDelete
{
	if (self.isDelete)
	{
		[viewObjectsS.multiDeleteList removeObject:self.artistNameLabel.text];
		[NSNotificationCenter postNotificationToMainThreadWithName:@"hideDeleteButton"];
		self.deleteToggleImage.image = [UIImage imageNamed:@"unselected.png"];
	}
	else
	{
		[viewObjectsS.multiDeleteList addObject:self.artistNameLabel.text];
		[NSNotificationCenter postNotificationToMainThreadWithName:@"showDeleteButton"];
		self.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
	}
	
	self.isDelete = !self.isDelete;
}

#pragma mark - Overlay

- (void)showOverlay
{	
	[super showOverlay];
	if (self.isOverlayShowing)
	{
		[self.overlayView.downloadButton setTitle:@"Delete" forState:UIControlStateNormal];
        self.overlayView.downloadButton.titleLabel.textColor = UIColor.redColor;
		[self.overlayView.downloadButton addTarget:self action:@selector(deleteAction) forControlEvents:UIControlEventTouchUpInside];
	}
}

- (void)deleteAction
{	
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Deleting"];
	[self performSelector:@selector(deleteAllSongs) withObject:nil afterDelay:0.05];
	
	self.overlayView.downloadButton.alpha = .3;
	self.overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}

- (void)deleteAllSongs
{
	NSMutableArray *songMd5s = [[NSMutableArray alloc] initWithCapacity:50];
	[databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? ", artistNameLabel.text];
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
			[ISMSSong removeSongFromCacheDbQueueByMD5:md5];
		}
	}
	
	[cacheS findCacheSize];
	
	// Reload the cached songs table
	[NSNotificationCenter postNotificationToMainThreadWithName:@"cachedSongDeleted"];
	
	if (!cacheQueueManagerS.isQueueDownloading)
		[cacheQueueManagerS startDownloadQueue];
	
	// Hide the loading screen	
	[viewObjectsS hideLoadingScreen];
}

- (void)queueAction
{
	[super queueAction];
	
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	[self performSelector:@selector(queueAllSongs) withObject:nil afterDelay:0.05];
	[self hideOverlay];
}

- (void)queueAllSongs
{
	NSMutableArray *songMd5s = [[NSMutableArray alloc] initWithCapacity:50];
	[databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? ORDER BY seg2 COLLATE NOCASE", artistNameLabel.text];
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
			ISMSSong *aSong = [ISMSSong songFromCacheDbQueue:md5];
			[aSong addToCurrentPlaylistDbQueue];
		}
	}
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	
	[viewObjectsS hideLoadingScreen];
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
