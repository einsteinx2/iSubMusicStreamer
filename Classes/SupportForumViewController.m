//
//  SupportForumViewController.m
//  iSub
//
//  Created by Ben Baron on 2/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SupportForumViewController.h"
#import "Crittercism.h"
#import "SavedSettings.h"

@implementation SupportForumViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) 
	{
		
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
	
	[Crittercism showCrittercism:nil];
	UIViewController *vc = (UIViewController *)[Crittercism sharedInstance].crittercismViewController;
	[self.navigationController pushViewController:vc animated:NO];
	/*if ([vc respondsToSelector:@selector(view)])
	{
		UIView *view = (UIView *)[vc view];
		if (view) [self.view addSubview:view];
	}*/
	//[self.view addSubview:vc.view];
	
	//[self.view addSubview:<#(UIView *)#>
	//[Crittercism sharedInstance].crittercismViewController.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	if (settingsS.isRotationLockEnabled && interfaceOrientation != UIInterfaceOrientationPortrait)
		return NO;
	return YES;
	
    // Return YES for supported orientations
    //return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
