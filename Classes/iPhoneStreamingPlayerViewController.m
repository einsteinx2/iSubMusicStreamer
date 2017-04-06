//
//  iPhoneStreamingPlayerViewController.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "iPhoneStreamingPlayerViewController.h"
#import "PageControlViewController.h"
#import <QuartzCore/CoreAnimation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <CFNetwork/CFNetwork.h>
#import <QuartzCore/QuartzCore.h>
#import "EqualizerViewController.h"
#import "OBSlider.h"
#import "StoreViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "ISMSStreamHandler.h"

#define downloadProgressBorder 4.
#define downloadProgressWidth (self.progressSlider.frame.size.width - (downloadProgressBorder * 2))


@interface iPhoneStreamingPlayerViewController ()
@property (strong) NSDictionary *originalViewFrames;
- (void)createReflection;
- (void)initSongInfo;
- (void)setStopButtonImage;
- (void)setPlayButtonImage;
- (void)setPauseButtonImage;
- (void)updateBarButtonImage;
- (void)registerForNotifications;
- (void)unregisterForNotifications;
- (void)createDownloadProgressView;
- (void)createLandscapeViews;
- (void)updateFormatLabel;
- (void)hideExtraButtons;
@end

@implementation iPhoneStreamingPlayerViewController

static const CGFloat kDefaultReflectionFraction = 0.30;
static const CGFloat kDefaultReflectionOpacity = 0.55;

#pragma mark -
#pragma mark Controller Life Cycle

- (BOOL)prefersStatusBarHidden
{
    return NO;
}

- (NSString *)stringFromSeconds:(NSUInteger)seconds
{
	if (seconds < 60)
		return [NSString stringWithFormat:@"%lus", (unsigned long)seconds];
	else
		return [NSString stringWithFormat:@"%lum", (long)(seconds / 60)];
}

- (void)showStore
{	
	if (self.isFlipped)
		[self songInfoToggle:nil];
	
	StoreViewController *store = [[StoreViewController alloc] init];
	//[self pushViewControllerCustom:store];
	[self.navigationController pushViewController:store animated:YES];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
    
    if (IS_IOS7())
    {
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;
        
        self.volumeSlider.y -= 5.;
        self.eqButton.y -= 5.;
        self.prevButton.y -= 5.;
        self.playButton.y -= 5.;
        self.nextButton.y -= 5.;
        self.extraButtonsButton.y -= 5.;
        
        self.progressSlider.superview.y -= 2.;
        
        [self.progressSlider setThumbImage:[UIImage imageNamed:@"controller-slider-thumb.png"] forState:UIControlStateNormal];
    }
	
    //DLog(@"coverArtImageView class: %@", NSStringFromClass(coverArtImageView.class));
	
	self.extraButtonsButtonOffImage = [UIImage imageNamed:@"controller-extras.png"];
	self.extraButtonsButtonOnImage = [UIImage imageNamed:@"controller-extras-on.png"];
	
	// Set default values
	self.pageControlViewController = nil;
	self.isFlipped = NO;
	self.isExtraButtonsShowing = NO;
	self.pauseSlider = NO;
	
	self.coverArtImageView.isLarge = YES;
	//coverArtImageView.delegate = self;

	// Create the extra views not in the XIB file
    if (IS_TALL_SCREEN() && UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
    {
        [self showTallPlayerButtons];
        
        // Only show Extra Buttons Button if the Show Large Song Info setting is turned on
        if (!settingsS.isShowLargeSongInfoInPlayer)
        {
            self.extraButtonsButton.hidden = YES;
        }
        else
        {
            self.extraButtonsButton.hidden = NO;
        }
    }
    
    if (!IS_IOS7())
    {
        self.progressSlider.y += 2.;
    }
    
	[self createDownloadProgressView];
	[self createLandscapeViews];
	
	// Setup the navigation controller buttons
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"player-overlay.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(songInfoToggle:)];
	if (!IS_IPAD())
    {
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"back.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(backAction:)];
    }
    
	// Initialize the song info
	//[self initSongInfo];
	
    // This also calls init song info, so no need to call it explicitly above
	[self jukeboxToggled];
	
	// Setup the cover art reflection
	self.reflectionHeight = self.coverArtImageView.bounds.size.height * kDefaultReflectionFraction;
	self.reflectionView.height = self.reflectionHeight;
	self.reflectionView.image = [self.coverArtImageView reflectedImageWithHeight:self.reflectionHeight];
	self.reflectionView.alpha = kDefaultReflectionOpacity;
	if (self.isFlipped)
		self.reflectionView.alpha = 0.0;
	
	// Register for all notifications
	[self registerForNotifications];
	
    if (!IS_TALL_SCREEN())
    {
        [self extraButtonsToggleAnimated:NO saveState:NO];
        if (!settingsS.isExtraPlayerControlsShowing)
            [self performSelector:@selector(hideExtraButtons) withObject:nil afterDelay:4.0];
    }
	
	// Show the song info screen automatically if the setting is enabled
	if (settingsS.isPlayerPlaylistShowing)
	{
		[self playlistToggleAnimated:NO saveState:NO];
	}
	
	self.coverArtHolderView.layer.masksToBounds = YES;
	
	if (IS_IPAD())
	{
		// Fix some positions
		self.eqButton.y -= 10;
		self.prevButton.y -= 10;
		self.playButton.y -= 10;
		self.nextButton.y -= 10;
		self.extraButtonsButton.y -= 10;
		self.volumeSlider.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin;
		self.volumeSlider.y += 5;
	}
	
	self.swipeDetector = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(songInfoToggle:)];
    self.swipeDetector.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.songInfoToggleButton addGestureRecognizer:self.swipeDetector];
    self.swipeDetector.delegate = self;
    
    // Fix starting in landscape on iPhone 5
    if (IS_TALL_SCREEN() && UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
    {
        NSArray *viewsToSkip = @[self.reflectionView, self.artistLabel, self.albumLabel, self.titleLabel];
        for(UIView *subview in self.view.subviews)
        {
            if (![viewsToSkip containsObject:subview])
                subview.x += 44.;
        }
    }
}

- (void)showTallPlayerButtons
{
    //[self.songInfoView removeFromSuperview];
    //[self.extraButtons removeFromSuperview];
    
    //self.extraButtonsButton.hidden = YES;
    self.extraButtonsButton.enabled = YES;
    
    if (self.coverArtHolderView.y != 100.)
    {
        for (UIView *subview in self.view.subviews)
        {
            subview.y += 100.;
        }
    }
    
    self.songInfoView.frame = CGRectMake(0., 73., 320., self.songInfoView.height);
    [self.view addSubview:self.songInfoView];
    
    self.extraButtons.frame = CGRectMake(0., 0., 320., self.extraButtons.height);
    [self.view addSubview:self.extraButtons];
}

- (void)removeTallPlayerButtons
{
    [self.songInfoView removeFromSuperview];
    [self.extraButtons removeFromSuperview];
    
    self.extraButtonsButton.hidden = NO;
    self.extraButtonsButton.enabled = YES;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
		
	if (settingsS.isJukeboxEnabled)
	{
		[jukeboxS jukeboxGetInfo];
		
		self.view.backgroundColor = viewObjectsS.jukeboxColor;
	}
	else 
	{
		self.view.backgroundColor = [UIColor blackColor]; 
	}
	
	if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation) || IS_IPAD())
	{
		[self createSongTitle];
	}
	
	[self updateDownloadProgress];
	[self updateSlider];
	
	if (settingsS.isJukeboxEnabled)
	{
		[jukeboxS jukeboxGetInfo];
		
		if (jukeboxS.jukeboxIsPlaying)
			[self setStopButtonImage];
		else 
			[self setPlayButtonImage];
	}
	else
	{
		if(audioEngineS.player.isPlaying)
			[self setPauseButtonImage];
		else
			[self setPlayButtonImage];
	}
	
	NSString *imageName = settingsS.isEqualizerOn ? @"controller-equalizer-on.png" : @"controller-equalizer.png";
	[self.eqButton setImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
	
	[self quickSecondsSetLabels];

}

