//
//  GenresViewController.m
//  iSub
//
//  Created by Ben Baron on 5/26/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "GenresViewController.h"
#import "GenresArtistViewController.h"
#import "GenresGenreUITableViewCell.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "UIViewController+PushViewControllerCustom.h"

@implementation GenresViewController
@synthesize isNoGenresScreenShowing, noGenresScreen;

#pragma mark -
#pragma mark View lifecycle

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];

	//DLog(@"Cache viewDidLoad");
	
	self.isNoGenresScreenShowing = NO;
	
	self.title = @"Genres";
	
	if (settingsS.isOfflineMode)
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)];
	
	//Set defaults
	//letUserSelectRow = YES;
	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}

	if (!self.tableView.tableHeaderView) self.tableView.tableHeaderView = [[UIView alloc] init];
		
	if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addURLRefBackButton) name:UIApplicationDidBecomeActiveNotification object:nil];
}


- (void)showNoGenresScreen
{
	if (self.isNoGenresScreenShowing == NO)
	{
		self.isNoGenresScreenShowing = YES;
		self.noGenresScreen = [[UIImageView alloc] init];
		self.noGenresScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
		self.noGenresScreen.frame = CGRectMake(40, 100, 240, 180);
		self.noGenresScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
		self.noGenresScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
		self.noGenresScreen.alpha = .80;
		
		UILabel *textLabel = [[UILabel alloc] init];
		textLabel.backgroundColor = [UIColor clearColor];
		textLabel.textColor = [UIColor whiteColor];
		textLabel.font = ISMSBoldFont(30);
		textLabel.textAlignment = NSTextAlignmentCenter;
		textLabel.numberOfLines = 0;
		if (settingsS.isOfflineMode) {
			[textLabel setText:@"No Cached\nSongs"];
		}
		else {
			[textLabel setText:@"Load The\nSongs Tab\nFirst"];
		}
		textLabel.frame = CGRectMake(20, 20, 200, 140);
		[self.noGenresScreen addSubview:textLabel];
		
		[self.view addSubview:self.noGenresScreen];
	}
}

- (void)addURLRefBackButton
{
    if (appDelegateS.referringAppUrl && appDelegateS.mainTabBarController.selectedIndex != 4)
    {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleBordered target:appDelegateS action:@selector(backToReferringApp)];
    }
}

- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
    
    [self addURLRefBackButton];
	
    self.navigationItem.rightBarButtonItem = nil;
	if(musicS.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)];
	}
	
	if (settingsS.isOfflineMode)
	{
		if ([databaseS.songCacheDbQueue intForQuery:@"SELECT COUNT(*) FROM genres"] == 0)
		{
			[self showNoGenresScreen];
		}
	}
	else 
	{
		if ([databaseS.genresDbQueue intForQuery:@"SELECT COUNT(*) FROM genres"] == 0)
		{
			[self showNoGenresScreen];
		}
	}

	[self.tableView reloadData];
}


-(void)viewWillDisappear:(BOOL)animated
{
	if (self.isNoGenresScreenShowing == YES)
	{
		[self.noGenresScreen removeFromSuperview];
		self.isNoGenresScreenShowing = NO;
	}
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


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1; 
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
    // Return the number of rows in the section.
	if (settingsS.isOfflineMode)
		return [databaseS.songCacheDbQueue intForQuery:@"SELECT COUNT(*) FROM genres"];
	else
		return [databaseS.genresDbQueue intForQuery:@"SELECT COUNT(*) FROM genres"];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *cellIdentifier = @"GenresGenreCell";
	GenresGenreUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell)
	{
		cell = [[GenresGenreUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}

    // Configure the cell...
    cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
	
	if (settingsS.isOfflineMode)
	{
		cell.genreNameLabel.text = [databaseS.songCacheDbQueue stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", @(indexPath.row + 1)];
	}
	else
	{
		cell.genreNameLabel.text = [databaseS.genresDbQueue stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", @(indexPath.row + 1)];
	}
	
    return cell;
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{	
	if (!indexPath)
		return;
	
	if (viewObjectsS.isCellEnabled)
	{
		GenresArtistViewController *artistViewController = [[GenresArtistViewController alloc] initWithNibName:@"GenresArtistViewController" bundle:nil];
		if (settingsS.isOfflineMode) 
		{
			NSString *title = [databaseS.songCacheDbQueue stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", @(indexPath.row + 1)];
			artistViewController.title = [NSString stringWithString:title ? title : @""];
		}
		else
		{
			NSString *title = [databaseS.genresDbQueue stringForQuery:@"SELECT genre FROM genres WHERE ROWID = ?", @(indexPath.row + 1)];
			artistViewController.title = [NSString stringWithString:title ? title : @""];
		}
		artistViewController.listOfArtists = [NSMutableArray arrayWithCapacity:1];

		FMDatabaseQueue *dbQueue;
		NSString *query;
		
		if (settingsS.isOfflineMode) 
		{
			dbQueue = databaseS.songCacheDbQueue;
			query = @"SELECT seg1 FROM cachedSongsLayout a INNER JOIN genresSongs b ON a.md5 = b.md5 WHERE b.genre = ? GROUP BY seg1 ORDER BY seg1 COLLATE NOCASE";
		}
		else
		{
			dbQueue = databaseS.genresDbQueue;
			query = @"SELECT seg1 FROM genresLayout a INNER JOIN genresSongs b ON a.md5 = b.md5 WHERE b.genre = ? GROUP BY seg1 ORDER BY seg1 COLLATE NOCASE";
		}
		
		[dbQueue inDatabase:^(FMDatabase *db)
		{
			FMResultSet *result = [db executeQuery:query, artistViewController.title];
			if ([db hadError])
			{
			//DLog(@"Error grabbing the artists for this genre... Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
			}
			else 
			{
				while ([result next])
				{
					NSString *artist = [result stringForColumnIndex:0];
					if (artist) [artistViewController.listOfArtists addObject:artist];
				}
			}
			[result close];
		}];
		
		[self pushViewControllerCustom:artistViewController];
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning 
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}



@end

