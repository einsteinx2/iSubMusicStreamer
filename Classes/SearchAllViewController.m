//
//  SearchAllViewController.m
//  iSub
//
//  Created by Ben Baron on 4/6/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SearchAllViewController.h"
#import "SearchSongsViewController.h"
#import "UIViewController+PushViewControllerCustom.h"

@implementation SearchAllViewController
@synthesize cellNames, listOfArtists, listOfAlbums, listOfSongs, query;

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.cellNames = [NSMutableArray arrayWithCapacity:3];
	
	if (self.listOfArtists.count > 0)
	{
		[cellNames addObject:@"Artists"];
	}
	
	if (self.listOfAlbums.count > 0)
	{
		[cellNames addObject:@"Albums"];
	}
	
	if (self.listOfSongs.count > 0)
	{
		[cellNames addObject:@"Songs"];
	}
	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
	
	if (!self.tableView.tableHeaderView) self.tableView.tableHeaderView = [[UIView alloc] init];
	if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return self.cellNames.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *cellIdentifier = @"SearchAllCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) 
	{
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
	
	cell.textLabel.text = [cellNames objectAtIndexSafe:indexPath.row];
	cell.textLabel.backgroundColor = [UIColor clearColor];
	cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (!indexPath)
		return;
	
	SearchSongsViewController *searchView = [[SearchSongsViewController alloc] initWithNibName:@"SearchSongsViewController" 
																						bundle:nil];
	NSString *type = [cellNames objectAtIndexSafe:indexPath.row];
	if ([type isEqualToString:@"Artists"])
	{
		searchView.listOfArtists = [NSMutableArray arrayWithArray:listOfArtists];
		searchView.searchType = ISMSSearchSongsSearchType_Artists;
	}
	else if ([type isEqualToString:@"Albums"])
	{
		searchView.listOfAlbums = [NSMutableArray arrayWithArray:listOfAlbums];
		searchView.searchType = ISMSSearchSongsSearchType_Albums;
	}
	else if ([type isEqualToString:@"Songs"])
	{
		searchView.listOfSongs = [NSMutableArray arrayWithArray:listOfSongs];
		searchView.searchType = ISMSSearchSongsSearchType_Songs;
	}
	
	searchView.query = query;
	
	//[self.navigationController pushViewController:searchView animated:YES];
	[self pushViewControllerCustom:searchView];
}

@end