- (void)quickSecondsSetLabels
{
	NSString *quickSeconds = [self stringFromSeconds:settingsS.quickSkipNumberOfSeconds];
	self.quickBackLabel.text = quickSeconds;
	self.quickForwLabel.text = quickSeconds;
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	if (!settingsS.isExtraPlayerControlsShowing)
	{
		if (self.isExtraButtonsShowing)
			[self extraButtonsToggleAnimated:NO saveState:NO];
	}
}

- (void)asyncImageViewFinishedLoading:(AsynchronousImageView *)asyncImageView
{
	[self createReflection];
}

- (void)largeSongInfoWasToggled
{
	if (self.isExtraButtonsShowing)
	{
		[self extraButtonsToggleAnimated:NO saveState:NO];
		[self extraButtonsToggleAnimated:NO saveState:NO];
	}
}

- (void)registerForNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(jukeboxToggled) 
												 name:ISMSNotification_JukeboxDisabled object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(jukeboxToggled) 
												 name:ISMSNotification_JukeboxEnabled object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setPlayButtonImage) 
												 name:ISMSNotification_SongPlaybackEnded object:nil];
    
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setPlayButtonImage) 
												 name:ISMSNotification_SongPlaybackPaused object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setPauseButtonImage) 
												 name:ISMSNotification_SongPlaybackStarted object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initSongInfo) 
												 name:ISMSNotification_JukeboxSongInfo object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initSongInfo) 
												 name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initSongInfo) 
												 name:ISMSNotification_ServerSwitched object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initSongInfo) 
												 name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateShuffleIcon) 
												 name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(songInfoToggle:) 
												 name:@"hideSongInfo" object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(largeSongInfoWasToggled) name:ISMSNotification_LargeSongInfoToggle object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showStore) name:@"player show store" object:nil];
	
	if (IS_IPAD())
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showPlayerOverlayTemp) 
													 name:ISMSNotification_ShowPlayer object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initSongInfo) 
													 name:ISMSNotification_ShowPlayer object:nil];
	}
}

- (void)unregisterForNotifications
{
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:ISMSNotification_JukeboxEnabled object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:ISMSNotification_JukeboxDisabled object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:ISMSNotification_SongPlaybackEnded object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:ISMSNotification_SongPlaybackPaused object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:ISMSNotification_SongPlaybackStarted object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:ISMSNotification_ServerSwitched object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:ISMSNotification_JukeboxSongInfo object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self 
													name:@"hideSongInfo" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_LargeSongInfoToggle object:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:@"player show store" object:nil];
	
	if (IS_IPAD())
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self 
														name:ISMSNotification_ShowPlayer object:nil];
	}
}

- (void)createDownloadProgressView
{
	self.downloadProgress = [[UIView alloc] initWithFrame:self.progressSlider.frame];
	self.downloadProgress.x = 0.0;
	self.downloadProgress.y = 0.0;
	self.downloadProgress.backgroundColor = [UIColor whiteColor];
	self.downloadProgress.alpha = 0.3;
	self.downloadProgress.userInteractionEnabled = NO;
	self.downloadProgress.width = 0.0;
	self.downloadProgress.layer.cornerRadius = 5;
	[self.progressSlider addSubview:self.downloadProgress];
    
    if (IS_IOS7())
    {
        self.downloadProgress.height -= 20.;
        self.downloadProgress.y += 1.;
        self.downloadProgress.layer.cornerRadius = 1.;
        [self.downloadProgress centerVertically];
    }
	
	if (settingsS.isJukeboxEnabled)
		self.downloadProgress.hidden = YES;
}

