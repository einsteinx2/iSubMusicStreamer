//
//  HomeAlbumViewController.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "HomeAlbumViewController.h"
#import "ServerListViewController.h"
#import "Defines.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "EX2Kit.h"
#import "Swift.h"

@interface HomeAlbumViewController() <APILoaderDelegate>
@end

@implementation HomeAlbumViewController

- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b; {
    if (self = [super initWithNibName:n bundle:b]) {
		_isMoreAlbums = YES;
    }
    return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	    
    self.tableView.rowHeight = Defines.rowHeight;
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self addShowPlayerButton];
}

- (void)loadMoreResults {
	if (self.isLoading) return;
	
	self.isLoading = YES;
	self.offset += 20;
    
    self.loader = [[QuickAlbumsLoader alloc] initWithDelegate:self];
    self.loader.modifier = self.modifier;
    self.loader.offset = self.offset;
    [self.loader startLoad];
}

- (void)loadingFinished:(APILoader *)loader {
    if (self.loader.folderAlbums.count == 0) {
        // There are no more songs
        self.isMoreAlbums = NO;
    } else {
        // Add the new results to the list of songs
        [self.folderAlbums addObjectsFromArray:self.loader.folderAlbums];
    }
    
    // Reload the table
    [self.tableView reloadData];
    self.isLoading = NO;
    
    self.loader = nil;
}

- (void)loadingFailed:(APILoader *)theLoader error:(NSError *)error {
    self.loader = nil;
	self.isLoading = NO;
	    
    if (settingsS.isPopupsEnabled) {
        NSString *message = [NSString stringWithFormat:@"There was an error performing the search.\n\nError:%@", error.localizedDescription];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark Table view methods

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section  {
	return self.folderAlbums.count + 1;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath  {
	if (indexPath.row < self.folderAlbums.count) {
        UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
        [cell showCached:NO number:NO art:YES secondary:YES duration:NO];
        [cell updateWithModel:[self.folderAlbums objectAtIndexSafe:indexPath.row]];
        return cell;
	} else if (indexPath.row == self.folderAlbums.count) {
		// This is the last cell and there could be more results, load the next 20 songs;
		UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"HomeAlbumLoadCell"];
        cell.backgroundColor = [UIColor colorNamed:@"isubBackgroundColor"];
		if (self.isMoreAlbums) {
			cell.textLabel.text = @"Loading more results...";
            UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
			indicator.center = CGPointMake(300, 30);
			[cell addSubview:indicator];
			[indicator startAnimating];
            
			[self loadMoreResults];
		} else {
			cell.textLabel.text = @"No more results";
		}
		
		return cell;
	}
	
	// In case somehow no cell is created, return an empty cell
	return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier: @"EmptyCell"];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!indexPath) return;
	
	if (indexPath.row != self.folderAlbums.count) {
		ISMSFolderAlbum *folderAlbum = [self.folderAlbums objectAtIndexSafe:indexPath.row];
		FolderAlbumViewController *controller = [[FolderAlbumViewController alloc] initWithFolderAlbum:folderAlbum];
		[self pushViewControllerCustom:controller];
	} else {
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row != self.folderAlbums.count) {
        return [SwipeAction downloadAndQueueConfigWithModel:[self.folderAlbums objectAtIndexSafe:indexPath.row]];
    }
    return nil;
}

@end

