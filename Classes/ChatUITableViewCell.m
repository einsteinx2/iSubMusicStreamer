//
//  ChatUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ChatUITableViewCell.h"

@implementation ChatUITableViewCell

@synthesize userNameLabel, messageLabel;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{
		userNameLabel = [[UILabel alloc] init];
		userNameLabel.frame = CGRectMake(0, 0, 320, 20);
		userNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		userNameLabel.textAlignment = NSTextAlignmentCenter; // default
		userNameLabel.backgroundColor = [UIColor blackColor];
		userNameLabel.alpha = .65;
		userNameLabel.font = ISMSBoldFont(10);
		userNameLabel.textColor = [UIColor whiteColor];
		[self.contentView addSubview:userNameLabel];
		
		messageLabel = [[UILabel alloc] init];
		messageLabel.frame = CGRectMake(5, 20, 310, 55);
		messageLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		messageLabel.textAlignment = NSTextAlignmentLeft; // default
		messageLabel.backgroundColor = [UIColor clearColor];
		messageLabel.font = ISMSRegularFont(20);
		messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
		messageLabel.numberOfLines = 0;
		[self.contentView addSubview:messageLabel];
	}
	
	return self;
}


- (void)layoutSubviews
{
    [super layoutSubviews];
		
	// Automatically set the height based on the height of the message text
    CGSize expectedLabelSize = [self.messageLabel.text boundingRectWithSize:CGSizeMake(310,CGFLOAT_MAX)
                                                                    options:NSStringDrawingUsesLineFragmentOrigin
                                                                 attributes:@{NSFontAttributeName:self.messageLabel.font}
                                                                    context:nil].size;
	if (expectedLabelSize.height < 40)
		expectedLabelSize.height = 40;
	CGRect newFrame = self.messageLabel.frame;
	newFrame.size.height = expectedLabelSize.height;
	self.messageLabel.frame = newFrame;
}

#pragma mark - Overlay

- (void) hideOverlay
{
	return;
}

- (void) showOverlay
{
	return;
}

@end