- (void)createLandscapeViews
{
	// Setup landscape orientation if necessary
	if (!IS_IPAD())
	{
		self.artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(IS_TALL_SCREEN() ? 349 : 305, 60, 170, 30)];
		self.artistLabel.backgroundColor = [UIColor clearColor];
		self.artistLabel.textColor = [UIColor colorWithWhite:.7 alpha:1.];
		self.artistLabel.font = ISMSBoldFont(22);
		self.artistLabel.adjustsFontSizeToFitWidth = YES;
		self.artistLabel.textAlignment = NSTextAlignmentCenter;
		[self.view addSubview:self.artistLabel];
		[self.view sendSubviewToBack:self.artistLabel];
		
		self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(IS_TALL_SCREEN() ? 349 : 305, 90, 170, 30)];
		self.titleLabel.backgroundColor = [UIColor clearColor];
		self.titleLabel.textColor = [UIColor whiteColor];
		self.titleLabel.font = ISMSBoldFont(24);
		self.titleLabel.adjustsFontSizeToFitWidth = YES;
		self.titleLabel.textAlignment = NSTextAlignmentCenter;
		[self.view addSubview:self.titleLabel];
		[self.view sendSubviewToBack:self.titleLabel];
		
		self.albumLabel = [[UILabel alloc] initWithFrame:CGRectMake(IS_TALL_SCREEN() ? 349 : 305, 120, 170, 30)];
		self.albumLabel.backgroundColor = [UIColor clearColor];
		self.albumLabel.textColor = [UIColor colorWithWhite:.7 alpha:1.];
		self.albumLabel.font = ISMSRegularFont(22);
		self.albumLabel.adjustsFontSizeToFitWidth = YES;
		self.albumLabel.textAlignment = NSTextAlignmentCenter;
		[self.view addSubview:self.albumLabel];
		[self.view sendSubviewToBack:self.albumLabel];
		
		NSMutableDictionary *positions = [NSMutableDictionary dictionaryWithCapacity:0];
		[positions setObject:[NSValue valueWithCGRect:self.volumeSlider.frame] forKey:@"volumeSlider"];
		[positions setObject:[NSValue valueWithCGRect:self.coverArtHolderView.frame] forKey:@"coverArtHolderView"];
		[positions setObject:[NSValue valueWithCGRect:self.prevButton.frame] forKey:@"prevButton"];
		[positions setObject:[NSValue valueWithCGRect:self.playButton.frame] forKey:@"playButton"];
		[positions setObject:[NSValue valueWithCGRect:self.nextButton.frame] forKey:@"nextButton"];
		[positions setObject:[NSValue valueWithCGRect:self.eqButton.frame] forKey:@"eqButton"];
		[positions setObject:[NSValue valueWithCGRect:self.extraButtonsButton.frame] forKey:@"extraButtonsButton"];
        [positions setObject:[NSValue valueWithCGRect:self.artistLabel.frame] forKey:@"artistLabel"];
        [positions setObject:[NSValue valueWithCGRect:self.albumLabel.frame] forKey:@"albumLabel"];
        [positions setObject:[NSValue valueWithCGRect:self.titleLabel.frame] forKey:@"titleLabel"];
		self.originalViewFrames = [NSDictionary dictionaryWithDictionary:positions];
		
		if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
		{
			self.coverArtHolderView.frame = CGRectMake(0, 0, 300, 270);
			self.prevButton.origin = CGPointMake(315, 184);
			self.playButton.origin = CGPointMake(372.5, 184);
			self.nextButton.origin = CGPointMake(425, 184);
			self.volumeSlider.frame = CGRectMake(300, 244, 180, 55);
			self.volumeView.frame = CGRectMake(0, 0, 180, 55);
			self.eqButton.origin = CGPointMake(328, 20);
			self.extraButtonsButton.origin = CGPointMake(418, 20);
		}
		else
		{
			self.artistLabel.alpha = 0.1;
			self.albumLabel.alpha = 0.1;
			self.titleLabel.alpha = 0.1;
		}
	}
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{	
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	self.coverArtImageView.delegate = nil;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Rotation

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
    if (!IS_IPAD())
    {
        if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
        {
            //[self setSongTitle];
            [self createSongTitle];
        }
        else
        {
            [self removeSongTitle];
        }
    }
    
    if (IS_TALL_SCREEN() && UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
    {
        [UIView animateWithDuration:.25 animations:^
         {
             self.extraButtons.alpha = 0.0;
             self.songInfoView.alpha = 0.0;
         }
        completion:^(BOOL finished)
         {
             if (finished)
             {
                 [self removeTallPlayerButtons];
                 
                 if (settingsS.isExtraPlayerControlsShowing)
                 {
                     self.isExtraButtonsShowing = NO;
                     [self extraButtonsToggleAnimated:YES saveState:NO];
                 }
             }
         }];
    }
    else if (IS_TALL_SCREEN())
    {
        if (self.isExtraButtonsShowing)
        {
            [self extraButtonsToggleAnimated:NO saveState:NO];
        }
    }
	
	if (!IS_IPAD())
	{
		[UIView beginAnimations:@"rotate" context:nil];
		[UIView setAnimationDuration:duration];
		if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
		{
			self.coverArtHolderView.frame = [[self.originalViewFrames objectForKey:@"coverArtHolderView"] CGRectValue];
			self.prevButton.frame = [[self.originalViewFrames objectForKey:@"prevButton"] CGRectValue];
			self.playButton.frame = [[self.originalViewFrames objectForKey:@"playButton"] CGRectValue];
			self.nextButton.frame = [[self.originalViewFrames objectForKey:@"nextButton"] CGRectValue];
			self.eqButton.frame = [[self.originalViewFrames objectForKey:@"eqButton"] CGRectValue];
			self.extraButtonsButton.frame = [[self.originalViewFrames objectForKey:@"extraButtonsButton"] CGRectValue];
			self.volumeSlider.frame = [[self.originalViewFrames objectForKey:@"volumeSlider"] CGRectValue];
            //self.artistLabel.frame = [[self.originalViewFrames objectForKey:@"artistLabel"] CGRectValue];
            //self.albumLabel.frame = [[self.originalViewFrames objectForKey:@"albumLabel"] CGRectValue];
            //self.titleLabel.frame = [[self.originalViewFrames objectForKey:@"titleLabel"] CGRectValue];
			
			CGRect volumeFrame = [[self.originalViewFrames objectForKey:@"volumeSlider"] CGRectValue];
			volumeFrame.origin.x = 0;
			volumeFrame.origin.y = 0;
			
			if (settingsS.isJukeboxEnabled)
				self.jukeboxVolumeView.frame = volumeFrame;
			else
				self.volumeView.frame = volumeFrame;
			
			self.artistLabel.alpha = 0.1;
			self.albumLabel.alpha = 0.1;
			self.titleLabel.alpha = 0.1;
			
			CGFloat width = 320 * self.pageControlViewController.numberOfPages;
			CGFloat height = self.pageControlViewController.numberOfPages == 1 ? 320 : 300;
			self.pageControlViewController.scrollView.contentSize = CGSizeMake(width, height);
            [self.pageControlViewController changePage:self.pageControlViewController.pageControl];
		}
		else if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
		{
			self.coverArtHolderView.frame = CGRectMake(0, 0, 300, 270);
			self.prevButton.origin = CGPointMake(315, 184);
			self.playButton.origin = CGPointMake(372.5, 184);
			self.nextButton.origin = CGPointMake(425, 184);
			self.eqButton.origin = CGPointMake(328, 20);
			self.extraButtonsButton.origin = CGPointMake(418, 20);
			self.volumeSlider.frame = CGRectMake(300, 244, 180, 55);
            self.artistLabel.frame = [[self.originalViewFrames objectForKey:@"artistLabel"] CGRectValue];
            self.albumLabel.frame = [[self.originalViewFrames objectForKey:@"albumLabel"] CGRectValue];
            self.titleLabel.frame = [[self.originalViewFrames objectForKey:@"titleLabel"] CGRectValue];
			
			if (settingsS.isJukeboxEnabled)
				self.jukeboxVolumeView.frame = CGRectMake(0, 0, 180, 22.5);
			else
				self.volumeView.frame = CGRectMake(0, 0, 180, 55);
			
			self.navigationItem.titleView = nil;
			
			self.artistLabel.alpha = 1.0;
			self.albumLabel.alpha = 1.0;
			self.titleLabel.alpha = 1.0;
			
			CGFloat width = 300 * self.pageControlViewController.numberOfPages;
			CGFloat height = self.pageControlViewController.numberOfPages == 1 ? 270 : 250;
			self.pageControlViewController.scrollView.contentSize = CGSizeMake(width, height);
            [self.pageControlViewController changePage:self.pageControlViewController.pageControl];
            
            if (IS_TALL_SCREEN())
            {
                NSArray *viewsToSkip = @[self.reflectionView, self.artistLabel, self.albumLabel, self.titleLabel];
                for(UIView *subview in self.view.subviews)
                {
                    if (![viewsToSkip containsObject:subview])
                        subview.x += 44.;
                }
            }
		}
		[UIView commitAnimations];
	}
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	
	if (!IS_IPAD() && UIInterfaceOrientationIsLandscape(fromInterfaceOrientation))
	{
		[self createSongTitle];
	}
    
    if (IS_TALL_SCREEN() && UIInterfaceOrientationIsLandscape(fromInterfaceOrientation))
    {
        self.extraButtons.alpha = 0.0;
        self.songInfoView.alpha = 0.0;
        [self showTallPlayerButtons];
        [UIView animateWithDuration:.25 animations:^
         {
             self.extraButtons.alpha = 1.0;
             self.songInfoView.alpha = 1.0;
         }];
    }
}

#pragma mark Main

- (void)showPlayerOverlayTemp
{
	if (!self.isFlipped && !self.isExtraButtonsShowing)
	{
		[self extraButtonsToggleAnimated:NO saveState:NO];
		if (!settingsS.isExtraPlayerControlsShowing)
			[self performSelector:@selector(hideExtraButtons) withObject:nil afterDelay:4.0];
	}
}

- (void)setPlayButtonImage
{		
	[self.playButton setImage:[UIImage imageNamed:@"controller-play.png"] forState:0];
}


- (void)setPauseButtonImage
{
	[self.playButton setImage:[UIImage imageNamed:@"controller-pause.png"] forState:0];
}

- (void)setStopButtonImage
{
	[self.playButton setImage:[UIImage imageNamed:@"controller-stop.png"] forState:0];
}
 
- (void)createSongTitle
{
	if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation) || IS_IPAD())
	{
		self.navigationItem.titleView = nil;
		
		float width = 180;
		
		UIView *titleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 40)];
		titleView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		
		CGRect artistFrame = CGRectMake(0, -2, width, 15);
		CGRect songFrame   = CGRectMake(0, 10, width, 15);
		CGRect albumFrame  = CGRectMake(0, 23, width, 15);
		
		NSUInteger artistSize = 11;
		NSUInteger songSize   = 12;
		NSUInteger albumSize  = 11;
		
		self.artistTitleLabel = [[UILabel alloc] initWithFrame:artistFrame];
		self.artistTitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.artistTitleLabel.backgroundColor = [UIColor clearColor];
		self.artistTitleLabel.textColor = [UIColor colorWithWhite:.7 alpha:1.];
		self.artistTitleLabel.font = ISMSBoldFont(artistSize);
		self.artistTitleLabel.textAlignment = NSTextAlignmentCenter;
		[titleView addSubview:self.artistTitleLabel];
		
		self.songTitleLabel = [[UILabel alloc] initWithFrame:songFrame];
		//MarqueeLabel *song = [[MarqueeLabel alloc] initWithFrame:songFrame andRate:50.0 andBufer:6.0];
		self.songTitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.songTitleLabel.backgroundColor = [UIColor clearColor];
		self.songTitleLabel.textColor = [UIColor whiteColor];
		self.songTitleLabel.font = ISMSBoldFont(songSize);
		self.songTitleLabel.textAlignment = NSTextAlignmentCenter;
		[titleView addSubview:self.songTitleLabel];
		
		self.albumTitleLabel = [[UILabel alloc] initWithFrame:albumFrame];
		self.albumTitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.albumTitleLabel.backgroundColor = [UIColor clearColor];
		self.albumTitleLabel.textColor = [UIColor colorWithWhite:.7 alpha:1.];
		self.albumTitleLabel.font = ISMSBoldFont(albumSize);
		self.albumTitleLabel.textAlignment = NSTextAlignmentCenter;
		[titleView addSubview:self.albumTitleLabel];
				
		self.artistTitleLabel.text = self.currentSong.artist;
		self.albumTitleLabel.text = self.currentSong.album;
		self.songTitleLabel.text = self.currentSong.title;
		
		self.navigationItem.titleView = titleView;		
	}
}

