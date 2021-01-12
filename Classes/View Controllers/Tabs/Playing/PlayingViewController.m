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
#import "EX2Kit.h"
#import "Swift.h"

@interface PlayingViewController() <APILoaderDelegate>
@end

@implementation PlayingViewController

#pragma mark Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.isNothingPlayingScreenShowing = NO;
		
	self.title = @"Now Playing";
	
    self.nowPlayingLoader = [[NowPlayingLoader alloc] initWithDelegate:self];
	
    // Add the pull to refresh view
    __weak PlayingViewController *weakSelf = self;
    self.refreshControl = [[RefreshControl alloc] initWithHandler:^{
        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
        [weakSelf.nowPlayingLoader startLoad];
    }];
    
    self.tableView.rowHeight = Defines.tallRowHeight;
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
		UIImage *playingImage = [UIImage systemImageNamed:@"music.quarternote.3"];
		UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithImage:playingImage style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
		self.navigationItem.rightBarButtonItem = buttonItem;
	}
	
	[viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
	
	[self.nowPlayingLoader startLoad];
	
	[Flurry logEvent:@"NowPlayingTab"];
}

- (void)cancelLoad {
	[self.nowPlayingLoader cancelLoad];
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

- (NowPlayingSong *)nowPlayingSongAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < self.nowPlayingLoader.nowPlayingSongs.count) {
        return self.nowPlayingLoader.nowPlayingSongs[indexPath.row];
    }
    return nil;
}

- (ISMSSong *)songAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < self.nowPlayingLoader.nowPlayingSongs.count) {
        NowPlayingSong *nowPlayingSong = self.nowPlayingLoader.nowPlayingSongs[indexPath.row];
        return [Store.shared songWithServerId:nowPlayingSong.serverId songId:nowPlayingSong.songId];
    }
    return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView  {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section  {
    return self.nowPlayingLoader.nowPlayingSongs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
    cell.hideHeaderLabel = NO;
    cell.hideNumberLabel = YES;
    NowPlayingSong *nowPlayingSong = [self nowPlayingSongAtIndexPath:indexPath];
    NSString *playTimeMins = nowPlayingSong.minutesAgo == 1 ? @"min" : @"mins";
    NSString *playTime = [NSString stringWithFormat:@"%ld %@ ago", (long)nowPlayingSong.minutesAgo, playTimeMins];
    if (nowPlayingSong.playerName.hasValue) {
        cell.headerText = [NSString stringWithFormat:@"%@ @ %@ - %@", nowPlayingSong.username, nowPlayingSong.playerName, playTime];
    } else {
        cell.headerText = [NSString stringWithFormat:@"%@ - %@", nowPlayingSong.username, playTime];
    }
    [cell updateWithModel:[self songAtIndexPath:indexPath]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!indexPath || indexPath.row >= self.nowPlayingLoader.nowPlayingSongs.count) return;
	
    ISMSSong *song = [self songAtIndexPath:indexPath];
    song = [Store.shared playSongWithPosition:0 songs:@[song]];
    if (!song.isVideo) {
        [self showPlayer];
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [SwipeAction downloadAndQueueConfigWithModel:[self songAtIndexPath:indexPath]];
}

// NOTE: For some reason, in this controller and this controller only, it's ignoring the rowHeight property and this must be implemented
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return Defines.tallRowHeight;
}

#pragma mark - APILoader delegate

- (void)loadingFinished:(APILoader *)loader {
    [viewObjectsS hideLoadingScreen];
	
	[self.tableView reloadData];
	[self.refreshControl endRefreshing];
	
	// Display the no songs overlay if 0 results
	if (self.nowPlayingLoader.nowPlayingSongs.count == 0) {
		if (!self.isNothingPlayingScreenShowing) {
			self.isNothingPlayingScreenShowing = YES;
			self.nothingPlayingScreen = [[UIImageView alloc] init];
			self.nothingPlayingScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
			self.nothingPlayingScreen.frame = CGRectMake(40, 100, 240, 180);
			self.nothingPlayingScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
			self.nothingPlayingScreen.image = [UIImage imageNamed:@"loading-screen-image"];
			self.nothingPlayingScreen.alpha = .80;
			
			UILabel *textLabel = [[UILabel alloc] init];
			textLabel.backgroundColor = [UIColor clearColor];
			textLabel.textColor = [UIColor whiteColor];
			textLabel.font = [UIFont boldSystemFontOfSize:30];
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

- (void)loadingFailed:(APILoader *)loader error:(NSError *)error {
    if (settingsS.isPopupsEnabled) {
        NSString *message = [NSString stringWithFormat:@"There was an error loading the now playing list.\n\nError %li: %@", (long)[error code], [error localizedDescription]];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
    
    [viewObjectsS hideLoadingScreen];
    
    [self.refreshControl endRefreshing];
}

@end

