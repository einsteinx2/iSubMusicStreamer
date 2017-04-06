//
//  NewHomeViewController.m
//  iSub
//
//  Created by bbaron on 11/6/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "NewHomeViewController.h"
#import "ServerListViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "QuickAlbumsViewController.h"
#import "ChatViewController.h"
#import "SearchSongsViewController.h"
#import "StoreViewController.h"
#import "ShuffleFolderPickerViewController.h"
#import "FolderPickerDialog.h"
#import "SearchAllViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "UIViewController+PushViewControllerCustom.h"
#import "iPadRootViewController.h"
#import "MenuViewController.h"
#import "SearchXMLParser.h"

#import "ISMSPlayerViewController.h"

@implementation NewHomeViewController

@synthesize receivedData, connection;
@synthesize playerButton, jukeboxButton, searchBar, searchSegment, searchSegmentBackground, searchOverlay, dismissButton, isSearch, quickLabel, shuffleLabel, jukeboxLabel, settingsLabel, chatLabel, playerLabel, coverArtBorder, coverArtView, artistLabel, albumLabel, songLabel;

- (BOOL)prefersStatusBarHidden
{
    return NO;
}

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
	BOOL rotationDisabled = settingsS.isRotationLockEnabled;
	
	if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
	{
		if (!IS_IPAD())
		{
			// Animate the segmented control off screen
			[UIView beginAnimations:nil context:NULL];
			[UIView setAnimationDuration:.3];
			[UIView setAnimationCurve:UIViewAnimationCurveLinear];
			self.quickLabel.alpha = 1.0;
			self.shuffleLabel.alpha = 1.0;
			self.jukeboxLabel.alpha = 1.0;
			self.settingsLabel.alpha = 1.0;
			self.chatLabel.alpha = 1.0;
			self.playerLabel.alpha = 1.0;
			
			self.coverArtBorder.alpha = 1.0;
			self.coverArtView.alpha = 1.0;
			self.artistLabel.alpha = 1.0;
			self.albumLabel.alpha = 1.0;
			self.songLabel.alpha = 1.0;
			[UIView commitAnimations];
            
            if (IS_TALL_SCREEN())
            {
                [UIView animateWithDuration:duration animations:^
                 {
                     for (UIView *aView in self.topRow)
                     {
                         aView.y = 75.;
                     }
                     
                     for (UIView *aView in self.topRowLabels)
                     {
                         aView.y = 145.;
                     }
                     
                     self.coverArtBorder.y = 217.;
                     
                     for (UIView *aView in self.bottomRow)
                     {
                         aView.y = 115;
                     }
                     
                     for (UIView *aView in self.bottomRowLabels)
                     {
                         aView.y = 160;
                     }
                 }];
            }
		}
	}
	else if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation) && !rotationDisabled)
	{
		if (!IS_IPAD())
		{
            if (IS_TALL_SCREEN())
            {
                for (UIView *aView in self.topRow)
                {
                    aView.y -= 30;
                }
                
                self.coverArtBorder.y -= 40;
                
                for (UIView *aView in self.bottomRow)
                {
                    aView.y += 40;
                }
            }
            
			// Animate the segmented control off screen
			[UIView beginAnimations:nil context:NULL];
			[UIView setAnimationDuration:.3];
			[UIView setAnimationCurve:UIViewAnimationCurveLinear];
			self.quickLabel.alpha = 0.0;
			self.shuffleLabel.alpha = 0.0;
			self.jukeboxLabel.alpha = 0.0;
			self.settingsLabel.alpha = 0.0;
			self.chatLabel.alpha = 0.0;
			self.playerLabel.alpha = 0.0;
			
			self.coverArtBorder.alpha = 0.0;
			self.coverArtView.alpha = 0.0;
			self.artistLabel.alpha = 0.0;
			self.albumLabel.alpha = 0.0;
			self.songLabel.alpha = 0.0;
			[UIView commitAnimations];
		}
	}
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    DLog(@"y: %@", self.bottomRowLabels.firstObjectSafe);
        
    // Since the values in viewWillRotate would have to be rounded, we need to fix them here
    if (IS_TALL_SCREEN())
    {
        if (UIInterfaceOrientationIsLandscape(fromInterfaceOrientation))
        {
            for (UIView *aView in self.topRow)
            {
                aView.y = 75.;
            }
            
            for (UIView *aView in self.topRowLabels)
            {
                aView.y = 145.;
            }
            
            self.coverArtBorder.y = 217.;
            
            for (UIView *aView in self.bottomRow)
            {
                aView.y = 313.;
            }
            
            for (UIView *aView in self.bottomRowLabels)
            {
                aView.y = 381;
            }
        }
        else
        {
            for (UIView *aView in self.topRow)
            {
                aView.y = 45.;
            }
            
            for (UIView *aView in self.topRowLabels)
            {
                aView.y = 115.;
            }
            
            self.coverArtBorder.y = 177.;
            
            for (UIView *aView in self.bottomRow)
            {
                aView.y = 127.;
            }
            
            for (UIView *aView in self.bottomRowLabels)
            {
                aView.y = 159.;
            }
        }
    }    
}