- (void)removeSongTitle
{
	self.navigationItem.titleView = nil;
	self.artistTitleLabel = nil;
	self.albumTitleLabel = nil;
	self.songTitleLabel = nil;
}

- (void)setSongTitle
{
	if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation) || IS_IPAD())
	{		
		self.artistTitleLabel.text = self.currentSong.artist;
		self.albumTitleLabel.text = self.currentSong.album;
		self.songTitleLabel.text = self.currentSong.title;
	}
}

- (void)initSongInfo
{	
	self.currentSong = playlistS.currentDisplaySong;
	
	self.lastProgress = NSUIntegerMax;
	
	//DLog(@"currentSong parentId: %@", currentSong.parentId);
	
	if (self.currentSong.parentId)
	{
		self.currentAlbumButton.enabled = YES;
		self.currentAlbumButton.alpha = 1.0;
	}
	else
	{
		self.currentAlbumButton.enabled = NO;
		self.currentAlbumButton.alpha = 0.5;
	}
	
    [self setSongTitle];
	self.coverArtImageView.coverArtId = self.currentSong.coverArtId;
//DLog(@"player coverArtId: %@", currentSong.coverArtId);
    [self createReflection];
    
	// Update the icon in top right
	if (self.isFlipped)
	{
		//DLog(@"Updating the top right button");
		[self updateBarButtonImage];
	}
	
	self.artistLabel.text = self.currentSong.artist;
	self.albumLabel.text = self.currentSong.album;
	self.titleLabel.text = self.currentSong.title;
	
	self.largeOverlayArtist.text = self.currentSong.artist;
	self.largeOverlayAlbum.text = self.currentSong.album;
	self.largeOverlaySong.text = self.currentSong.title;
	
	if (settingsS.isJukeboxEnabled)
	{
		self.jukeboxVolumeView.value = jukeboxS.jukeboxGain;
		
		if (jukeboxS.jukeboxIsPlaying)
			[self setStopButtonImage];
		else 
			[self setPlayButtonImage];
	}
	
	self.hasMoved = NO;
	self.oldPosition = 0.0;
	self.progressSlider.minimumValue = 0.0;
    self.progressSlider.alpha = 1.0;
    self.elapsedTimeLabel.alpha = 1.0;
    self.remainingTimeLabel.alpha = 1.0;
	if (!settingsS.isJukeboxEnabled && self.currentSong.duration && [self.currentSong.duration intValue] > 0)
	{
		self.progressSlider.maximumValue = [self.currentSong.duration floatValue];
		self.progressSlider.enabled = YES;
	}
	else
	{
		self.progressSlider.maximumValue = 0.0;
		self.progressSlider.enabled = NO;
        self.progressSlider.alpha = 0.5;
        self.elapsedTimeLabel.alpha = 0.5;
        self.remainingTimeLabel.alpha = 0.5;
	}
	
	[self.repeatButton setImage:[UIImage imageNamed:@"controller-repeat.png"] forState:0];
	self.repeatButton.enabled = NO;
	if (!settingsS.isJukeboxEnabled)
	{
		self.repeatButton.enabled = YES;
		if(playlistS.repeatMode == 1)
		{
			[self.repeatButton setImage:[UIImage imageNamed:@"controller-repeat-one.png"] forState:0];
		}
		else if(playlistS.repeatMode == 2)
		{
			[self.repeatButton setImage:[UIImage imageNamed:@"controller-repeat-all.png"] forState:0];
		}
	}
	
	self.eqButton.enabled = YES;
	self.back30Button.enabled = YES;
	self.forw30Button.enabled = YES;
	if (settingsS.isJukeboxEnabled)
	{
		self.eqButton.enabled = NO;
		self.back30Button.enabled = NO;
		self.forw30Button.enabled = NO;
	}
	
	[self updateShuffleIcon];
	
	__block NSInteger bookmarkCount;
	[databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db)
	{
		bookmarkCount = [db intForQuery:@"SELECT COUNT(*) FROM bookmarks WHERE songId = ?", self.currentSong.songId]; 
	}];
	
	if (bookmarkCount > 0)
	{
		self.bookmarkButton.imageView.image = [UIImage imageNamed:@"controller-bookmark-on.png"];
	}
	else
	{
		self.bookmarkButton.imageView.image = [UIImage imageNamed:@"controller-bookmark.png"];
	}
	
	self.trackLabel.text = [self.currentSong.track intValue] != 0 ? [NSString stringWithFormat:@"Track %i", [self.currentSong.track intValue]] : @"";
	self.genreLabel.text = self.currentSong.genre ? self.currentSong.genre : @"";
	self.yearLabel.text = [self.currentSong.year intValue] != 0 ? [self.currentSong.year stringValue] : @"";
	[self updateFormatLabel];
    
    if (self.currentSong.isVideo)
    {
        // Disable buttons for video
        self.eqButton.enabled = NO;
        self.back30Button.enabled = NO;
        self.forw30Button.enabled = NO;
        self.progressSlider.enabled = NO;
        self.progressSlider.alpha = 0.5;
        self.bookmarkButton.enabled = NO;
        self.elapsedTimeLabel.alpha = 0.5;
        self.remainingTimeLabel.alpha = 0.5;
        self.progressSlider.maximumValue = 0.0;
    }
}

- (void)jukeboxToggled
{
	// Setup the volume controller view
	if (settingsS.isJukeboxEnabled)
	{
		// Remove the regular volume control if there
		[self.volumeView removeFromSuperview];
		self.volumeView = nil;
		
		[jukeboxS jukeboxGetInfo];
		
		self.view.backgroundColor = viewObjectsS.jukeboxColor;
		
		CGRect frame = self.volumeSlider.bounds;
		frame.size.height = self.volumeSlider.bounds.size.height / 2;
		self.jukeboxVolumeView = [[UISlider alloc] initWithFrame:frame];
        [self.jukeboxVolumeView setThumbImage:[UIImage imageNamed:@"controller-slider-thumb.png"] forState:UIControlStateNormal];
		[self.jukeboxVolumeView addTarget:self action:@selector(jukeboxVolumeChanged:) forControlEvents:UIControlEventValueChanged];
		self.jukeboxVolumeView.minimumValue = 0.0;
		self.jukeboxVolumeView.maximumValue = 1.0;
		self.jukeboxVolumeView.continuous = NO;
		self.jukeboxVolumeView.value = jukeboxS.jukeboxGain;
		[self.volumeSlider addSubview:self.jukeboxVolumeView];
	}
	else
	{
		// Remove the jukebox volume control if there
		[self.jukeboxVolumeView removeFromSuperview];
		self.jukeboxVolumeView = nil;
		
		self.view.backgroundColor = [UIColor blackColor];
		
		CGRect newFrame = CGRectMake(10, 0, self.volumeSlider.width-20, self.volumeSlider.height);
		self.volumeView = [[MPVolumeView alloc] initWithFrame:newFrame];
        if (IS_IOS7())
            [self.volumeView setVolumeThumbImage:[UIImage imageNamed:@"controller-volumeslider-thumb.png"] forState:UIControlStateNormal];
		[self.volumeSlider addSubview:self.volumeView];
	}
	
	[self initSongInfo];
}

