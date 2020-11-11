//
//  PlaylistSongUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CurrentPlaylistSongSmallUITableViewCell.h"
#import "Defines.h"

@implementation CurrentPlaylistSongSmallUITableViewCell

#pragma mark - Lifecycle

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.backgroundColor = [UIColor clearColor];
		self.backgroundView.backgroundColor = [UIColor clearColor];
		self.contentView.backgroundColor = [UIColor clearColor];
		
		_numberLabel = [[UILabel alloc] init];
		_numberLabel.frame = CGRectMake(2, 0, 40, 45);
		_numberLabel.backgroundColor = [UIColor clearColor];
		_numberLabel.textAlignment = NSTextAlignmentCenter;
		_numberLabel.textColor = [UIColor whiteColor];
        _numberLabel.highlightedTextColor = [UIColor blackColor];
		_numberLabel.font = ISMSBoldFont(24);
		_numberLabel.adjustsFontSizeToFitWidth = YES;
		_numberLabel.minimumScaleFactor = 12.0 / _numberLabel.font.pointSize;
		[self.contentView addSubview:_numberLabel];
		
        _nowPlayingImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"playing-cell-icon-white.png"]];
        _nowPlayingImageView.highlightedImage = [UIImage imageNamed:@"playing-cell-icon.png"];
		_nowPlayingImageView.center = _numberLabel.center;
		_nowPlayingImageView.hidden = YES;
		[self.contentView addSubview:_nowPlayingImageView];
		
		_songNameLabel = [[UILabel alloc] init];
		_songNameLabel.frame = CGRectMake(45, 0, 235, 30);
		_songNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		_songNameLabel.backgroundColor = [UIColor clearColor];
		_songNameLabel.textAlignment = NSTextAlignmentLeft; // default
		_songNameLabel.textColor = [UIColor whiteColor];
        _songNameLabel.highlightedTextColor = [UIColor blackColor];
		_songNameLabel.font = ISMSSongFont;
		[self.contentView addSubview:_songNameLabel];
		
		_artistNameLabel = [[UILabel alloc] init];
		_artistNameLabel.frame = CGRectMake(45, 27, 235, 15);
		_artistNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		_artistNameLabel.backgroundColor = [UIColor clearColor];
        _artistNameLabel.highlightedTextColor = [UIColor blackColor];
		_artistNameLabel.textAlignment = NSTextAlignmentLeft; // default
		_artistNameLabel.textColor = [UIColor whiteColor];
		_artistNameLabel.font = ISMSRegularFont(12);
		[self.contentView addSubview:_artistNameLabel];
		
		_durationLabel = [[UILabel alloc] init];
		_durationLabel.frame = CGRectMake(270, 0, 45, 41);
		_durationLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		_durationLabel.backgroundColor = [UIColor clearColor];
		_durationLabel.textAlignment = NSTextAlignmentRight; // default
		_durationLabel.textColor = [UIColor whiteColor];
        _durationLabel.highlightedTextColor = [UIColor blackColor];
		_durationLabel.font = ISMSRegularFont(16);
		_durationLabel.adjustsFontSizeToFitWidth = YES;
		_durationLabel.minimumScaleFactor = 12.0 / _durationLabel.font.pointSize;
		[self.contentView addSubview:_durationLabel];
	}
	
	return self;
}

@end
