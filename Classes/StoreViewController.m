//
//  StoreViewController.m
//  iSub
//
//  Created by Ben Baron on 12/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "StoreViewController.h"
#import "StoreUITableViewCell.h"

@implementation StoreViewController

#pragma mark - View lifecycle

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[self.tableView reloadData];
}

- (void)viewDidLoad 
{
    [super viewDidLoad];

	self.storeManager = [MKStoreManager sharedManager];

	self.storeItems = [[NSArray alloc] initWithArray:self.storeManager.purchasableObjects];
	
	[[NSNotificationCenter defaultCenter] addObserver:self.tableView selector:@selector(reloadData) name:ISMSNotification_StorePurchaseComplete object:nil];
	
	if (self.storeItems.count == 0)
	{
		[viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
		self.checkProductsTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkProducts) userInfo:nil repeats:YES];
		[self checkProducts];
	}
	else
	{
		[self organizeList];
		[self.tableView reloadData];
	}
}


- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc. that aren't in use.
}

- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self.tableView];
}

#pragma mark - Store

- (void)cancelLoad
{
	[self.checkProductsTimer invalidate]; self.checkProductsTimer = nil;
	[viewObjectsS hideLoadingScreen];
}

- (void)checkProducts
{
	self.storeItems = [[NSArray alloc] initWithArray:self.storeManager.purchasableObjects];
	
	if (self.storeItems.count > 0)
	{
		[self.checkProductsTimer invalidate]; 
		self.checkProductsTimer = nil;
		
		[viewObjectsS hideLoadingScreen];
		
		[self organizeList];
		
		[self.tableView reloadData];
	}
}

- (void)organizeList
{
	NSMutableArray *sorted = [[NSMutableArray alloc] init];
	NSMutableArray *temp = [[NSMutableArray alloc] init];
	
	for (SKProduct *product in self.storeItems)
	{
		if ([MKStoreManager isFeaturePurchased:[product productIdentifier]])
		{
			[temp addObject:product];
		}
		else
		{
			[sorted addObject:product];
		}
	}
	
	[sorted addObjectsFromArray:temp];
	
	self.storeItems = [[NSArray alloc] initWithArray:sorted];
}

#pragma mark - Table view data source

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.row == 0)
		return 75.0;
	return 150.0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return self.storeItems.count + 1;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *cellIdentifier = @"NoReuse";
	
	UITableViewCell *cell = nil;
	if (indexPath.row == 0)
	{
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		cell.textLabel.text = @"Restore previous purchases";
	}
	else
	{
		NSUInteger adjustedRow = indexPath.row - 1;
		cell = [[StoreUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		((StoreUITableViewCell *)cell).myProduct = [self.storeItems objectAtIndexSafe:adjustedRow];
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (indexPath.row == 0)
	{
		[self.storeManager restorePreviousTransactions];
	}
	else
	{
		NSUInteger adjustedRow = indexPath.row - 1;
		if (![MKStoreManager isFeaturePurchased:[[self.storeItems objectAtIndexSafe:adjustedRow] productIdentifier]])
		{
			[self.storeManager buyFeature:[[self.storeItems objectAtIndexSafe:adjustedRow] productIdentifier]];
			
			[self.navigationController popToRootViewControllerAnimated:YES];
		}
	}
	
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end