- (void)jukeboxVolumeChanged:(id)sender
{
	[jukeboxS jukeboxSetVolume:self.jukeboxVolumeView.value];
}

- (void)backAction:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)updateBarButtonImage
{
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(30.0, 30.0), NO, 0.0);
	//DLog(@"coverArtImageView.image: %@", coverArtImageView.image);
	[self.coverArtImageView.image drawInRect:CGRectMake(0, 0,30.0, 30.0)];
	UIImage *cover = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	
	UIView *aView = [[UIView alloc] initWithFrame:CGRectMake(0, 0,34.0, 30.0)];
	aView.layer.cornerRadius = 4;
	
	UIImageView *coverView = [[UIImageView alloc] initWithImage:cover];
	coverView.frame = CGRectMake(2, 0,30.0, 30.0);
	//coverView.userInteractionEnabled = YES;
	[aView addSubview:coverView];
	
	UIButton *action = [UIButton buttonWithType:UIButtonTypeCustom];
	action.frame = coverView.frame;
	[action addTarget:self action:@selector(songInfoToggle:) forControlEvents:UIControlEventTouchUpInside];
	[aView addSubview:action];
	
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:aView];
}

- (void)playlistToggleAnimated:(BOOL)animated saveState:(BOOL)saveState
{
	if (!self.isFlipped)
	{
		self.songInfoToggleButton.userInteractionEnabled = NO;
		
		if (!self.pageControlViewController)
		{
			self.pageControlViewController = [[PageControlViewController alloc] initWithNibName:@"PageControlViewController" bundle:nil];
			self.pageControlViewController.view.frame = CGRectMake (0, 0, self.coverArtImageView.frame.size.width, self.coverArtImageView.frame.size.height);
		}
		
		// Set the icon in the top right
		[self updateBarButtonImage];
		
		// Flip the album art horizontally
		self.coverArtHolderView.transform = CGAffineTransformMakeScale(-1, 1);
		self.pageControlViewController.view.transform = CGAffineTransformMakeScale(-1, 1);
		
		if (animated)
		{
			[UIView beginAnimations:nil context:NULL];
			[UIView setAnimationDuration:0.40];
			[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:self.coverArtHolderView cache:YES];
		}
		
		//[pageControlViewController resetScrollView];
		[self.coverArtHolderView addSubview:self.pageControlViewController.view];
		self.reflectionView.alpha = 0.0;
		
		self.extraButtonsButton.alpha = 0.0;
		self.extraButtonsButton.enabled = NO;
		//extraButtons.alpha = 0.0;
		//songInfoView.alpha = 0.0;
		
		if (animated)
			[UIView commitAnimations];
		
		//[pageControlViewController viewWillAppear:NO];
	}
	else
	{
		self.songInfoToggleButton.userInteractionEnabled = YES;
		
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"player-overlay.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(songInfoToggle:)];
		
		// Flip the album art horizontally
		self.coverArtHolderView.transform = CGAffineTransformMakeScale(1, 1);
		
		if (animated)
		{
			[UIView beginAnimations:nil context:NULL];
			[UIView setAnimationDuration:0.4];
			[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:self.coverArtHolderView cache:YES];
			//[UIView setAnimationDelegate:self];
			//[UIView setAnimationDidStopSelector:@selector(releaseSongInfo:finished:context:)];
		}
		
		//[[[coverArtImageView subviews] lastObject] removeFromSuperview];
		[self.pageControlViewController.view removeFromSuperview];
		self.reflectionView.alpha = kDefaultReflectionOpacity;
		
		self.extraButtonsButton.alpha = 1.0;
		self.extraButtonsButton.enabled = YES;
		//extraButtons.alpha = 1.0;
		//songInfoView.alpha = 1.0;
		
		UIGraphicsEndImageContext();
		
		if (animated)
			[UIView commitAnimations];
		
		//[pageControlViewController resetScrollView];
		
		self.pageControlViewController = nil;
	}
	
	self.isFlipped = !self.isFlipped;
	
	if (saveState)
		settingsS.isPlayerPlaylistShowing = self.isFlipped;
}

- (IBAction)songInfoToggle:(id)sender
{
	[self playlistToggleAnimated:YES saveState:YES];
}

/*- (void)releaseSongInfo:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
	NSLog(@"releaseSongInfo called");
	[pageControlViewController release]; pageControlViewController = nil;
}*/

#pragma mark Player Controls

- (IBAction)playButtonPressed:(id)sender
{
	if (settingsS.isJukeboxEnabled)
	{
		if (jukeboxS.jukeboxIsPlaying)
			[jukeboxS jukeboxStop];
		else
			[jukeboxS jukeboxPlay];
	}
	else
	{
		if (audioEngineS.player && !playlistS.currentSong.isVideo)
		{
			[audioEngineS.player playPause];
		}
		else
		{
			[musicS playSongAtPosition:playlistS.currentIndex];
            //[musicS startSongAtOffsetInBytes:<#(unsigned long long)#> andSeconds:<#(double)#>]
		}
	}
}

- (IBAction)prevButtonPressed:(id)sender
{	
	//DLog(@"track position: %f", audioEngineS.progress);
	if (audioEngineS.player.progress > 10.0)
	{
		if (settingsS.isJukeboxEnabled)
			[jukeboxS jukeboxPlaySongAtPosition:@(playlistS.currentIndex)];
		else
			[musicS playSongAtPosition:playlistS.currentIndex];
	}
	else
	{
		[musicS prevSong];
	}
	
	[self initSongInfo];
}

- (IBAction)nextButtonPressed:(id)sender
{
	[musicS nextSong];
	[self initSongInfo];
}

/*- (void)showExtraButtonsTemporarilyAnimated
{
	if (!isExtraButtonsShowing)
	{
		[self extraButtonsToggleAnimated:YES saveState:NO];
		[self performSelector:@selector(hideExtraButtons) withObject:nil afterDelay:5.0];
	}
}

- (void)showExtraButtonsTemporarily
{
	if (!isExtraButtonsShowing)
	{
		[self extraButtonsToggleAnimated:NO saveState:NO];
		[self performSelector:@selector(hideExtraButtons) withObject:nil afterDelay:5.0];
	}
}*/

- (void)hideExtraButtons
{
	[self extraButtonsToggleAnimated:YES saveState:NO];
}

