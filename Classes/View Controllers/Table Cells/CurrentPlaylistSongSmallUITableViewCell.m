//
//  PlaylistSongUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CurrentPlaylistSongSmallUITableViewCell.h"

@implementation CurrentPlaylistSongSmallUITableViewCell

@synthesize numberLabel, songNameLabel, artistNameLabel, durationLabel, nowPlayingImageView;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{
        self.backgroundColor = [UIColor clearColor];
		self.backgroundView.backgroundColor = [UIColor clearColor];
		self.contentView.backgroundColor = [UIColor clearColor];
		
		numberLabel = [[UILabel alloc] init];
		numberLabel.frame = CGRectMake(2, 0, 40, 45);
		numberLabel.backgroundColor = [UIColor clearColor];
		numberLabel.textAlignment = NSTextAlignmentCenter;
		numberLabel.textColor = [UIColor whiteColor];
        numberLabel.highlightedTextColor = [UIColor blackColor];
		numberLabel.font = ISMSBoldFont(24);
		numberLabel.adjustsFontSizeToFitWidth = YES;
		numberLabel.minimumScaleFactor = 12.0 / numberLabel.font.pointSize;
		[self.contentView addSubview:numberLabel];
		
		nowPlayingImageView = [[UIImageView alloc] initWithImage:self.nowPlayingImageWhite];
        nowPlayingImageView.highlightedImage = self.nowPlayingImageBlack;
		nowPlayingImageView.center = numberLabel.center;
		nowPlayingImageView.hidden = YES;
		[self.contentView addSubview:nowPlayingImageView];
		
		songNameLabel = [[UILabel alloc] init];
		songNameLabel.frame = CGRectMake(45, 0, 235, 30);
		songNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		songNameLabel.backgroundColor = [UIColor clearColor];
		songNameLabel.textAlignment = NSTextAlignmentLeft; // default
		songNameLabel.textColor = [UIColor whiteColor];
        songNameLabel.highlightedTextColor = [UIColor blackColor];
		songNameLabel.font = ISMSSongFont;
		[self.contentView addSubview:songNameLabel];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.frame = CGRectMake(45, 27, 235, 15);
		artistNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		artistNameLabel.backgroundColor = [UIColor clearColor];
        artistNameLabel.highlightedTextColor = [UIColor blackColor];
		artistNameLabel.textAlignment = NSTextAlignmentLeft; // default
		artistNameLabel.textColor = [UIColor whiteColor];
		artistNameLabel.font = ISMSRegularFont(12);
		[self.contentView addSubview:artistNameLabel];
		
		durationLabel = [[UILabel alloc] init];
		durationLabel.frame = CGRectMake(270, 0, 45, 41);
		durationLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		durationLabel.backgroundColor = [UIColor clearColor];
		durationLabel.textAlignment = NSTextAlignmentRight; // default
		durationLabel.textColor = [UIColor whiteColor];
        durationLabel.highlightedTextColor = [UIColor blackColor];
		durationLabel.font = ISMSRegularFont(16);
		durationLabel.adjustsFontSizeToFitWidth = YES;
		durationLabel.minimumScaleFactor = 12.0 / durationLabel.font.pointSize;
		[self.contentView addSubview:durationLabel];
	}
	
	return self;
}


#pragma mark - Overlay

- (void)showOverlay
{
	return;
}

- (void)hideOverlay
{
	return;
}

@end
