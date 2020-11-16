//
//  HomeAlbumViewController.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "HomeAlbumViewController.h"
#import "AlbumViewController.h"
#import "ServerListViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "SUSQuickAlbumsLoader.h"
#import "CustomUIAlertView.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "ISMSArtist.h"
#import "ISMSAlbum.h"
#import "EX2Kit.h"
#import "Swift.h"

@implementation HomeAlbumViewController

- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b; {
    if (self = [super initWithNibName:n bundle:b]) {
		_isMoreAlbums = YES;
    }
    return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	if (musicS.showPlayerIcon) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
	} else {
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	if (UIDevice.isIPad) {
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
    
    self.tableView.rowHeight = 80.0;
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
}

- (void) settingsAction:(id)sender {
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverListViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverListViewController animated:YES];
}

- (IBAction)nowPlayingAction:(id)sender {
    PlayerViewController *playerViewController = [[PlayerViewController alloc] init];
    playerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:playerViewController animated:YES];
}

- (void)loadMoreResults {
	if (self.isLoading) return;
	
	self.isLoading = YES;
	self.offset += 20;
    
    self.loader = [[SUSQuickAlbumsLoader alloc] initWithDelegate:self];
    self.loader.modifier = self.modifier;
    self.loader.offset = self.offset;
    [self.loader startLoad];
}

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error {
    self.loader = nil;
	self.isLoading = NO;
	    
    CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"There was an error doing the search.\n\nError:%@", error.localizedDescription] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
}	

- (void)loadingFinished:(SUSLoader *)theLoader {
    if (self.loader.listOfAlbums.count == 0) {
        // There are no more songs
		self.isMoreAlbums = NO;
    } else {
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
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section  {
	return self.listOfAlbums.count + 1;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath  {
	if (indexPath.row < self.listOfAlbums.count) {
        UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
        cell.hideNumberLabel = YES;
        cell.hideCoverArt = NO;
        cell.hideDurationLabel = YES;
        [cell updateWithModel:[self.listOfAlbums objectAtIndexSafe:indexPath.row]];
        return cell;
	} else if (indexPath.row == self.listOfAlbums.count) {
		// This is the last cell and there could be more results, load the next 20 songs;
		UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"HomeAlbumLoadCell"];

		if (self.isMoreAlbums)
		{
			cell.textLabel.text = @"Loading more results...";
            UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
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
	return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier: @"EmptyCell"];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!indexPath) return;
	
	if (indexPath.row != self.listOfAlbums.count) {
		ISMSAlbum *anAlbum = [self.listOfAlbums objectAtIndexSafe:indexPath.row];
		AlbumViewController *albumViewController = [[AlbumViewController alloc] initWithArtist:nil orAlbum:anAlbum];
		[self pushViewControllerCustom:albumViewController];
	} else {
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row != self.listOfAlbums.count) {
        return [SwipeAction downloadAndQueueConfigWithModel:[self.listOfAlbums objectAtIndexSafe:indexPath.row]];
    }
    return nil;
}

@end