- (void)extraButtonsToggleAnimated:(BOOL)animated saveState:(BOOL)saveState
{
    if (IS_TALL_SCREEN() && UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
    {        
        if (self.isExtraButtonsShowing)
        {
            [self.extraButtonsButton setImage:self.extraButtonsButtonOffImage forState:UIControlStateNormal];
            
            self.largeOverlayView.alpha = 0.0;
            
            if (animated)
            {
                [UIView commitAnimations];
            }
            else
            {
                [self.largeOverlayView removeFromSuperview];
            }
        }
        else
        {
            [self.extraButtonsButton setImage:self.extraButtonsButtonOnImage forState:UIControlStateNormal];

            if (settingsS.isShowLargeSongInfoInPlayer)
            {
                //largeOverlayView.origin = CGPointMake(0, extraButtons.height);
                //largeOverlayView.width = coverArtImageView.width;
                self.largeOverlayView.frame = self.coverArtImageView.bounds;//CGRectMake(0, self.extraButtons.height, self.coverArtImageView.width, self.coverArtImageView.height - self.extraButtons.height - self.songInfoView.height);
                self.largeOverlayView.alpha = 0.0;
                [self.coverArtImageView addSubview:self.largeOverlayView];
            }
            self.largeOverlayView.alpha = 1.0;
            
            if (animated)
                [UIView commitAnimations];
        }
        
        self.isExtraButtonsShowing = !self.isExtraButtonsShowing;
        
        if (saveState)
            settingsS.isExtraPlayerControlsShowing = self.isExtraButtonsShowing;
        return;
    }
    
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideExtraButtons) object:nil];
	
    self.extraButtons.alpha = 1.0;
    self.songInfoView.alpha = 1.0;
    
	CGPoint extraButtonsHidden = CGPointMake(0, -self.extraButtons.height);
	CGPoint extraButtonsVisible = CGPointMake(0, 0);
	
	CGPoint songInfoViewHidden  = CGPointMake(0, self.coverArtHolderView.height);
	CGPoint songInfoViewVisible = CGPointMake(0, self.coverArtHolderView.height - self.songInfoView.height);
	
	if (self.isExtraButtonsShowing)
	{
		[self.extraButtonsButton setImage:self.extraButtonsButtonOffImage forState:UIControlStateNormal];
		
		if (animated)
		{
			[UIView beginAnimations:nil context:nil];
			[UIView setAnimationDelegate:self];
			[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
			[UIView setAnimationDidStopSelector:@selector(toggleExtraButtonsAnimationDone)];
			[UIView setAnimationDuration:0.2];
		}
		
		self.extraButtons.origin = extraButtonsHidden;
		self.songInfoView.origin = songInfoViewHidden;
		self.largeOverlayView.alpha = 0.0;

		if (animated)
		{
			[UIView commitAnimations];
		}
		else
		{
			[self.extraButtons removeFromSuperview];
			[self.songInfoView removeFromSuperview];
			[self.largeOverlayView removeFromSuperview];
		}
	}
	else
	{
		[self.extraButtonsButton setImage:self.extraButtonsButtonOnImage forState:UIControlStateNormal];
		
		self.extraButtons.origin = extraButtonsHidden;
		self.extraButtons.width = self.coverArtHolderView.width;
		self.songInfoView.origin = songInfoViewHidden;
		self.songInfoView.width = self.coverArtHolderView.width;
		if (settingsS.isShowLargeSongInfoInPlayer)
		{
			//largeOverlayView.origin = CGPointMake(0, extraButtons.height);
			//largeOverlayView.width = coverArtImageView.width;
			self.largeOverlayView.frame = CGRectMake(0, self.extraButtons.height, self.coverArtImageView.width, self.coverArtImageView.height - self.extraButtons.height - self.songInfoView.height);
			self.largeOverlayView.alpha = 0.0;
			[self.coverArtImageView addSubview:self.largeOverlayView];
		}
		[self.coverArtHolderView addSubview:self.extraButtons];
		[self.coverArtHolderView addSubview:self.songInfoView];
		
		if (self.isFlipped)
			[self.coverArtHolderView bringSubviewToFront:self.pageControlViewController.view];
		
		[self updateFormatLabel];
		
		if (animated)
		{
			[UIView beginAnimations:nil context:nil];
			[UIView setAnimationDelegate:self];
			[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
			[UIView setAnimationDidStopSelector:@selector(toggleExtraButtonsAnimationDone)];
			[UIView setAnimationDuration:0.2];
		}
		
		self.extraButtons.origin = extraButtonsVisible;
		self.songInfoView.origin = songInfoViewVisible;
		self.largeOverlayView.alpha = 1.0;
		
		if (animated)
			[UIView commitAnimations];
	}
	
	self.isExtraButtonsShowing = !self.isExtraButtonsShowing;
	
	if (saveState)
		settingsS.isExtraPlayerControlsShowing = self.isExtraButtonsShowing;
}

- (void)toggleExtraButtonsAnimationDone
{
	if (!self.isExtraButtonsShowing)
	{
		[self.extraButtons removeFromSuperview];
		[self.songInfoView removeFromSuperview];
		[self.largeOverlayView removeFromSuperview];
	}
}

- (IBAction)toggleExtraButtons:(id)sender
{	
	[self extraButtonsToggleAnimated:YES saveState:YES];
}
/*- (IBAction)toggleExtraButtons:(id)sender
{	
	CGFloat height = extraButtons.height;
	CGFloat width = 250.;
	CGFloat y = extraButtonsButton.y - ((height - extraButtonsButton.height) / 2);
	
	if (isExtraButtonsShowing)
	{
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
		[UIView setAnimationDidStopSelector:@selector(toggleExtraButtonsAnimationDone)];
		[UIView setAnimationDuration:0.3];
		
		CGRect frame = CGRectMake(extraButtonsButton.x + extraButtonsButton.width, y, 0, height);
		extraButtons.frame = frame;
		extraButtonsBackground.width = 0.;
		
		extraButtons.alpha = 0.;
		for (UIView *subView in extraButtons.subviews)
		{			
			if (subView.tag)
				subView.alpha = 0.;
		}
		
		[UIView commitAnimations];
	}
	else
	{ 
		[self.view addSubview:extraButtons];
		CGRect frame = CGRectMake(extraButtonsButton.x + 40., y, 0, height);
		extraButtons.frame = frame;
		extraButtons.alpha = 0.;
		extraButtonsBackground.width = 0.;
		
		[self.view bringSubviewToFront:extraButtonsButton];
		
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
		[UIView setAnimationDidStopSelector:@selector(toggleExtraButtonsAnimationDone)];
		[UIView setAnimationDuration:0.3];
		
		frame = CGRectMake(extraButtonsButton.x - width + extraButtonsButton.width, y, width, height);
		extraButtons.frame = frame;
		extraButtonsBackground.width = width;
		
		extraButtons.alpha = 1.;
		for (UIView *subView in extraButtons.subviews)
		{			
			if (subView.tag)
				subView.alpha = 1.;
		}
		
		[UIView commitAnimations];
	}
	
	isExtraButtonsShowing = !isExtraButtonsShowing;
}

- (void)toggleExtraButtonsAnimationDone
{
	if (isExtraButtonsShowing)
	{
		
	}
	else
	{
		[extraButtons removeFromSuperview];
	}
}*/


- (IBAction)touchedSlider:(id)sender
{
	self.pauseSlider = YES;
	
	if (self.sliderMultipleLabel == nil)
	{
		// Create the label
		CGFloat width = 80;
		CGFloat height = 18;
		CGFloat x = (self.coverArtHolderView.width / 2) - (width / 2.);
		CGFloat y = self.songInfoView.y - height;
		CGRect frame = CGRectMake(x, y, width, height);
		self.sliderMultipleLabel = [[UILabel alloc] initWithFrame:frame];
		self.sliderMultipleLabel.textColor = [UIColor colorWithWhite:.8 alpha:1.0];
		self.sliderMultipleLabel.alpha = 0.0;
		self.sliderMultipleLabel.font = ISMSBoldFont(13.5);
		self.sliderMultipleLabel.shadowOffset = CGSizeMake(0, 2);
		self.sliderMultipleLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.25];
		self.sliderMultipleLabel.textAlignment = NSTextAlignmentCenter;
		
		// Create the label background
		CGFloat cornerRadius = 4.;
		CGRect backgroundFrame = CGRectMake(0., 0., self.sliderMultipleLabel.width, self.sliderMultipleLabel.height + cornerRadius);
		CALayer *backgroundLayer = [[CALayer alloc] init];
		backgroundLayer.frame = backgroundFrame;
		backgroundLayer.backgroundColor = [UIColor colorWithWhite:0 alpha:.72].CGColor;
		backgroundLayer.cornerRadius = cornerRadius;
        //self.sliderMultipleLabel.backgroundColor = [UIColor colorWithPatternImage:[backgroundLayer imageFromLayer]];
        
        CGRect cropRect = CGRectMake(0., cornerRadius, self.sliderMultipleLabel.width, self.sliderMultipleLabel.height);
        UIImage *croppedImage = [[backgroundLayer imageFromLayer] croppedImage:cropRect];
        self.sliderMultipleLabel.backgroundColor = [UIColor colorWithPatternImage:croppedImage];
        self.sliderMultipleLabel.top = IS_TALL_SCREEN() ? 0. : self.extraButtons.height - 1.;

		[self.coverArtHolderView addSubview:self.sliderMultipleLabel];
	}
	
	OBSlider *slider = sender;
	NSString *text = [NSString stringWithFormat:@"%@  x%.1f", [NSString formatTime:self.progressSlider.value], slider.scrubbingSpeed];
	self.sliderMultipleLabel.text = text;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.2];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	self.sliderMultipleLabel.alpha = 1.0;
	[UIView commitAnimations];	
}


