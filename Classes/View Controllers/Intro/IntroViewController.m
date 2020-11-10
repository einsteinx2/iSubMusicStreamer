//
//  IntroViewController.m
//  iSub
//
//  Created by Ben Baron on 1/27/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "IntroViewController.h"
#import <MediaPlayer/MediaPlayer.h>

@implementation IntroViewController
@synthesize introVideo, testServer, ownServer, sunkenLogo;

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning 
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	if (IS_IPAD())
		sunkenLogo.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dismissFast) name:ISMSNotification_EnteringOfflineMode object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_EnteringOfflineMode object:nil];
}

- (void)dismissFast
{
	[self dismissViewControllerAnimated:NO completion:nil];
}

- (IBAction)buttonPress:(id)sender
{
	if (sender == self.introVideo)
	{
		NSURL *introUrl = nil;
		if (IS_IPAD())
			introUrl = [NSURL URLWithString:@"http://isubapp.com/intro/ipad/prog_index.m3u8"];
		else if (SCREEN_SCALE() == 2.0)
			introUrl = [NSURL URLWithString:@"http://isubapp.com/intro/iphone4/prog_index.m3u8"];
		else
			introUrl = [NSURL URLWithString:@"http://isubapp.com/intro/iphone/prog_index.m3u8"];
		
		if ([MPMoviePlayerController instancesRespondToSelector:@selector(view)]) 
		{
			// Running on 3.2+
			MPMoviePlayerViewController *moviePlayer = [[MPMoviePlayerViewController alloc] initWithContentURL:introUrl];
			// Assuming self is a UIViewController
			[self presentMoviePlayerViewControllerAnimated:moviePlayer];
			// This line might be needed
			[moviePlayer.moviePlayer play];
			
			// TODO, 
		} 
		else 
		{
			MPMoviePlayerController *moviePlayer= [[MPMoviePlayerController alloc] initWithContentURL:introUrl];
			[moviePlayer play];
		}	
	}
	else if (sender == self.testServer)
	{
		[self dismissViewControllerAnimated:YES completion:nil];
	}
	else if (sender == self.ownServer)
	{
		[self dismissViewControllerAnimated:NO completion:nil];
		
		// Hack to get this working on iOS 4, can't call it directly because it doesn't detect the selected tab correctly
		//[appDelegateS performSelector:@selector(showSettings) withObject:nil afterDelay:1.0];
        [appDelegateS showSettings];
	}
}

@end
