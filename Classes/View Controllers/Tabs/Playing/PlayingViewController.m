//
//  PlayingViewController.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "PlayingViewController.h"
#import "ServerListViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "Flurry.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "SUSNowPlayingDAO.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "Swift.h"

@implementation PlayingViewController

#pragma mark Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.isNothingPlayingScreenShowing = NO;
	
	self.tableView.separatorColor = [UIColor clearColor];
	
	self.title = @"Now Playing";
	//self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStylePlain target:self action:@selector(settingsAction:)] autorelease];
	
	self.dataModel = [[SUSNowPlayingDAO alloc] initWithDelegate:self];
	
    // Add the pull to refresh view
    __weak PlayingViewController *weakSelf = self;
    self.refreshControl = [[RefreshControl alloc] initWithHandler:^{
        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
        [weakSelf.dataModel startLoad];
    }];
    
    self.tableView.rowHeight = 85.0;
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
        
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(addURLRefBackButton) name:UIApplicationDidBecomeActiveNotification];
}

- (void)addURLRefBackButton {
    if (appDelegateS.referringAppUrl && appDelegateS.mainTabBarController.selectedIndex != 4) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:appDelegateS action:@selector(backToReferringApp)];
    }
}

- (void)viewWillAppear:(BOOL)animated  {
    [super viewWillAppear:animated];
    
    [self addURLRefBackButton];
	
    self.navigationItem.rightBarButtonItem = nil;
	if (musicS.showPlayerIcon) {
		UIImage *playingImage = [UIImage imageNamed:@"now-playing.png"];
		UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithImage:playingImage style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
		self.navigationItem.rightBarButtonItem = buttonItem;
	}
	
	[viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
	
	[self.dataModel startLoad];
	
	[Flurry logEvent:@"NowPlayingTab"];
}

- (void)cancelLoad {
	[self.dataModel cancelLoad];
	[viewObjectsS hideLoadingScreen];
	[self.refreshControl endRefreshing];
}

-(void)viewWillDisappear:(BOOL)animated {
	if (self.isNothingPlayingScreenShowing) {
		[self.nothingPlayingScreen removeFromSuperview];
		self.isNothingPlayingScreenShowing = NO;
	}
}

#pragma mark - Button Handling

- (void) settingsAction:(id)sender  {
	ServerListViewController *serverVC = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverVC.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverVC animated:YES];
}

- (IBAction)nowPlayingAction:(id)sender {
    PlayerViewController *playerViewController = [[PlayerViewController alloc] init];
    playerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:playerViewController animated:YES];
}

#pragma mark - Table View Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView  {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section  {
    return self.dataModel.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
    cell.hideHeaderLabel = NO;
    cell.hideNumberLabel = YES;
    NSString *playTime = [self.dataModel playTimeForIndex:indexPath.row];
    NSString *username = [self.dataModel usernameForIndex:indexPath.row];
    NSString *playerName = [self.dataModel playerNameForIndex:indexPath.row];
    if (playerName) {
        cell.headerText = [NSString stringWithFormat:@"%@ @ %@ - %@", username, playerName, playTime];
    } else {
        cell.headerText = [NSString stringWithFormat:@"%@ - %@", username, playTime];
    }
    [cell updateWithModel:[self.dataModel songForIndex:indexPath.row]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!indexPath) return;
	
	ISMSSong *playedSong = [self.dataModel playSongAtIndex:indexPath.row];
    if (!playedSong.isVideo) {
        [self showPlayer];
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [SwipeAction downloadAndQueueConfigWithModel:[self.dataModel songForIndex:indexPath.row]];
}

#pragma mark - ISMSLoader delegate

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error {
    if (settingsS.isPopupsEnabled) {
        NSString *message = [NSString stringWithFormat:@"There was an error loading the now playing list.\n\nError %li: %@", (long)[error code], [error localizedDescription]];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
	
	[viewObjectsS hideLoadingScreen];
	
	[self.refreshControl endRefreshing];
}

- (void)loadingFinished:(SUSLoader *)theLoader {
    [viewObjectsS hideLoadingScreen];
	
	[self.tableView reloadData];
	[self.refreshControl endRefreshing];
	
	// Display the no songs overlay if 0 results
	if (self.dataModel.count == 0) {
		if (!self.isNothingPlayingScreenShowing) {
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
	} else {
		if (self.isNothingPlayingScreenShowing) {
			self.isNothingPlayingScreenShowing = NO;
			[self.nothingPlayingScreen removeFromSuperview];
		}
	}
}

@end

