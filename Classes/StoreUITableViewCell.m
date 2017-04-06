//
//  StoreUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "StoreUITableViewCell.h"
#import "MKStoreManager.h"

@interface StoreUITableViewCell ()
{
    __strong SKProduct *_myProduct;
}
@end

@implementation StoreUITableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{		
		_titleLabel = [[UILabel alloc] init];
		_titleLabel.frame = CGRectMake(10, 10, 250, 25);
		_titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		_titleLabel.font = ISMSBoldFont(20);
		_titleLabel.textColor = [UIColor blackColor];
		_titleLabel.textAlignment = NSTextAlignmentLeft;
		[self.contentView addSubview:_titleLabel];
		
		_descLabel = [[UILabel alloc] init];
		_descLabel.frame = CGRectMake(10, 40, 310, 100);
		_descLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		_descLabel.font = ISMSRegularFont(14);
		_descLabel.textColor = [UIColor grayColor];
		_descLabel.textAlignment = NSTextAlignmentLeft;
		_descLabel.numberOfLines = 0;
		[self.contentView addSubview:_descLabel];
		
		_priceLabel = [[UILabel alloc] init];
		_priceLabel.frame = CGRectMake(250, 10, 60, 20);
		_priceLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		_priceLabel.font = ISMSBoldFont(20);
		_priceLabel.textColor = [UIColor redColor];
		_priceLabel.textAlignment = NSTextAlignmentRight;
		_priceLabel.adjustsFontSizeToFitWidth = YES;
		[self.contentView addSubview:_priceLabel];
	}
	
	return self;
}

- (SKProduct *)myProduct
{
	@synchronized(self)
	{
		return _myProduct;
	}
}

- (void)setMyProduct:(SKProduct*)product
{
	@synchronized(self)
	{
		_myProduct = product;
		
		self.titleLabel.text = [_myProduct localizedTitle];
		self.descLabel.text = [_myProduct localizedDescription];
		
		if ([MKStoreManager isFeaturePurchased:[_myProduct productIdentifier]])
		{
			self.priceLabel.textColor = [UIColor colorWithRed:0.0 green:.66 blue:0.0 alpha:1.0];
			self.priceLabel.text = @"Unlocked";
			
			self.contentView.alpha = .40;
		}
		else
		{
			NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
			[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
			[numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
			[numberFormatter setLocale:_myProduct.priceLocale];
			self.priceLabel.text = [numberFormatter stringFromNumber:_myProduct.price];
		}
	}
}

@end
