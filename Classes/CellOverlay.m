//
//  CellOverlay.m
//  iSub
//
//  Created by bbaron on 11/12/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CellOverlay.h"

@implementation CellOverlay

@synthesize downloadButton, queueButton, inputBlocker;

+ (CellOverlay*)cellOverlayWithTableCell:(UITableViewCell*)cell
{
	return [[CellOverlay alloc] initWithTableCell:cell];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

- (id)initWithTableCell:(UITableViewCell*)cell
{
	CGRect newFrame = cell.frame;
	newFrame.origin.x = 0;
	newFrame.origin.y = 0;
	if ((self = [super initWithFrame:newFrame]))
	{
			
		self.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:.85];
		self.alpha = 0.1;
		self.userInteractionEnabled = YES;
		
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		
		inputBlocker = [UIButton buttonWithType:UIButtonTypeCustom];
		inputBlocker.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[inputBlocker addTarget:cell action:@selector(blockerAction) forControlEvents:UIControlEventTouchUpInside];
		inputBlocker.frame = self.frame;
		inputBlocker.userInteractionEnabled = NO;
		[self addSubview:inputBlocker];
		
		downloadButton = [UIButton buttonWithType:UIButtonTypeCustom];
		downloadButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		downloadButton.alpha = 1.;
		[downloadButton addTarget:cell action:@selector(downloadAction) forControlEvents:UIControlEventTouchUpInside];
		downloadButton.userInteractionEnabled = NO;
		downloadButton.frame = CGRectMake(30, 5, 120, 34);
		float width = self.frame.size.width == 320 ? 90.0 : (self.frame.size.width / 3.0) - 50.0;
		downloadButton.center = CGPointMake(width, self.frame.size.height / 2);
        [downloadButton setTitle:@"Download" forState:UIControlStateNormal];
        [downloadButton setTitleColor:ISMSHeaderButtonColor forState:UIControlStateNormal];
        [downloadButton setBackgroundColor:[UIColor whiteColor]];
        downloadButton.layer.cornerRadius = 3.;
        downloadButton.layer.masksToBounds = YES;
		[inputBlocker addSubview:downloadButton];
        
        // If the cache feature is not unlocked, don't allow the user to cache songs
        if (!settingsS.isCacheUnlocked)
        {
            downloadButton.enabled = NO;
        }
		
		queueButton = [UIButton buttonWithType:UIButtonTypeCustom];
		queueButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		queueButton.alpha = 1.;
		[queueButton addTarget:cell action:@selector(queueAction) forControlEvents:UIControlEventTouchUpInside];
		queueButton.userInteractionEnabled = NO;
		queueButton.frame = CGRectMake(170, 5, 120, 34);
		width = self.frame.size.width == 320 ? 230.0 : ((self.frame.size.width / 3.0) * 2.0) + 40.0;
		queueButton.center = CGPointMake(width, self.frame.size.height / 2);
        [queueButton setTitle:@"Queue" forState:UIControlStateNormal];
        [queueButton setTitleColor:ISMSHeaderButtonColor forState:UIControlStateNormal];
        [queueButton setBackgroundColor:[UIColor whiteColor]];
        queueButton.layer.cornerRadius = 3.;
        queueButton.layer.masksToBounds = YES;
		[inputBlocker addSubview:queueButton];
        
        // If the playlist feature is not unlocked, don't allow the user to queue songs
        if (!settingsS.isPlaylistUnlocked)
        {
            queueButton.enabled = NO;
        }
	}
	return self;
}

#pragma clang diagnostic pop

- (void)enableButtons
{
	self.inputBlocker.userInteractionEnabled = YES;
	self.downloadButton.userInteractionEnabled = YES;
	self.queueButton.userInteractionEnabled = YES;
}

@end

