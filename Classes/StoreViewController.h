//
//  StoreViewController.h
//  iSub
//
//  Created by Ben Baron on 12/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "MKStoreManager.h"

@interface StoreViewController : UITableViewController

@property (strong) MKStoreManager *storeManager;
@property (strong) NSArray *storeItems;
@property (strong) NSTimer *checkProductsTimer;

- (void)checkProducts;
- (void)organizeList;
- (void)cancelLoad;

@end
