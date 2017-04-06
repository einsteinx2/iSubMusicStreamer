//
//  SearchSongUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SearchSongUITableViewCell.h"
#import "CellOverlay.h"

@implementation SearchSongUITableViewCell

@synthesize mySong, row, coverArtView, songNameScrollView, songNameLabel, artistNameLabel;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
	{        
		coverArtView = [[AsynchronousImageView alloc] init];
        coverArtView.frame = CGRectMake(0, 0, 60, 60);
		coverArtView.isLarge = NO;
		[self.contentView addSubview:coverArtView];
		
		songNameScrollView = [[UIScrollView alloc] init];
        songNameScrollView.frame = CGRectMake(65, 0, 250, 60);
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
		[self.songNameScrollView addSubview:songNameLabel];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = NSTextAlignmentLeft; // default
		artistNameLabel.font = ISMSRegularFont(15);
		[self.songNameScrollView addSubview:artistNameLabel];
	}
	
	return self;
}

- (void)dealloc 
{
	coverArtView.delegate = nil;	
}

- (void)layoutSubviews
{
    [super layoutSubviews];
	
	// Automatically set the width based on the width of the text
	self.songNameLabel.frame = CGRectMake(0, 0, 250, 35);
    CGSize expectedLabelSize = [self.songNameLabel.text boundingRectWithSize:CGSizeMake(1000,35)
                                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                                  attributes:@{NSFontAttributeName:self.songNameLabel.font}
                                                                     context:nil].size;
	CGRect newFrame = self.songNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	self.songNameLabel.frame = newFrame;
	
	self.artistNameLabel.frame = CGRectMake(0, 35, 250, 20);
    expectedLabelSize = [self.artistNameLabel.text boundingRectWithSize:CGSizeMake(1000,20)
                                                              options:NSStringDrawingUsesLineFragmentOrigin
                                                           attributes:@{NSFontAttributeName:self.artistNameLabel.font}
                                                              context:nil].size;
	newFrame = self.artistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	self.artistNameLabel.frame = newFrame;
}

- (ISMSSong *)mySong
{
	@synchronized(self)
	{
		return mySong;
	}
}

- (void)setMySong:(ISMSSong *)aSong
{
	@synchronized(self)
	{
		mySong = [aSong copy];
		
		self.coverArtView.coverArtId = mySong.coverArtId;
		
		self.backgroundView = [[UIView alloc] init];
		if(row % 2 == 0)
		{
			if (mySong.isFullyCached)
				self.backgroundView.backgroundColor = [viewObjectsS currentLightColor];
			else
				self.backgroundView.backgroundColor = viewObjectsS.lightNormal;
		}
		else
		{
			if (mySong.isFullyCached)
				self.backgroundView.backgroundColor = [viewObjectsS currentDarkColor];
			else
				self.backgroundView.backgroundColor = viewObjectsS.darkNormal;
		}
		
		[self.songNameLabel setText:aSong.title];
		if (aSong.album)
			[self.artistNameLabel setText:[NSString stringWithFormat:@"%@ - %@", aSong.artist, aSong.album]];
		else
			[self.artistNameLabel setText:aSong.artist];
	}
}

#pragma mark - Overlay

- (void)showOverlay
{
	[super showOverlay];
	
	self.overlayView.downloadButton.alpha = (float)!settingsS.isOfflineMode;
	self.overlayView.downloadButton.enabled = !settingsS.isOfflineMode;
	
	if ((self.mySong.isFullyCached && !settingsS.isOfflineMode) || self.mySong.isVideo)
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
	[self.mySong addToCacheQueueDbQueue];
	
	self.overlayView.downloadButton.alpha = .3;
	self.overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}

- (void)queueAction
{	
	[self.mySong addToCurrentPlaylistDbQueue];
	
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
