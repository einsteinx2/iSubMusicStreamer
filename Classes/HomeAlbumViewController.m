//
//  HomeAlbumViewController.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "HomeAlbumViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "AlbumViewController.h"
#import "AllAlbumsUITableViewCell.h"
#import "SongUITableViewCell.h"
#import "ServerListViewController.h"
#import "UIViewController+PushViewControllerCustom.h"

@implementation HomeAlbumViewController

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

- (id)initWithNibName:(NSString *)n bundle:(NSBundle *)b;
{
    self = [super initWithNibName:n bundle:b];
	
    if (self != nil)
    {
		_isMoreAlbums = YES;
    }
	
    return self;
}

- (void)viewDidLoad  
{	
	[super viewDidLoad];
	
	//self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];

	if(musicS.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
	
	if (!self.tableView.tableHeaderView) self.tableView.tableHeaderView = [[UIView alloc] init];
	
	if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
}

- (void) settingsAction:(id)sender 
{
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverListViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverListViewController animated:YES];
}

- (IBAction)nowPlayingAction:(id)sender
{
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}


- (void)loadMoreResults
{	
	if (self.isLoading)
		return;
	
	self.isLoading = YES;
	self.offset += 20;
    
    self.loader = [ISMSQuickAlbumsLoader loaderWithDelegate:self];
    self.loader.modifier = self.modifier;
    self.loader.offset = self.offset;
    [self.loader startLoad];
}

- (void)loadingFailed:(ISMSLoader *)theLoader withError:(NSError *)error
{
    self.loader = nil;
	self.isLoading = NO;
	    
    CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"There was an error doing the search.\n\nError:%@", error.localizedDescription] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
}	

- (void)loadingFinished:(ISMSLoader *)theLoader
{
    if (self.loader.listOfAlbums.count == 0)
    {
        // There are no more songs
		self.isMoreAlbums = NO;
    }
    else 
    {
        // Add the new results to the list of songs
        [self.listOfAlbums addObjectsFromArray:self.loader.listOfAlbums];
    }
    
    // Reload the table
    [self.tableView reloadData];
    self.isLoading = NO;
    
	self.loader = nil;
}

#pragma mark Table view methods

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	return self.listOfAlbums.count + 1;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{		
	if (indexPath.row < self.listOfAlbums.count)
	{
		static NSString *cellIdentifier = @"AllAlbumsCell";
		AllAlbumsUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[AllAlbumsUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		}
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		
		ISMSAlbum *anAlbum = [self.listOfAlbums objectAtIndexSafe:indexPath.row];
		cell.myId = anAlbum.albumId;
		cell.myArtist = [ISMSArtist artistWithName:anAlbum.artistName andArtistId:anAlbum.artistId];
		
		cell.coverArtView.coverArtId = anAlbum.coverArtId;
		
		[cell.albumNameLabel setText:anAlbum.title];
		[cell.artistNameLabel setText:anAlbum.artistName];
		
		// Setup cell backgrond color
		cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
		
		return cell;
	}
	else if (indexPath.row == self.listOfAlbums.count)
	{
		// This is the last cell and there could be more results, load the next 20 songs;
		static NSString *cellIdentifier = @"HomeAlbumLoadCell";
		UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];

		// Set background color
		cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
		cell.textLabel.backgroundColor = cell.backgroundView.backgroundColor;
		
		if (self.isMoreAlbums)
		{
			cell.textLabel.text = @"Loading more results...";
			UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
			indicator.center = CGPointMake(300, 30);
			[cell addSubview:indicator];
			[indicator startAnimating];
			
			[self loadMoreResults];
		}
		else 
		{
			cell.textLabel.text = @"No more results";
		}
		
		return cell;
	}
	
	// In case somehow no cell is created, return an empty cell
	static NSString *cellIdentifier = @"EmptyCell";
	return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{	
	if (!indexPath)
		return;
	
	if (viewObjectsS.isCellEnabled && indexPath.row != self.listOfAlbums.count)
	{
		ISMSAlbum *anAlbum = [self.listOfAlbums objectAtIndexSafe:indexPath.row];
		AlbumViewController *albumViewController = [[AlbumViewController alloc] initWithArtist:nil orAlbum:anAlbum];
		[self pushViewControllerCustom:albumViewController];
		//[self.navigationController pushViewController:albumViewController animated:YES];
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

@end

