//
//  PlayingUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CacheQueueSongUITableViewCell.h"

@implementation CacheQueueSongUITableViewCell

@synthesize coverArtView, cacheInfoLabel, nameScrollView, songNameLabel, artistNameLabel, md5;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{
		md5 = nil;
		
		coverArtView = [[AsynchronousImageView alloc] init];
		coverArtView.isLarge = NO;
		[self.contentView addSubview:coverArtView];
		
		cacheInfoLabel = [[UILabel alloc] init];
		cacheInfoLabel.frame = CGRectMake(0, 0, 320, 20);
		cacheInfoLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		cacheInfoLabel.textAlignment = NSTextAlignmentCenter; // default
		cacheInfoLabel.backgroundColor = [UIColor blackColor];
		cacheInfoLabel.alpha = .65;
		cacheInfoLabel.font = ISMSBoldFont(10);
		cacheInfoLabel.textColor = [UIColor whiteColor];
		[self.contentView addSubview:cacheInfoLabel];
		
		nameScrollView = [[UIScrollView alloc] init];
		nameScrollView.frame = CGRectMake(65, 20, 245, 55);
		nameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		nameScrollView.backgroundColor = [UIColor clearColor];
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

- (void)toggleDelete
{
    if (!self.md5)
        return;
    
	if (self.isDelete)
	{
		[viewObjectsS.multiDeleteList removeObject:self.md5];
		[NSNotificationCenter postNotificationToMainThreadWithName:@"hideDeleteButton"];
		self.deleteToggleImage.image = [UIImage imageNamed:@"unselected.png"];
	}
	else
	{
		[viewObjectsS.multiDeleteList addObject:self.md5];
		[NSNotificationCenter postNotificationToMainThreadWithName:@"showDeleteButton"];
		self.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
	}
	
	self.isDelete = !self.isDelete;
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

#pragma mark - Scrolling

- (void)scrollLabels
{
	CGFloat scrollWidth = self.songNameLabel.frame.size.width > self.artistNameLabel.frame.size.width ? self.songNameLabel.frame.size.width : self.artistNameLabel.frame.size.width;
	
	if (scrollWidth > self.nameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:scrollWidth/(float)150];
		self.nameScrollView.contentOffset = CGPointMake(scrollWidth - self.nameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	CGFloat scrollWidth = self.songNameLabel.frame.size.width > self.artistNameLabel.frame.size.width ? self.songNameLabel.frame.size.width : self.artistNameLabel.frame.size.width;
	
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:scrollWidth/(float)150];
	self.nameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
