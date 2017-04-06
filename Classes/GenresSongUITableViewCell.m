//
//  SongUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "GenresSongUITableViewCell.h"
#import "CellOverlay.h"

@implementation GenresSongUITableViewCell

@synthesize md5, trackNumberLabel, songNameScrollView, songNameLabel, artistNameLabel, songDurationLabel;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
	{		
		trackNumberLabel = [[UILabel alloc] init];
		trackNumberLabel.frame = CGRectMake(0, 4, 30, 41);
		trackNumberLabel.backgroundColor = [UIColor clearColor];
		trackNumberLabel.textAlignment = NSTextAlignmentCenter;
		trackNumberLabel.font = ISMSBoldFont(22);
		trackNumberLabel.adjustsFontSizeToFitWidth = YES;
		trackNumberLabel.minimumScaleFactor = 16.0 / trackNumberLabel.font.pointSize;
		[self.contentView addSubview:trackNumberLabel];
		
		songNameScrollView = [[UIScrollView alloc] init];
		songNameScrollView.frame = CGRectMake(35, 0, 235, 50);
		songNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		songNameScrollView.showsVerticalScrollIndicator = NO;
		songNameScrollView.showsHorizontalScrollIndicator = NO;
		songNameScrollView.userInteractionEnabled = NO;
		songNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:songNameScrollView];
		
		songNameLabel = [[UILabel alloc] init];
		songNameLabel.backgroundColor = [UIColor clearColor];
		songNameLabel.textAlignment = NSTextAlignmentLeft;
		songNameLabel.font = ISMSSongFont;
		[songNameScrollView addSubview:songNameLabel];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = NSTextAlignmentLeft;
		artistNameLabel.font = ISMSRegularFont(13);
		artistNameLabel.textColor = [UIColor colorWithWhite:.4 alpha:1];
		[songNameScrollView addSubview:artistNameLabel];
		
		songDurationLabel = [[UILabel alloc] init];
		songDurationLabel.frame = CGRectMake(270, 0, 45, 41);
		songDurationLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		songDurationLabel.backgroundColor = [UIColor clearColor];
		songDurationLabel.textAlignment = NSTextAlignmentRight;
		songDurationLabel.font = ISMSRegularFont(16);
		songDurationLabel.adjustsFontSizeToFitWidth = YES;
		songDurationLabel.minimumScaleFactor = 12.0 / songDurationLabel.font.pointSize;
		songDurationLabel.textColor = [UIColor grayColor];
		[self.contentView addSubview:songDurationLabel];
	}
	
	return self;
}


- (void)layoutSubviews 
{
    [super layoutSubviews];
	
	// Automatically set the width based on the width of the text
	self.songNameLabel.frame = CGRectMake(0, 0, 235, 37);
    CGSize expectedLabelSize = [self.songNameLabel.text boundingRectWithSize:CGSizeMake(1000,37)
                                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                                  attributes:@{NSFontAttributeName:self.songNameLabel.font}
                                                                     context:nil].size;
	CGRect newFrame = self.songNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	self.songNameLabel.frame = newFrame;
	
	self.artistNameLabel.frame = CGRectMake(0, 33, 235, 15);
    expectedLabelSize = [self.artistNameLabel.text boundingRectWithSize:CGSizeMake(1000,15)
                                                              options:NSStringDrawingUsesLineFragmentOrigin
                                                           attributes:@{NSFontAttributeName:self.artistNameLabel.font}
                                                              context:nil].size;
	newFrame = self.artistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	self.artistNameLabel.frame = newFrame;
}

#pragma mark - Overlay

- (void)showOverlay
{
	[super showOverlay];

	self.overlayView.downloadButton.alpha = (float)!settingsS.isOfflineMode;
	self.overlayView.downloadButton.enabled = !settingsS.isOfflineMode;
	
	if (!settingsS.isOfflineMode)
	{
		if ([[databaseS.songCacheDbQueue stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", self.md5] isEqualToString:@"YES"] ||
            [[databaseS.songCacheDbQueue stringForQuery:@"SELECT isVideo FROM cachedSongs WHERE md5 = ?", self.md5] isEqualToString:@"YES"])
		{
			self.overlayView.downloadButton.alpha = .3;
			self.overlayView.downloadButton.enabled = NO;
		}
	}
    
    if (!settingsS.isCacheUnlocked)
    {
        self.overlayView.downloadButton.enabled = NO;
    }
}

- (void)downloadAction
{
	[[ISMSSong songFromGenreDbQueue:md5] addToCacheQueueDbQueue];	
		
	self.overlayView.downloadButton.alpha = .3;
	self.overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}

- (void)queueAction
{
	//DLog(@"queueAction");
	[[ISMSSong songFromGenreDbQueue:md5] addToCurrentPlaylistDbQueue];
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	
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
		[UIView setAnimationDuration:self.songNameLabel.frame.size.width/150.];
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