- (void)viewDidLoad
{
	[super viewDidLoad];
    
    if (IS_IOS7())
    {
        self.searchSegment.tintColor = ISMSHeaderColor;
        self.searchSegmentBackground.backgroundColor = [UIColor colorWithWhite:.3 alpha:1];
    }
    
	self.searchSegment.selectedSegmentIndex = 3;
	
	self.title = @"Home";

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(jukeboxOff) name:ISMSNotification_JukeboxDisabled object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initSongInfo) name:ISMSNotification_SongPlaybackStarted object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initSongInfo) name:ISMSNotification_ServerSwitched object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(performServerShuffle:) name:@"performServerShuffle" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addURLRefBackButton) name:UIApplicationDidBecomeActiveNotification object:nil];

	if (!IS_IPAD())
	{
		self.coverArtBorder = [UIButton buttonWithType:UIButtonTypeCustom];
		self.coverArtBorder.frame = CGRectMake(15, 177, 290, 60);
		self.coverArtBorder.layer.borderColor = [UIColor colorWithWhite:0.7 alpha:1.0].CGColor;
		self.coverArtBorder.layer.borderWidth = 2.0f;
		[self.coverArtBorder addTarget:self action:@selector(player) forControlEvents:UIControlEventTouchUpInside];
		[self.view addSubview:self.coverArtBorder];
		
		self.coverArtView = [[AsynchronousImageView alloc] init];
		self.coverArtView.isLarge = NO;
		self.coverArtView.frame = CGRectMake(0, 0, 60, 60);
		self.coverArtView.layer.borderColor = [UIColor colorWithWhite:0.7 alpha:1.0].CGColor;
		self.coverArtView.layer.borderWidth = 2.0f;
		
		[self.coverArtBorder addSubview:self.coverArtView];
		
		self.artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(65, 3, 220, 20)];
		self.artistLabel.backgroundColor = [UIColor clearColor];
		self.artistLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
		self.artistLabel.font = ISMSBoldFont(17);
		self.artistLabel.minimumScaleFactor = 12.0 / self.artistLabel.font.pointSize;
		self.artistLabel.adjustsFontSizeToFitWidth = YES;
		self.artistLabel.textAlignment = NSTextAlignmentCenter;
		self.artistLabel.shadowOffset = CGSizeMake(0, 2);
		self.artistLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.25];
		[self.coverArtBorder addSubview:self.artistLabel];
		
		self.albumLabel = [[UILabel alloc] initWithFrame:CGRectMake(65, 20, 220, 20)];
		self.albumLabel.backgroundColor = [UIColor clearColor];
		self.albumLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
		self.albumLabel.font = ISMSRegularFont(17);
		self.albumLabel.minimumScaleFactor = 12.0 / self.albumLabel.font.pointSize;
		self.albumLabel.adjustsFontSizeToFitWidth = YES;
		self.albumLabel.textAlignment = NSTextAlignmentCenter;
		self.albumLabel.shadowOffset = CGSizeMake(0, 2);
		self.albumLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.25];
		[self.coverArtBorder addSubview:self.albumLabel];
		
		self.songLabel = [[UILabel alloc] initWithFrame:CGRectMake(65, 37, 220, 20)];
		self.songLabel.backgroundColor = [UIColor clearColor];
		self.songLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
		self.songLabel.font = ISMSBoldFont(17);
		self.songLabel.minimumScaleFactor = 12.0 / self.songLabel.font.pointSize;
		self.songLabel.adjustsFontSizeToFitWidth = YES;
		self.songLabel.textAlignment = NSTextAlignmentCenter;
		self.songLabel.shadowOffset = CGSizeMake(0, 2);
		self.songLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.25];
		[self.coverArtBorder addSubview:self.songLabel];
        		
		[self initSongInfo];
	}
    
    if (SYSTEM_VERSION_LESS_THAN(@"7"))
    {
        self.navigationController.navigationBar.translucent = NO;
        self.navigationController.navigationBar.tintColor = [UIColor blackColor];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
    
	if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
	{
		if (!IS_IPAD())
		{
			self.quickLabel.alpha = 1.0;
			self.shuffleLabel.alpha = 1.0;
			self.jukeboxLabel.alpha = 1.0;
			self.settingsLabel.alpha = 1.0;
			self.chatLabel.alpha = 1.0;
			self.playerLabel.alpha = 1.0;
			
			self.coverArtBorder.alpha = 1.0;
			self.coverArtView.alpha = 1.0;
			self.artistLabel.alpha = 1.0;
			self.albumLabel.alpha = 1.0;
			self.songLabel.alpha = 1.0;
            
            if (IS_TALL_SCREEN())
            {
                // Make sure everything's in the right place
                [self didRotateFromInterfaceOrientation:UIInterfaceOrientationLandscapeLeft];
            }
		}
	}
	else if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
	{
		if (!IS_IPAD())
		{
			self.quickLabel.alpha = 0.0;
			self.shuffleLabel.alpha = 0.0;
			self.jukeboxLabel.alpha = 0.0;
			self.settingsLabel.alpha = 0.0;
			self.chatLabel.alpha = 0.0;
			self.playerLabel.alpha = 0.0;
			
			self.coverArtBorder.alpha = 0.0;
			self.coverArtView.alpha = 0.0;
			self.artistLabel.alpha = 0.0;
			self.albumLabel.alpha = 0.0;
			self.songLabel.alpha = 0.0;
            
            if (IS_TALL_SCREEN())
            {
                // Make sure everything's in the right place
                [self didRotateFromInterfaceOrientation:UIInterfaceOrientationPortrait];
            }
		}
	}
    
    [self addURLRefBackButton];
	
    self.navigationItem.rightBarButtonItem = nil;
	if(musicS.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)];
	}

	/*if(musicS.showPlayerIcon)
	{
		playerButton.enabled = YES;
		playerButton.alpha = 1.0;
	}
	else
	{
		playerButton.enabled = NO;
		playerButton.alpha = 0.5;
	}*/
	
	if (settingsS.isJukeboxEnabled)
	{
		if (IS_IPAD())
			[self.jukeboxButton setImage:[UIImage imageNamed:@"home-jukebox-on-ipad.png"] forState:UIControlStateNormal];
		else
			[self.jukeboxButton setImage:[UIImage imageNamed:@"home-jukebox-on.png"] forState:UIControlStateNormal];
	}
	else
	{
		if (IS_IPAD())
			[self.jukeboxButton setImage:[UIImage imageNamed:@"home-jukebox-off-ipad.png"] forState:UIControlStateNormal];
		else
			[self.jukeboxButton setImage:[UIImage imageNamed:@"home-jukebox-off.png"] forState:UIControlStateNormal];
	}
	
	self.searchSegment.alpha = 0.0;
	self.searchSegment.enabled = NO;
	self.searchSegmentBackground.alpha = 0.0;
	
	[Flurry logEvent:@"HomeTab"];
}

