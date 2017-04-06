//
//  AllAlbumsUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "AllSongsUITableViewCell.h"
#import "CellOverlay.h"
#import "AsynchronousImageView.h"

@implementation AllSongsUITableViewCell

@synthesize md5, coverArtView, songNameScrollView, songNameLabel, artistNameLabel;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{	
		self.isSearching = NO;
		self.isOverlayShowing = NO;
		
		coverArtView = [[AsynchronousImageView alloc] init];
		coverArtView.isLarge = NO;
		[self.contentView addSubview:coverArtView];
		
		songNameScrollView = [[UIScrollView alloc] init];
		songNameScrollView.frame = CGRectMake(65, 0, 255, 60);
		songNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		songNameScrollView.showsVerticalScrollIndicator = NO;
		songNameScrollView.showsHorizontalScrollIndicator = NO;
		songNameScrollView.userInteractionEnabled = NO;
		songNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:songNameScrollView];
		
		songNameLabel = [[UILabel alloc] init];
		songNameLabel.backgroundColor = [UIColor clearColor];
		songNameLabel.textAlignment = NSTextAlignmentLeft; // default
		songNameLabel.font = ISMSSongFont;
		[songNameScrollView addSubview:songNameLabel];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = NSTextAlignmentLeft; // default
		artistNameLabel.font = ISMSRegularFont(15);
		[songNameScrollView addSubview:artistNameLabel];
	}
	
	return self;
}

- (void)layoutSubviews 
{
    [super layoutSubviews];
	
	self.coverArtView.frame = CGRectMake(0, 0, 60, 60);
	
	// Automatically set the width based on the width of the text
	self.songNameLabel.frame = CGRectMake(0, 0, 225, 35);
    CGSize expectedLabelSize = [self.songNameLabel.text boundingRectWithSize:CGSizeMake(1000,35)
                                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                                  attributes:@{NSFontAttributeName:self.songNameLabel.font}
                                                                     context:nil].size;
	CGRect frame = self.songNameLabel.frame;
	frame.size.width = expectedLabelSize.width;
	self.songNameLabel.frame = frame;
	
	self.artistNameLabel.frame = CGRectMake(0, 35, 225, 20);
    expectedLabelSize = [self.artistNameLabel.text boundingRectWithSize:CGSizeMake(1000,20)
                                                                options:NSStringDrawingUsesLineFragmentOrigin
                                                             attributes:@{NSFontAttributeName:self.artistNameLabel.font}
                                                                context:nil].size;
	frame = self.artistNameLabel.frame;
	frame.size.width = expectedLabelSize.width;
	self.artistNameLabel.frame = frame;
}

- (void)dealloc
{
	coverArtView.delegate = nil;
}

#pragma mark - Overlay

- (void)showOverlay
{	
	[super showOverlay];
    
    self.overlayView.downloadButton.alpha = (float)!settingsS.isOfflineMode;
	self.overlayView.downloadButton.enabled = !settingsS.isOfflineMode;
    
    if (!settingsS.isOfflineMode)
	{
		if ([[databaseS.songCacheDbQueue stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", self.md5] isEqualToString:@"YES"])
		{
			self.overlayView.downloadButton.alpha = .3;
			self.overlayView.downloadButton.enabled = NO;
		}
		else
		{
			self.overlayView.downloadButton.alpha = 1.;
			[self.overlayView.downloadButton addTarget:self action:@selector(downloadAction) forControlEvents:UIControlEventTouchUpInside];
			self.overlayView.downloadButton.enabled = YES;
		}
	}
    
    // If video, disable download button
    if ([[databaseS.songCacheDbQueue stringForQuery:@"SELECT isVideo FROM cachedSongs WHERE md5 = ?", self.md5] isEqualToString:@"YES"])
    {
        self.overlayView.downloadButton.alpha = .3;
        self.overlayView.downloadButton.enabled = NO;
    }
    
    if (!settingsS.isCacheUnlocked)
    {
        self.overlayView.downloadButton.enabled = NO;
    }
}

- (void)downloadAction
{
	if (self.isSearching) 
	{
		ISMSSong *aSong = [ISMSSong songFromDbRow:self.indexPath.row inTable:@"allSongsSearch" inDatabaseQueue:databaseS.allSongsDbQueue];
		[aSong addToCacheQueueDbQueue];
	}
	else 
	{
		ISMSSong *aSong = [ISMSSong songFromDbRow:self.indexPath.row inTable:@"allSongs" inDatabaseQueue:databaseS.allSongsDbQueue];
		[aSong addToCacheQueueDbQueue];
	}
	
	self.overlayView.downloadButton.alpha = .3;
	self.overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}

- (void)queueAction
{	
	NSString *tableName = self.isSearching ? @"allSongsSearch" : @"allSongs";
	ISMSSong *aSong = [ISMSSong songFromDbRow:self.indexPath.row inTable:tableName inDatabaseQueue:databaseS.allSongsDbQueue];
	
	[aSong addToCurrentPlaylistDbQueue];
	
	[self hideOverlay];
}

#pragma mark - Scrolling

- (void)scrollLabels
{	
	CGFloat scrollWidth = self.songNameLabel.frame.size.width > self.artistNameLabel.frame.size.width ? self.songNameLabel.frame.size.width : self.artistNameLabel.frame.size.width;
	if (scrollWidth > self.songNameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:scrollWidth/150.];
		self.songNameScrollView.contentOffset = CGPointMake(scrollWidth - self.songNameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	CGFloat scrollWidth = self.songNameLabel.frame.size.width > self.artistNameLabel.frame.size.width ? self.songNameLabel.frame.size.width : self.artistNameLabel.frame.size.width;
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:scrollWidth/150.];
	self.songNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
