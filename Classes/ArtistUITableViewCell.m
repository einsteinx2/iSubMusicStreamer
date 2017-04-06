//
//  ArtistUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 5/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ArtistUITableViewCell.h"
#import "CellOverlay.h"

@implementation ArtistUITableViewCell

@synthesize artistNameScrollView, artistNameLabel, myArtist;

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
	self.artistNameLabel.frame = CGRectMake(0, 0, 280, 44);
    CGSize expectedLabelSize = [self.artistNameLabel.text boundingRectWithSize:CGSizeMake(1000,44)
                                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                                  attributes:@{NSFontAttributeName:self.artistNameLabel.font}
                                                                     context:nil].size;
	//DLog(@"%@: size: %@", artistNameLabel.text, NSStringFromCGSize(expectedLabelSize));
	
	if (expectedLabelSize.width > 280)
	{
		CGRect frame = self.artistNameLabel.frame;
		frame.size.width = expectedLabelSize.width;
		self.artistNameLabel.frame = frame;
	}
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
	[databaseS downloadAllSongs:self.myArtist.artistId artist:self.myArtist];
	
	self.overlayView.downloadButton.alpha = .3;
	self.overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}

- (void)queueAction
{
	[databaseS queueAllSongs:self.myArtist.artistId artist:self.myArtist];
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
	[UIView setAnimationDuration:self.artistNameLabel.frame.size.width/150.];
	self.artistNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}


@end
