//
//  AllAlbumsUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "AllAlbumsUITableViewCell.h"
#import "CellOverlay.h"
#import "AsynchronousImageView.h"

@implementation AllAlbumsUITableViewCell

@synthesize myId, myArtist, coverArtView, albumNameScrollView, albumNameLabel, artistNameLabel;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{
		coverArtView = [[AsynchronousImageView alloc] init];
		coverArtView.isLarge = NO;
		[self.contentView addSubview:coverArtView];
		
		albumNameScrollView = [[UIScrollView alloc] init];
		albumNameScrollView.frame = CGRectMake(65, 0, 250, 60);
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
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = NSTextAlignmentLeft; // default
		artistNameLabel.font = ISMSRegularFont(15);
		[albumNameScrollView addSubview:artistNameLabel];
	}
	
	return self;
}

- (void)layoutSubviews 
{
    [super layoutSubviews];
	
	self.coverArtView.frame = CGRectMake(0, 0, 60, 60);
	
	// Automatically set the width based on the width of the text
	self.albumNameLabel.frame = CGRectMake(0, 0, 230, 35);
    CGSize expectedLabelSize = [self.albumNameLabel.text boundingRectWithSize:CGSizeMake(1000,35)
                                                                      options:NSStringDrawingUsesLineFragmentOrigin
                                                                   attributes:@{NSFontAttributeName:self.albumNameLabel.font}
                                                                      context:nil].size;
	CGRect frame = self.albumNameLabel.frame;
	frame.size.width = expectedLabelSize.width;
	self.albumNameLabel.frame = frame;
	
	self.artistNameLabel.frame = CGRectMake(0, 35, 230, 20);
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
	CGFloat scrollWidth = self.albumNameLabel.frame.size.width > self.artistNameLabel.frame.size.width ? self.albumNameLabel.frame.size.width : self.artistNameLabel.frame.size.width;
	if (scrollWidth > self.albumNameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:self.albumNameLabel.frame.size.width/150.];
		self.albumNameScrollView.contentOffset = CGPointMake(scrollWidth - self.albumNameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	CGFloat scrollWidth = self.albumNameLabel.frame.size.width > self.artistNameLabel.frame.size.width ? self.albumNameLabel.frame.size.width : self.artistNameLabel.frame.size.width;
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:scrollWidth/150.];
	self.albumNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
