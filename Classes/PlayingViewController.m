//
//  PlayingViewController.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "PlayingViewController.h"
#import "PlayingUITableViewCell.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "EGORefreshTableHeaderView.h"
#import "UIViewController+PushViewControllerCustom.h"

@interface PlayingViewController (Private)
- (void)dataSourceDidFinishLoadingNewData;
@end

@implementation PlayingViewController

@synthesize nothingPlayingScreen, dataModel;
@synthesize reloading, refreshHeaderView;
@synthesize isNothingPlayingScreenShowing, receivedData;

#pragma mark - Rotation Handling

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

#pragma mark Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.isNothingPlayingScreenShowing = NO;
	
	self.tableView.separatorColor = [UIColor clearColor];
	
	self.title = @"Now Playing";
	//self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];
	
	self.dataModel = [[SUSNowPlayingDAO alloc] initWithDelegate:self];
	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
	
	// Add the pull to refresh view
	self.refreshHeaderView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, 320.0f, self.tableView.bounds.size.height)];
	self.refreshHeaderView.backgroundColor = [UIColor whiteColor];
	[self.tableView addSubview:self.refreshHeaderView];
		
	if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addURLRefBackButton) name:UIApplicationDidBecomeActiveNotification object:nil];
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
		UIImage *playingImage = [UIImage imageNamed:@"now-playing.png"];
		UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithImage:playingImage
																	   style:UIBarButtonItemStyleBordered 
																	  target:self 
																	  action:@selector(nowPlayingAction:)];
		self.navigationItem.rightBarButtonItem = buttonItem;
	}
	
	[viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
	
	[self.dataModel startLoad];
	
	[Flurry logEvent:@"NowPlayingTab"];
}

- (void)cancelLoad
{
	[self.dataModel cancelLoad];
	[viewObjectsS hideLoadingScreen];
	[self dataSourceDidFinishLoadingNewData];
}

-(void)viewWillDisappear:(BOOL)animated
{
	if (self.isNothingPlayingScreenShowing)
	{
		[self.nothingPlayingScreen removeFromSuperview];
		self.isNothingPlayingScreenShowing = NO;
	}
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}


#pragma mark - Button Handling

- (void) settingsAction:(id)sender 
{
	ServerListViewController *serverVC = [[ServerListViewController alloc] 
										  initWithNibName:@"ServerListViewController" 
												   bundle:nil];
	serverVC.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverVC animated:YES];
}


- (IBAction)nowPlayingAction:(id)sender
{
	iPhoneStreamingPlayerViewController *playerVC = [[iPhoneStreamingPlayerViewController alloc]
													 initWithNibName:@"iPhoneStreamingPlayerViewController"
															  bundle:nil];
	playerVC.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:playerVC animated:YES];
}


#pragma mark - Table View Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
    return self.dataModel.count;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *cellIdentifier = @"PlayingCell";
	PlayingUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell)
	{
		cell = [[PlayingUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}
	
	ISMSSong *aSong = [self.dataModel songForIndex:indexPath.row];
	cell.mySong = aSong;
	
	// Set the cover art
	cell.coverArtView.coverArtId = aSong.coverArtId;
	
	// Create the background view
	cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
	
	// Set the title label
	NSString *playTime = [self.dataModel playTimeForIndex:indexPath.row];
	NSString *username = [self.dataModel usernameForIndex:indexPath.row];
	NSString *playerName = [self.dataModel playerNameForIndex:indexPath.row];
	
	if (playerName)
	{
		NSString *text = [NSString stringWithFormat:@"%@ @ %@ - %@", username, playerName, playTime];
		[cell.userNameLabel setText:text];
	}
	else
	{
		NSString *text = [NSString stringWithFormat:@"%@ - %@", username, playTime];
		[cell.userNameLabel setText:text];
	}

	// Set the song name label
	cell.songNameLabel.text = aSong.title;
	if (aSong.album)
		cell.artistNameLabel.text = [NSString stringWithFormat:@"%@ - %@", aSong.artist, aSong.album];
	else
		cell.artistNameLabel.text = aSong.artist;
	
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (!indexPath)
		return;
	
	ISMSSong *playedSong = [self.dataModel playSongAtIndex:indexPath.row];
	if (!playedSong.isVideo)
        [self showPlayer];
}

#pragma mark - ISMSLoader delegate

- (void)loadingFailed:(ISMSLoader *)theLoader withError:(NSError *)error
{
    // Inform the user that the connection failed.
	NSString *message = [NSString stringWithFormat:@"There was an error loading the now playing list.\n\nError %li: %@", (long)[error code], [error localizedDescription]];
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	
	[viewObjectsS hideLoadingScreen];
	
	[self dataSourceDidFinishLoadingNewData];
}

- (void)loadingFinished:(ISMSLoader *)theLoader
{
    [viewObjectsS hideLoadingScreen];
	
	[self.tableView reloadData];
	[self dataSourceDidFinishLoadingNewData];
	
	// Display the no songs overlay if 0 results
	if (self.dataModel.count == 0)
	{
		if (!self.isNothingPlayingScreenShowing)
		{
			self.isNothingPlayingScreenShowing = YES;
			self.nothingPlayingScreen = [[UIImageView alloc] init];
			self.nothingPlayingScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
			self.nothingPlayingScreen.frame = CGRectMake(40, 100, 240, 180);
			self.nothingPlayingScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
			self.nothingPlayingScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
			self.nothingPlayingScreen.alpha = .80;
			
			UILabel *textLabel = [[UILabel alloc] init];
			textLabel.backgroundColor = [UIColor clearColor];
			textLabel.textColor = [UIColor whiteColor];
			textLabel.font = ISMSBoldFont(30);
			textLabel.textAlignment = NSTextAlignmentCenter;
			textLabel.numberOfLines = 0;
			[textLabel setText:@"Nothing Playing\non the\nServer"];
			textLabel.frame = CGRectMake(15, 15, 210, 150);
			[self.nothingPlayingScreen addSubview:textLabel];
			
			[self.view addSubview:self.nothingPlayingScreen];
			
		}
	}
	else
	{
		if (self.isNothingPlayingScreenShowing)
		{
			self.isNothingPlayingScreenShowing = NO;
			[self.nothingPlayingScreen removeFromSuperview];
		}
	}
}

#pragma mark - Pull to refresh methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{	
	if (scrollView.isDragging) 
	{
		if (self.refreshHeaderView.state == EGOOPullRefreshPulling && scrollView.contentOffset.y > -65.0f && scrollView.contentOffset.y < 0.0f && !self.reloading) 
		{
			[self.refreshHeaderView setState:EGOOPullRefreshNormal];
		} 
		else if (self.refreshHeaderView.state == EGOOPullRefreshNormal && scrollView.contentOffset.y < -65.0f && !self.reloading) 
		{
			[self.refreshHeaderView setState:EGOOPullRefreshPulling];
		}
	}
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	if (scrollView.contentOffset.y <= - 65.0f && !self.reloading) 
	{
		self.reloading = YES;
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
		[self.dataModel startLoad];
		[self.refreshHeaderView setState:EGOOPullRefreshLoading];
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.2];
		self.tableView.contentInset = UIEdgeInsetsMake(60.0f, 0.0f, 0.0f, 0.0f);
		[UIView commitAnimations];
	}
}

- (void)dataSourceDidFinishLoadingNewData
{
	self.reloading = NO;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	[self.tableView setContentInset:UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f)];
	[UIView commitAnimations];
	
	[self.refreshHeaderView setState:EGOOPullRefreshNormal];
}

@end

