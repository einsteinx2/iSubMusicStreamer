//
//  ChatUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ChatUITableViewCell.h"
#import "Defines.h"

@implementation ChatUITableViewCell

#pragma mark - Lifecycle

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier  {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])  {
		_userNameLabel = [[UILabel alloc] init];
		_userNameLabel.frame = CGRectMake(0, 0, 320, 20);
		_userNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		_userNameLabel.textAlignment = NSTextAlignmentCenter; // default
		_userNameLabel.backgroundColor = [UIColor blackColor];
		_userNameLabel.alpha = .65;
		_userNameLabel.font = ISMSBoldFont(10);
		_userNameLabel.textColor = [UIColor whiteColor];
		[self.contentView addSubview:_userNameLabel];
		
		_messageLabel = [[UILabel alloc] init];
		_messageLabel.frame = CGRectMake(5, 20, 310, 55);
		_messageLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		_messageLabel.textAlignment = NSTextAlignmentLeft; // default
		_messageLabel.backgroundColor = [UIColor clearColor];
		_messageLabel.font = ISMSRegularFont(20);
		_messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
		_messageLabel.numberOfLines = 0;
		[self.contentView addSubview:_messageLabel];
	}
	
	return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
		
	// Automatically set the height based on the height of the message text
    CGSize expectedLabelSize = [self.messageLabel.text boundingRectWithSize:CGSizeMake(310,CGFLOAT_MAX)
                                                                    options:NSStringDrawingUsesLineFragmentOrigin
                                                                 attributes:@{NSFontAttributeName:self.messageLabel.font}
                                                                    context:nil].size;
    if (expectedLabelSize.height < 40) expectedLabelSize.height = 40;
	CGRect newFrame = self.messageLabel.frame;
	newFrame.size.height = expectedLabelSize.height;
	self.messageLabel.frame = newFrame;
}

@end