- (void)addURLRefBackButton
{
    if (appDelegateS.referringAppUrl && appDelegateS.mainTabBarController.selectedIndex != 4)
    {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleBordered target:appDelegateS action:@selector(backToReferringApp)];
    }
}

- (void)initSongInfo
{
	ISMSSong *currentSong = playlistS.currentSong ? playlistS.currentSong : playlistS.prevSong;
	
	if (currentSong != nil)
	{		
		self.coverArtView.coverArtId = currentSong.coverArtId;
		
		self.artistLabel.text = @"";
		self.albumLabel.text = @"";
		self.songLabel.text = @"";
		
		if (currentSong.artist)
		{
			self.artistLabel.text = [currentSong.artist copy];
		}
		
		if (currentSong.album)
		{
			self.albumLabel.text = [currentSong.album copy];
		}
		
		if (currentSong.title)
		{
			self.songLabel.text = [currentSong.title copy];
		}
	}
	else
	{
		self.coverArtView.image = [UIImage imageNamed:@"default-album-art.png"];
		self.artistLabel.text = @"Use the Folders tab to find music";
		self.albumLabel.text = @"";
		self.songLabel.text = @"";
	}
}

- (IBAction)quickAlbums
{
	QuickAlbumsViewController *quickAlbums = [[QuickAlbumsViewController alloc] init];
	quickAlbums.parent = self;
	//quickAlbums.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
	if ([quickAlbums respondsToSelector:@selector(setModalPresentationStyle:)])
		quickAlbums.modalPresentationStyle = UIModalPresentationFormSheet;
	
	if (IS_IPAD())
		[appDelegateS.ipadRootViewController presentViewController:quickAlbums animated:YES completion:nil];
	else
		[self presentViewController:quickAlbums animated:YES completion:nil];
	
}