- (IBAction) movingSlider:(id)sender
{	
	OBSlider *slider = sender;
	NSString *text = [NSString stringWithFormat:@"%@  x%.1f", [NSString formatTime:self.progressSlider.value], slider.scrubbingSpeed];
	self.sliderMultipleLabel.text = text;
}


- (IBAction)movedSlider:(id)sender
{	
	if (!self.hasMoved)
	{		
		self.hasMoved = YES;
		
		// Fix for skipping to end of file going to next song
		// It seems that the max time is always off
		if (self.progressSlider.value > (self.progressSlider.maximumValue - 8.0))
		{
			float newValue = self.progressSlider.maximumValue - 8.0;
			
			if (newValue < 0.0)
				newValue = 0.0;
			
			self.progressSlider.value = newValue;
		}
		
		self.byteOffset = [BassWrapper estimateBitrate:audioEngineS.player.currentStream] * 128 * self.progressSlider.value;
        //DLog(@"bitrate: %i slider: %f byteOffset: %i localFileSize: %llu", [BassWrapper estimateBitrate:audioEngineS.player.currentStream], progressSlider.value, byteOffset, currentSong.localFileSize);
		
		if (self.currentSong.isTempCached)
		{
            [audioEngineS.player stop];
			
			audioEngineS.startByteOffset = self.byteOffset;
			audioEngineS.startSecondsOffset = self.progressSlider.value;
			
			[streamManagerS removeStreamAtIndex:0];
			[streamManagerS queueStreamForSong:self.currentSong byteOffset:self.byteOffset secondsOffset:self.progressSlider.value atIndex:0 isTempCache:YES isStartDownload:YES];
			if ([streamManagerS.handlerStack count] > 1)
			{
				ISMSStreamHandler *handler = [streamManagerS.handlerStack firstObjectSafe];
				[handler start];
			}
			
			self.pauseSlider = NO;
			self.hasMoved = NO;
		}
		else 
		{			
			if (self.currentSong.isFullyCached || self.byteOffset <= self.currentSong.localFileSize)
			{
				[audioEngineS.player seekToPositionInSeconds:self.progressSlider.value fadeVolume:YES];
				self.pauseSlider = NO;
				self.hasMoved = NO;
			}
			else
			{
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Past Cache Point" message:@"You are trying to skip further than the song has cached. You can do this, but the song won't be cached. Or you can wait a little bit for the cache to catch up." delegate:self cancelButtonTitle:@"Wait" otherButtonTitles:@"OK", nil];
				[alert show];
			}
		}
	}
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.2];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	self.sliderMultipleLabel.alpha = 0.0;
	[UIView commitAnimations];	
}

- (IBAction)skipBack30:(id)sender
{
	CGFloat seconds = (CGFloat)settingsS.quickSkipNumberOfSeconds;
	
	float newValue = 0.0;
	if (self.progressSlider.value - seconds >= 0.0)
	{
		newValue = self.progressSlider.value - seconds;
	}
	self.progressSlider.value = newValue;
	[self movedSlider:nil];
	
	[Flurry logEvent:@"QuickSkip"];
}

- (IBAction)skipForward30:(id)sender
{
	CGFloat seconds = (CGFloat)settingsS.quickSkipNumberOfSeconds;
	self.progressSlider.value = self.progressSlider.value + seconds;
	[self movedSlider:nil];
	
	[Flurry logEvent:@"QuickSkip"];
}

- (IBAction) repeatButtonToggle:(id)sender
{	
	if(playlistS.repeatMode == 0)
	{
		[self.repeatButton setImage:[UIImage imageNamed:@"controller-repeat-one.png"] forState:0];
		playlistS.repeatMode = 1;
	}
	else if(playlistS.repeatMode == 1)
	{
		[self.repeatButton setImage:[UIImage imageNamed:@"controller-repeat-all.png"] forState:0];
		playlistS.repeatMode = 2;
	}
	else if(playlistS.repeatMode == 2)
	{
		[self.repeatButton setImage:[UIImage imageNamed:@"controller-repeat.png"] forState:0];
		playlistS.repeatMode = 0;
	}
}

- (IBAction)bookmarkButtonToggle:(id)sender
{
	self.bookmarkPosition = (int)self.progressSlider.value;
	self.bookmarkBytePosition = audioEngineS.player.currentByteOffset;
	
	UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Bookmark Name:" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
    myAlertView.alertViewStyle = UIAlertViewStylePlainTextInput;
	[myAlertView show];
}

