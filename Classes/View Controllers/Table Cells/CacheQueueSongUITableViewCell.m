//
//  PlayingUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CacheQueueSongUITableViewCell.h"
#import "AsynchronousImageView.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "EX2Kit.h"

@implementation CacheQueueSongUITableViewCell

#pragma mark - Lifecycle

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier  {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
		_md5 = nil;
		
		_coverArtView = [[AsynchronousImageView alloc] init];
		_coverArtView.isLarge = NO;
		[self.contentView addSubview:_coverArtView];
		
		_cacheInfoLabel = [[UILabel alloc] init];
		_cacheInfoLabel.frame = CGRectMake(0, 0, 320, 20);
		_cacheInfoLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		_cacheInfoLabel.textAlignment = NSTextAlignmentCenter; // default
		_cacheInfoLabel.backgroundColor = [UIColor blackColor];
		_cacheInfoLabel.alpha = .65;
		_cacheInfoLabel.font = ISMSBoldFont(10);
        _cacheInfoLabel.textColor = [UIColor labelColor];
		[self.contentView addSubview:_cacheInfoLabel];
		
		_nameScrollView = [[UIScrollView alloc] init];
		_nameScrollView.frame = CGRectMake(65, 20, 245, 55);
		_nameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		_nameScrollView.backgroundColor = [UIColor clearColor];
		_nameScrollView.showsVerticalScrollIndicator = NO;
		_nameScrollView.showsHorizontalScrollIndicator = NO;
		_nameScrollView.userInteractionEnabled = NO;
		_nameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:_nameScrollView];
		
		_songNameLabel = [[UILabel alloc] init];
		_songNameLabel.backgroundColor = [UIColor clearColor];
		_songNameLabel.textAlignment = NSTextAlignmentLeft; // default
		_songNameLabel.font = ISMSSongFont;
        _songNameLabel.textColor = [UIColor labelColor];
		[_nameScrollView addSubview:_songNameLabel];
		
		_artistNameLabel = [[UILabel alloc] init];
		_artistNameLabel.backgroundColor = [UIColor clearColor];
		_artistNameLabel.textAlignment = NSTextAlignmentLeft; // default
		_artistNameLabel.font = ISMSRegularFont(15);
        _artistNameLabel.textColor = [UIColor labelColor];
		[_nameScrollView addSubview:_artistNameLabel];
	}
	
	return self;
}

- (void)dealloc {
	_coverArtView.delegate = nil;
}

- (void)layoutSubviews {
    [super layoutSubviews];
	
	//self.deleteToggleImage.frame = CGRectMake(4, 28.5, 23, 23);
	self.coverArtView.frame = CGRectMake(0, 20, 60, 60);
	
	// Automatically set the width based on the width of the text
	self.songNameLabel.frame = CGRectMake(0, 0, 245, 35);
    CGSize expectedLabelSize = [self.songNameLabel.text boundingRectWithSize:CGSizeMake(1000,35)
                                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                                  attributes:@{NSFontAttributeName:self.songNameLabel.font}
                                                                     context:nil].size;
	CGRect newFrame = self.songNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	self.songNameLabel.frame = newFrame;
	
	self.artistNameLabel.frame = CGRectMake(0, 35, 245, 20);
    expectedLabelSize = [self.artistNameLabel.text boundingRectWithSize:CGSizeMake(1000,20)
                                                                options:NSStringDrawingUsesLineFragmentOrigin
                                                             attributes:@{NSFontAttributeName:self.artistNameLabel.font}
                                                                context:nil].size;
	newFrame = self.artistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	self.artistNameLabel.frame = newFrame;
}

- (void)toggleDelete {
    if (!self.md5)
        return;
    
//	if (self.isDelete)
//	{
//		[viewObjectsS.multiDeleteList removeObject:self.md5];
//		[NSNotificationCenter postNotificationToMainThreadWithName:@"hideDeleteButton"];
//		self.deleteToggleImage.image = [UIImage imageNamed:@"unselected.png"];
//	}
//	else
//	{
//		[viewObjectsS.multiDeleteList addObject:self.md5];
//		[NSNotificationCenter postNotificationToMainThreadWithName:@"showDeleteButton"];
//		self.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
//	}
//	
//	self.isDelete = !self.isDelete;
}

#pragma mark - Scrolling

- (void)scrollLabels {
	CGFloat scrollWidth = self.songNameLabel.frame.size.width > self.artistNameLabel.frame.size.width ? self.songNameLabel.frame.size.width : self.artistNameLabel.frame.size.width;
	if (scrollWidth > self.nameScrollView.frame.size.width) {
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
