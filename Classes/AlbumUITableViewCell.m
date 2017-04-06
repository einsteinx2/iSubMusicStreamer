//
//  AlbumUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "AlbumUITableViewCell.h"
#import "CellOverlay.h"

@implementation AlbumUITableViewCell

@synthesize myId, myArtist, coverArtView, albumNameScrollView, albumNameLabel;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{
		myId = nil;
		myArtist = nil;
		
		self.isOverlayShowing = NO;
		self.isIndexShowing = NO;
		
		coverArtView = [[AsynchronousImageView alloc] init];
		coverArtView.isLarge = NO;
		[self.contentView addSubview:coverArtView];
		
		albumNameScrollView = [[UIScrollView alloc] init];
		NSUInteger width;
		if (self.isIndexShowing)
			width = 220;
		else
			width = 250;
		albumNameScrollView.frame = CGRectMake(65, 0, width, 60);
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
		[self.albumNameScrollView addSubview:albumNameLabel];
	}
	
	return self;
}

- (void)layoutSubviews 
{	
    [super layoutSubviews];
	
	// Automatically set the width based on the width of the text
	self.albumNameLabel.frame = CGRectMake(0, 0, 230, 60);
    CGSize expectedLabelSize = [albumNameLabel.text boundingRectWithSize:CGSizeMake(1000,60)
                                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                                              attributes:@{NSFontAttributeName:albumNameLabel.font}
                                                                 context:nil].size;
    
	CGRect frame = self.albumNameLabel.frame;
	frame.size.width = expectedLabelSize.width;
	self.albumNameLabel.frame = frame;
	
	self.coverArtView.frame = CGRectMake(0, 0, 60, 60);
}

- (void)dealloc 
{
	self.coverArtView.delegate = nil;
	/*[coverArtView release]; coverArtView = nil;
	[albumNameScrollView release]; albumNameScrollView = nil;
	[albumNameLabel release]; albumNameLabel = nil;
	
	[myId release]; myId = nil;
	[myArtist release]; myArtist = nil;
	
    [super dealloc];*/
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

- (void)downloadAction
{
	[databaseS downloadAllSongs:self.myId artist:self.myArtist];
	
	self.overlayView.downloadButton.alpha = .3;
	self.overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}

- (void)queueAction
{
	[databaseS queueAllSongs:self.myId artist:self.myArtist];
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
		[UIView setAnimationDuration:self.albumNameLabel.frame.size.width/150.];
		self.albumNameScrollView.contentOffset = CGPointMake(self.albumNameLabel.frame.size.width - self.albumNameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:self.albumNameLabel.frame.size.width/150.];
	self.albumNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