- (void)saveBookmark:(NSString *)name
{
	// TODO: somehow this is saving the incorrect playlist index sometimes
	__block NSUInteger bookmarksCount;
	[databaseS.bookmarksDbQueue inDatabase:^(FMDatabase *db)
	{
        //NSString *query = [NSString stringWithFormat:@"INSERT INTO bookmarks (playlistIndex, name, position, %@, bytes) VALUES (?, ?, ?, %@, ?)", [ISMSSong standardSongColumnNames], [ISMSSong standardSongColumnQMarks]];
		//[db executeUpdate:query, @(playlistS.currentIndex), self.bookmarkNameTextField.text, @(self.bookmarkPosition), self.currentSong.title, self.currentSong.songId, self.currentSong.artist, self.currentSong.album, self.currentSong.genre, self.currentSong.coverArtId, self.currentSong.path, self.currentSong.suffix, self.currentSong.transcodedSuffix, self.currentSong.duration, self.currentSong.bitRate, self.currentSong.track, self.currentSong.year, self.currentSong.size, self.currentSong.parentId, @(self.currentSong.isVideo), self.currentSong.discNumber, @(self.bookmarkBytePosition)];
		
        NSString *query = [NSString stringWithFormat:@"INSERT INTO bookmarks (playlistIndex, name, position, %@, bytes) VALUES (?, ?, ?, %@, ?)", [ISMSSong standardSongColumnNames], [ISMSSong standardSongColumnQMarks]];
		[db executeUpdate:query, @(playlistS.currentIndex), name, @(self.bookmarkPosition), self.currentSong.title, self.currentSong.songId, self.currentSong.artist, self.currentSong.album, self.currentSong.genre, self.currentSong.coverArtId, self.currentSong.path, self.currentSong.suffix, self.currentSong.transcodedSuffix, self.currentSong.duration, self.currentSong.bitRate, self.currentSong.track, self.currentSong.year, self.currentSong.size, self.currentSong.parentId, @(self.currentSong.isVideo), self.currentSong.discNumber, @(self.bookmarkBytePosition)];
        
        
        //@"title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size, parentId, isVideo, discNumber";
        
		NSInteger bookmarkId = [db intForQuery:@"SELECT MAX(bookmarkId) FROM bookmarks"]; 
		
		NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
		NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
		NSString *table = playlistS.isShuffle ? shufTable : currTable;
        //DLog(@"table: %@", table);
		
		// Save the playlist
		NSString *dbName = settingsS.isOfflineMode ? @"%@/offlineCurrentPlaylist.db" : @"%@/%@currentPlaylist.db";
		[db executeUpdate:@"ATTACH DATABASE ? AS ?", [NSString stringWithFormat:dbName, settingsS.databasePath, settingsS.urlString.md5], @"currentPlaylistDb"];
		
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmark%li (%@)", (long)bookmarkId, [ISMSSong standardSongColumnSchema]]];
		
		[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO bookmark%li SELECT * FROM currentPlaylistDb.%@", (long)bookmarkId, table]];
		
		bookmarksCount = [db intForQuery:@"SELECT COUNT(*) FROM bookmarks WHERE songId = ?", self.currentSong.songId];
		
		[db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
	}];
	
	self.bookmarkButton.imageView.image = [UIImage imageNamed:@"controller-bookmark-on.png"];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{	
	if ([alertView.title isEqualToString:@"Sorry"])
	{
		self.hasMoved = NO;
	}
	if ([alertView.title isEqualToString:@"Past Cache Point"])
	{
		if (buttonIndex == 0)
		{
			self.pauseSlider = NO;
			self.hasMoved = NO;
		}
		else if(buttonIndex == 1)
		{
            [audioEngineS.player stop];
			audioEngineS.startByteOffset = self.byteOffset;
			audioEngineS.startSecondsOffset = self.progressSlider.value;
			
			[streamManagerS removeStreamAtIndex:0];
            //DLog(@"byteOffset: %i", byteOffset);
			//DLog(@"starting temp stream");
			[streamManagerS queueStreamForSong:self.currentSong byteOffset:self.byteOffset secondsOffset:self.progressSlider.value atIndex:0 isTempCache:YES isStartDownload:YES];
			if ([streamManagerS.handlerStack count] > 1)
			{
				ISMSStreamHandler *handler = [streamManagerS.handlerStack firstObjectSafe];
				[handler start];
			}
			self.pauseSlider = NO;
			self.hasMoved = NO;
		}
	}
	else if([alertView.title isEqualToString:@"Bookmark Name:"])
	{
        NSString *text = [alertView textFieldAtIndex:0].text;
		if(buttonIndex == 1)
		{
			[self saveBookmark:text];
		}
	}
}

- (IBAction)shuffleButtonToggle:(id)sender
{	
	NSString *message = playlistS.isShuffle ? @"Unshuffling" : @"Shuffling";
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:message];
	
	[playlistS performSelector:@selector(shuffleToggle) withObject:nil afterDelay:0.05];
}

- (void)updateShuffleIcon
{	
	if (playlistS.isShuffle)
	{
		[self.shuffleButton setImage:[UIImage imageNamed:@"controller-shuffle-on.png"] forState:0];
	}
	else
	{
		[self.shuffleButton setImage:[UIImage imageNamed:@"controller-shuffle.png"] forState:0];
	}
	
	[viewObjectsS hideLoadingScreen];
}

- (IBAction)currentAlbumPressed:(id)sender
{
//DLog(@"parentId: %@", currentSong.parentId);
}

- (void)updateDownloadProgress
{		
	// Set the current song progress bar
	if ([self.currentSong isTempCached])
	{
		self.downloadProgress.hidden = YES;
	}
	else
	{
		self.downloadProgress.hidden = NO;
        
        // Keep between 0 and 1
		float modifier = self.currentSong.downloadProgress;
		modifier = modifier < 0. ? 0. : modifier;
		modifier = modifier > 1. ? 1. : modifier;
		
		// Set the width based on the download progress + left border size
		float width = (self.currentSong.downloadProgress * downloadProgressWidth) + downloadProgressBorder;
		
		// If the song is fully cached, add the right side border
		width = modifier >= 1. ? width + downloadProgressBorder : width;
		
        if (width > self.downloadProgress.width && (width - self.downloadProgress.width < downloadProgressWidth + downloadProgressBorder))
        {
            [UIView animateWithDuration:1. delay:0. options:UIViewAnimationOptionCurveLinear animations:^
             {
                 self.downloadProgress.width = width;
             } completion:nil];
        }
        else
        {
            self.downloadProgress.width = width;
        }
	}
	
	[self performSelector:@selector(updateDownloadProgress) withObject:nil afterDelay:1.0];
}

- (void)updateSlider
{		
	if (settingsS.isJukeboxEnabled)
	{
		if (self.lastProgress != [self.currentSong.duration intValue])
		{
			self.elapsedTimeLabel.text = [NSString formatTime:0];
			self.remainingTimeLabel.text = [NSString stringWithFormat:@"-%@",[NSString formatTime:[self.currentSong.duration floatValue]]];
			
			self.progressSlider.value = 0.0;
		}
	}
	else 
	{
		if (!self.pauseSlider)
		{
			// Handle the case where Subsonic didn't detect the song length
			if ((!self.currentSong.duration || [self.currentSong.duration intValue] <= 0) &&
					 self.currentSong.isFullyCached && audioEngineS.player.isStarted)
			{
				self.progressSlider.maximumValue = audioEngineS.player.currentStream.song.duration.floatValue;
				self.progressSlider.enabled = YES;
			}
            			
			double progress = 0;
			if (audioEngineS.player.isPlaying)
				progress = audioEngineS.player.progress;
			else
            {
                if (!audioEngineS.player.currentStream.song)
                {
                    progress = (double)audioEngineS.startSecondsOffset;
                    
                }
                else
                {
                    progress = [self.currentSong isEqualToSong:audioEngineS.player.currentStream.song] ? audioEngineS.player.progress : 0.;
                }
//                ALog(@"startsecs - startSecondsOffset: %f, progress: %f, self.currentSong: %@, audioengine.currentSong: %@", (double)audioEngineS.startSecondsOffset, progress, self.currentSong, audioEngineS.player.currentStream.song);
            }
			
			if (self.lastProgress != floor(progress))
			{
				self.lastProgress = floor(progress);
				
				NSString *elapsedTime = [NSString formatTime:progress];
				NSString *remainingTime = [NSString formatTime:([self.currentSong.duration doubleValue] - progress)];
				
				// Handle the case where Subsonic didn't detect the song length
				if ((!self.currentSong.duration || [self.currentSong.duration intValue] <= 0) &&
					self.currentSong.isFullyCached && audioEngineS.player.isStarted)
				{
					remainingTime = [NSString formatTime:(audioEngineS.player.currentStream.song.duration.floatValue - progress)];
				}
				
				self.progressSlider.value = progress;
				self.elapsedTimeLabel.text = elapsedTime;
				self.remainingTimeLabel.text =[@"-" stringByAppendingString:remainingTime];
			}
		}
		
		if (self.isExtraButtonsShowing || IS_TALL_SCREEN())
			[self updateFormatLabel];
	}
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateSlider) object:nil];
	[self performSelector:@selector(updateSlider) withObject:nil afterDelay:1];
}

- (void)updateFormatLabel
{
	if ([self.currentSong isEqualToSong:audioEngineS.player.currentStream.song] && audioEngineS.player.bitRate > 0)
		self.formatLabel.text = [NSString stringWithFormat:@"%li kbps %@", (long)audioEngineS.player.bitRate, [BassWrapper formatForChannel:audioEngineS.player.currentStream.stream]];
	else if ([self.currentSong isEqualToSong:audioEngineS.player.currentStream.song])
		self.formatLabel.text = [BassWrapper formatForChannel:audioEngineS.player.currentStream.stream];
	else
		self.formatLabel.text = @"";
}

#pragma mark Image Reflection

- (void)createReflection
{	
    // Create reflection
	self.reflectionView.image = [self.coverArtImageView reflectedImageWithHeight:self.reflectionHeight];
	if (self.isFlipped)
	{
		[self updateBarButtonImage];
	}
}

- (IBAction)showEq:(id)sender
{
	if (self.isFlipped)
		[self songInfoToggle:nil];
	
	EqualizerViewController *eqView = [[EqualizerViewController alloc] initWithNibName:@"EqualizerViewController" bundle:nil];
	[self.navigationController pushViewController:eqView animated:YES];
}


@end