- (IBAction)serverShuffle
{	
	NSDictionary *folders = [SUSRootFoldersDAO folderDropdownFolders];
	
	/*NSString *key = [NSString stringWithFormat:@"folderDropdownCache%@", [appDelegateS.defaultUrl md5]];
	NSData *archivedData = [appDelegateS.settingsDictionary objectForKey:key];
	NSDictionary *folders = [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];*/
	
	if (folders == nil || [folders count] == 2)
	{
		[self performServerShuffle:nil];
	}
	else
	{		
		float height = 65.0f;
		height += (float)[folders count] * 44.0f;
		
		if (height > 300.0f)
			height = 300.0f;
		
		FolderPickerDialog *blankDialog = [[FolderPickerDialog alloc] initWithFrame:CGRectMake(0, 0, 300, height)];
		blankDialog.titleLabel.text = @"Folder to Shuffle";
		[blankDialog show];
	}
}

- (void)performServerShuffle:(NSNotification*)notification 
{
    ISMSServerShuffleLoader *loader = [ISMSServerShuffleLoader loaderWithCallbackBlock:^(BOOL success, NSError *error, ISMSLoader *loader)
    {
        [viewObjectsS hideLoadingScreen];
        
        if (success)
        {
            [musicS playSongAtPosition:0];
            [self showPlayer];
        }
        else
        {
            CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error creating the server shuffle list.\n\nThe connection could not be created" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        }
    }];
    // Display the loading screen
    [viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
    loader.notification = notification;
    [loader startLoad];
    

}

- (void)wbServerShuffle:(NSNotification *)notification
{

}

- (void)cancelLoad
{
	[self.connection cancel];
	self.connection = nil;
	self.receivedData = nil;
	[viewObjectsS hideLoadingScreen];
}

- (IBAction)chat
{
	ChatViewController *chat = [[ChatViewController alloc] initWithNibName:@"ChatViewController" bundle:nil];
	//playlists.isHomeTab = YES;
	[self.navigationController pushViewController:chat animated:YES];
}

- (IBAction)settings
{
	[appDelegateS showSettings];

//	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
//	if (IS_IPAD())
//	{
//		[appDelegateS.ipadRootViewController.menuViewController showSettings];
//	}
//	else
//	{
//		serverListViewController.hidesBottomBarWhenPushed = YES;
//		[self.navigationController pushViewController:serverListViewController animated:YES];
//	}
}

- (IBAction)player
{
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:streamingPlayerViewController animated:YES];
}

- (IBAction)support:(id)sender
{	
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Support" message:@"iSub support is happy to help with any issues you may have! \n\nWould you like to send an email to support or visit the iSub forum?" delegate:appDelegateS cancelButtonTitle:@"Not Now" otherButtonTitles:@"Send Email", @"iSub Forum", nil];
	alert.tag = 7;
	[alert show];
	//[Crittercism showCrittercism:self];
}

- (void)nowPlayingAction:(id)sender
{
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
}

- (void)jukeboxOff
{
	if (IS_IPAD())
		[self.jukeboxButton setImage:[UIImage imageNamed:@"home-jukebox-off-ipad.png"] forState:UIControlStateNormal];
	else
		[self.jukeboxButton setImage:[UIImage imageNamed:@"home-jukebox-off.png"] forState:UIControlStateNormal];
	
	[self initSongInfo];
}

- (IBAction)jukebox
{
    if (settingsS.isJukeboxEnabled)
    {
        // Jukebox mode is on, turn it off
        if (IS_IPAD())
            [self.jukeboxButton setImage:[UIImage imageNamed:@"home-jukebox-off-ipad.png"] forState:UIControlStateNormal];
        else
            [self.jukeboxButton setImage:[UIImage imageNamed:@"home-jukebox-off.png"] forState:UIControlStateNormal];
        settingsS.isJukeboxEnabled = NO;
        
        appDelegateS.window.backgroundColor = viewObjectsS.windowColor;
        
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_JukeboxDisabled];
        
        [Flurry logEvent:@"JukeboxDisabled"];
    }
    else
    {
        [audioEngineS.player stop];
        
        // Jukebox mode is off, turn it on
        if (IS_IPAD())
            [self.jukeboxButton setImage:[UIImage imageNamed:@"home-jukebox-on-ipad.png"] forState:UIControlStateNormal];
        else
            [self.jukeboxButton setImage:[UIImage imageNamed:@"home-jukebox-on.png"] forState:UIControlStateNormal];
        settingsS.isJukeboxEnabled = YES;
        
        [jukeboxS jukeboxGetInfo];
        
        appDelegateS.window.backgroundColor = viewObjectsS.jukeboxColor;
        
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_JukeboxEnabled];
        
        [Flurry logEvent:@"JukeboxEnabled"];
    }
    
    [self initSongInfo];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -
