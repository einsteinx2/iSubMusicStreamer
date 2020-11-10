//
//  PlaylistSongUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "PlaylistSongUITableViewCell.h"
#import "CellOverlay.h"
#import "AsynchronousImageView.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "SavedSettings.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"

@implementation PlaylistSongUITableViewCell

@synthesize coverArtView, cachedIndicatorView, numberLabel, nameScrollView, songNameLabel, artistNameLabel, mySong;

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{		
		coverArtView = [[AsynchronousImageView alloc] init];
		coverArtView.isLarge = NO;
		[self.contentView addSubview:coverArtView];
        
        cachedIndicatorView = [[CellCachedIndicatorView alloc] initWithSize:20];
        [self.contentView addSubview:cachedIndicatorView];
		
		numberLabel = [[UILabel alloc] init];
		numberLabel.backgroundColor = [UIColor clearColor];
		numberLabel.textAlignment = NSTextAlignmentCenter;
		numberLabel.font = ISMSBoldFont(30);
		numberLabel.adjustsFontSizeToFitWidth = YES;
        numberLabel.minimumScaleFactor = 12.0 / numberLabel.font.pointSize;
		[self.contentView addSubview:numberLabel];
		
		nameScrollView = [[UIScrollView alloc] init];
		nameScrollView.frame = CGRectMake(105, 0, 205, 60);
		nameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		nameScrollView.showsVerticalScrollIndicator = NO;
		nameScrollView.showsHorizontalScrollIndicator = NO;
		nameScrollView.userInteractionEnabled = NO;
		nameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:nameScrollView];
		
		songNameLabel = [[UILabel alloc] init];
		songNameLabel.backgroundColor = [UIColor clearColor];
		songNameLabel.textAlignment = NSTextAlignmentLeft; // default
		songNameLabel.font = ISMSSongFont;
		[nameScrollView addSubview:songNameLabel];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = NSTextAlignmentLeft; // default
		artistNameLabel.font = ISMSRegularFont(15);
		[nameScrollView addSubview:artistNameLabel];
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
	
	self.coverArtView.frame = CGRectMake(0, 0, 60, 60);
	self.numberLabel.frame = CGRectMake(62, 0, 40, 60);
	
	// Automatically set the width based on the width of the text
	self.songNameLabel.frame = CGRectMake(0, 0, 205, 40);
    CGSize expectedLabelSize = [self.songNameLabel.text boundingRectWithSize:CGSizeMake(1000,40)
                                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                                  attributes:@{NSFontAttributeName:self.songNameLabel.font}
                                                                     context:nil].size;
	CGRect newFrame = self.songNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	self.songNameLabel.frame = newFrame;
	
	self.artistNameLabel.frame = CGRectMake(0, 37, 205, 20);
    expectedLabelSize = [self.artistNameLabel.text boundingRectWithSize:CGSizeMake(1000,20)
                                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                                  attributes:@{NSFontAttributeName:self.artistNameLabel.font}
                                                                     context:nil].size;
	newFrame = self.artistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	self.artistNameLabel.frame = newFrame;
}

#pragma mark - Overlay

/*- (void)toggleDelete
{
	[[viewObjectsS.listOfPlaylistSongs objectAtIndexSafe:indexPath.row] addToCacheQueue];
	
	overlayView.downloadButton.alpha = .3;
	overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}*/

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
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	
	[self hideOverlay];
}

#pragma mark - Scrolling

- (void)scrollLabels
{
	CGFloat scrollWidth = self.songNameLabel.frame.size.width > self.artistNameLabel.frame.size.width ? self.songNameLabel.frame.size.width : self.artistNameLabel.frame.size.width;
	if (scrollWidth > self.nameScrollView.frame.size.width)
	{
        [UIView animateWithDuration:scrollWidth/150. animations:^{
            self.nameScrollView.contentOffset = CGPointMake(scrollWidth - self.nameScrollView.frame.size.width + 10, 0);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:scrollWidth/150. animations:^{
                self.nameScrollView.contentOffset = CGPointZero;
            }];
        }];
	}
}

@end
