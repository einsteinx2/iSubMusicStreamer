//
//  ServerTypeViewController.m
//  iSub
//
//  Created by Ben Baron on 1/13/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "ServerTypeViewController.h"
#import "SubsonicServerEditViewController.h"
#import "UbuntuServerEditViewController.h"
#import "PMSServerEditViewControllerViewController.h"

@implementation ServerTypeViewController
@synthesize subsonicButton, ubuntuButton, cancelButton, serverEditViewController, pmsButton;

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
    // For release versions, there is no option for server type at the moment as Ubuntu One support has been removed
#if !IS_BETA()
    [self buttonAction:self.subsonicButton];
#endif
}

- (IBAction)buttonAction:(id)sender
{
	UIView *subView = nil;

	if (sender == self.subsonicButton)
	{
		SubsonicServerEditViewController *subsonicServerEditViewController = [[SubsonicServerEditViewController alloc] initWithNibName:@"SubsonicServerEditViewController" bundle:nil];
		subsonicServerEditViewController.parentController = self;
		subsonicServerEditViewController.view.frame = self.view.bounds;
		subsonicServerEditViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		subView = subsonicServerEditViewController.view;
		self.serverEditViewController = subsonicServerEditViewController;
		
		[Flurry logEvent:@"ServerType" withParameters:[NSDictionary dictionaryWithObject:@"Subsonic" forKey:@"type"]];
	}
	else if (sender == self.ubuntuButton)
	{
		UbuntuServerEditViewController *ubuntuServerEditViewController = [[UbuntuServerEditViewController alloc] initWithNibName:@"UbuntuServerEditViewController" bundle:nil];
		ubuntuServerEditViewController.parentController = self;
		ubuntuServerEditViewController.view.frame = self.view.bounds;
		ubuntuServerEditViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[self.view addSubview:ubuntuServerEditViewController.view];
		self.serverEditViewController = ubuntuServerEditViewController;
		subView = ubuntuServerEditViewController.view;
		
		[Flurry logEvent:@"ServerType" withParameters:[NSDictionary dictionaryWithObject:@"UbuntuOne" forKey:@"type"]];
	}
	else if (sender == self.pmsButton)
	{
		PMSServerEditViewControllerViewController *pms = [[PMSServerEditViewControllerViewController alloc] initWithNibName:@"PMSServerEditViewControllerViewController" bundle:nil];
		pms.parentController = self;
		pms.view.frame = self.view.bounds;
		pms.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[self.view addSubview:pms.view];
		self.serverEditViewController = pms;
		subView = pms.view;
		
		[Flurry logEvent:@"ServerType" withParameters:[NSDictionary dictionaryWithObject:@"PMS" forKey:@"type"]];
	}
	else if (sender == self.cancelButton)
	{
		[self dismissViewControllerAnimated:YES completion:nil];
		return;
	}
	
	//[UIView beginAnimations:nil context:NULL];
	//[UIView setAnimationDuration:.5];
	//[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:self.view cache:YES];
	
	[self.view addSubview:subView];
	
	//[UIView commitAnimations];
}

@end