#pragma mark Search Bar Delgate

- (void)searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar
{	
	//NSString *key = [NSString stringWithFormat:@"isNewSearchAPI%@", [appDelegateS.defaultUrl md5]];
	
	// Create search overlay
	self.searchOverlay = [[UIView alloc] init];
	//if ([[appDelegateS.settingsDictionary objectForKey:key] isEqualToString:@"YES"])
	if (settingsS.isNewSearchAPI)
	{
		if (IS_IPAD())
			self.searchOverlay.frame = CGRectMake(0, 86, 1024, 1024);
		else
			self.searchOverlay.frame = CGRectMake(0, 82, 480, 480);
	}
	else
	{
		if (IS_IPAD())
			self.searchOverlay.frame = CGRectMake(0, 44, 1024, 1024);
		else
			self.searchOverlay.frame = CGRectMake(0, 44, 480, 480);
	}
	
	self.searchOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.searchOverlay.backgroundColor = [UIColor colorWithWhite:0 alpha:.80];
	self.searchOverlay.alpha = 0.0;
	[self.view addSubview:self.searchOverlay];
		
	self.dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.dismissButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.dismissButton addTarget:self.searchBar action:@selector(resignFirstResponder) forControlEvents:UIControlEventTouchUpInside];
	self.dismissButton.frame = self.view.bounds;
	self.dismissButton.enabled = NO;
	[self.searchOverlay addSubview:self.dismissButton];
	
	// Animate the segmented control on screen
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
	//if ([[appDelegateS.settingsDictionary objectForKey:key] isEqualToString:@"YES"])
	if (settingsS.isNewSearchAPI)
	{
		self.searchSegment.enabled = YES;
		self.searchSegment.alpha = 1;
		self.searchSegmentBackground.alpha = 1;
	}
	self.searchOverlay.alpha = 1;
	self.dismissButton.enabled = YES;
	[UIView commitAnimations];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)theSearchBar
{
	// Animate the segmented control off screen
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
	//NSString *key = [NSString stringWithFormat:@"isNewSearchAPI%@", [appDelegateS.defaultUrl md5]];
	//if ([[appDelegateS.settingsDictionary objectForKey:key] isEqualToString:@"YES"])
	if (settingsS.isNewSearchAPI)
	{
		self.searchSegment.alpha = 0;
		self.searchSegment.enabled = NO;
		self.searchSegmentBackground.alpha = 0;
	}
	self.searchOverlay.alpha = 0;
	self.dismissButton.enabled = NO;
	[UIView commitAnimations];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)theSearchBar
{
	self.isSearch = YES;
	
	[self.searchBar resignFirstResponder];
	
	NSString *searchTerms = [searchBar.text stringByTrimmingLeadingAndTrailingWhitespace];
//DLog(@"-%@-", searchTerms);
	
    NSDictionary *parameters = nil;
    NSString *action = nil;
	if (settingsS.isNewSearchAPI)
	{
        // Due to a Subsonic bug, to get good search results, we need to add a * to the end of
        // Latin based languages, but not to unicode languages like Japanese.
        BOOL isLatin = [searchTerms canBeConvertedToEncoding:NSISOLatin1StringEncoding];
		NSString *searchTermsString = isLatin ? [NSString stringWithFormat:@"%@*", searchTerms] : searchTerms;
        
        action = @"search2";
		if (self.searchSegment.selectedSegmentIndex == 0)
		{
            parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"20", @"artistCount", @"0", @"albumCount", @"0", @"songCount", 
                          n2N(searchTermsString), @"query", nil];
		}
		else if (self.searchSegment.selectedSegmentIndex == 1)
		{
            parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"0", @"artistCount", @"20", @"albumCount", @"0", @"songCount", 
                          n2N(searchTermsString), @"query", nil];
		}
		else if (searchSegment.selectedSegmentIndex == 2)
		{
            parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"0", @"artistCount", @"0", @"albumCount", @"20", @"songCount", 
                          n2N(searchTermsString), @"query", nil];
		}
		else
		{
            parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"20", @"artistCount", @"20", @"albumCount", @"20", @"songCount", 
                          n2N(searchTermsString), @"query", nil];
		}
	}
	else
	{
        action = @"search";
        parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"20", @"count", n2N(searchTerms), @"any", nil];
	}
		
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:action parameters:parameters];
    
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		self.receivedData = [NSMutableData dataWithLength:0];
		
		// Display the loading screen
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error performing the search.\n\nThe connection could not be created" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
	}
}

