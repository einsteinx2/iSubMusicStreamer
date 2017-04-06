//
//  MenuTableViewCell.m
//  StackScrollView
//
//  Created by Aaron Brethorst on 5/15/11.
//  Copyright 2011 Structlab LLC. All rights reserved.
//

#import "MenuTableViewCell.h"

@implementation MenuTableViewCell
@synthesize glowView;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
	{
		self.clipsToBounds = YES;
		
		UIView* bgView = [[UIView alloc] init];
		bgView.backgroundColor = [UIColor colorWithWhite:0.f alpha:0.25f];
		self.selectedBackgroundView = bgView;
        
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.backgroundView = [[UIView alloc] init];
        self.backgroundView.backgroundColor = [UIColor clearColor];
				
		self.textLabel.font = ISMSBoldFont([UIFont systemFontSize]);
		self.textLabel.shadowOffset = CGSizeMake(0, 2);
		self.textLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.25];
        self.textLabel.backgroundColor = [UIColor clearColor];
		
		self.imageView.contentMode = UIViewContentModeCenter;
		
		UIView *topLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, 1)];
		topLine.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.25];
		[self.textLabel.superview addSubview:topLine];
		
		UIView *bottomLine = [[UIView alloc] initWithFrame:CGRectMake(0, 43, self.bounds.size.width, 1)];
		bottomLine.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25];
		[self.textLabel.superview addSubview:bottomLine];
		
		glowView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 30, 43)];
		glowView.image = [UIImage imageNamed:@"glow.png"];
		glowView.hidden = YES;
		glowView.alpha = 0.3;
		[self addSubview:glowView];
	}
	return self;
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	
	self.textLabel.frame = CGRectMake(75, 0, self.bounds.size.width - 75, self.bounds.size.height);
	self.imageView.frame = CGRectMake(0, 0, 70, self.bounds.size.height);
}

- (void)setSelected:(BOOL)sel animated:(BOOL)animated
{
	[super setSelected:sel animated:animated];
		
	if (sel)
	{
		self.textLabel.textColor = [UIColor whiteColor];
	}
	else
	{
		self.textLabel.textColor = [UIColor colorWithRed:(188.f/255.f) green:(188.f/255.f) blue:(188.f/255.f) alpha:1.f];
	}
}

@end
