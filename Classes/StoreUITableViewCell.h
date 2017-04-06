//
//  StoreUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <StoreKit/StoreKit.h>

@interface StoreUITableViewCell : UITableViewCell 

@property (strong) SKProduct *myProduct;

@property (strong) UILabel *titleLabel;
@property (strong) UILabel *descLabel;
@property (strong) UILabel *priceLabel;

@end