#pragma mark -
#pragma mark Connection delegate

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
	[self.receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	// Inform the user that the connection failed.
	NSString *message;
	if (isSearch)
	{
		message = [NSString stringWithFormat:@"There was an error completing the search.\n\nError:%@", error.localizedDescription];
	}
	else
	{
		message = [NSString stringWithFormat:@"There was an error creating the server shuffle list.\n\nError:%@", error.localizedDescription];
	}
	
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	
	self.connection = nil;
	self.receivedData = nil;
	
	[viewObjectsS hideLoadingScreen];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
    //DLog(@"received data: %@", [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding]);
	
	if (isSearch)
	{
		// It's a search
		
		NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:receivedData];
		SearchXMLParser *parser = (SearchXMLParser*)[[SearchXMLParser alloc] initXMLParser];
		[xmlParser setDelegate:parser];
		[xmlParser parse];
		
		/*NSString *key = [NSString stringWithFormat:@"isNewSearchAPI%@", [appDelegateS.defaultUrl md5]];
		BOOL isNewSearchAPI = NO;
		if ([[appDelegateS.settingsDictionary objectForKey:key] isEqualToString:@"YES"])
			isNewSearchAPI = YES;
		
		if (isNewSearchAPI && searchSegment.selectedSegmentIndex == 3)*/
		if (settingsS.isNewSearchAPI && searchSegment.selectedSegmentIndex == 3)
		{
			SearchAllViewController *searchViewController = [[SearchAllViewController alloc] initWithNibName:@"SearchAllViewController" 
																						   bundle:nil];
			searchViewController.listOfArtists = [NSMutableArray arrayWithArray:parser.listOfArtists];
			searchViewController.listOfAlbums = [NSMutableArray arrayWithArray:parser.listOfAlbums];
			searchViewController.listOfSongs = [NSMutableArray arrayWithArray:parser.listOfSongs];
			
			searchViewController.query = [NSString stringWithFormat:@"%@*", searchBar.text];
			
			
			//[self.navigationController pushViewController:searchViewController animated:YES];
			[self pushViewControllerCustom:searchViewController];
			
		}
		else
		{
			SearchSongsViewController *searchViewController = [[SearchSongsViewController alloc] initWithNibName:@"SearchSongsViewController" 
																										  bundle:nil];
			searchViewController.title = @"Search";
			//if (isNewSearchAPI)
			if (settingsS.isNewSearchAPI)
			{
				if (self.searchSegment.selectedSegmentIndex == 0)
				{
					searchViewController.listOfArtists = [NSMutableArray arrayWithArray:parser.listOfArtists];
					//DLog(@"%@", searchViewController.listOfArtists);
				}
				else if (self.searchSegment.selectedSegmentIndex == 1)
				{
					searchViewController.listOfAlbums = [NSMutableArray arrayWithArray:parser.listOfAlbums];
					//DLog(@"%@", searchViewController.listOfAlbums);
				}
				else if (self.searchSegment.selectedSegmentIndex == 2)
				{
					searchViewController.listOfSongs = [NSMutableArray arrayWithArray:parser.listOfSongs];
					//DLog(@"%@", searchViewController.listOfSongs);
				}
				
				searchViewController.searchType = (ISMSSearchSongsSearchType)searchSegment.selectedSegmentIndex;
				searchViewController.query = [NSString stringWithFormat:@"%@*", searchBar.text];
			}
			else
			{
				searchViewController.listOfSongs = [NSMutableArray arrayWithArray:parser.listOfSongs];
				searchViewController.searchType = 2;
				searchViewController.query = searchBar.text;
			}
			
			
			[self pushViewControllerCustom:searchViewController];
			//[self.navigationController pushViewController:searchViewController animated:YES];
			
		}
		
		// Hide the loading screen
		[viewObjectsS hideLoadingScreen];
	}
	else
	{
    }
}


@end
