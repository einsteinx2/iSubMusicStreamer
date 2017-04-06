//
//  QuickAlbumsViewController.m
//  iSub
//
//  Created by bbaron on 11/6/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "QuickAlbumsViewController.h"
#import "HomeAlbumViewController.h"
#import "iPadRootViewController.h"
#import "StackScrollViewController.h"
#import "UIViewController+PushViewControllerCustom.h"

@interface QuickAlbumsViewController (Private)
- (void)albumLoad:(NSString*)modifier;
@end

@implementation QuickAlbumsViewController

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:duration];
	
	if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
	{
		self.randomButton.y += 16.;
		self.frequentButton.y += 16.;
		self.newestButton.y += 16.;
		self.recentButton.y += 16.;
		self.cancelButton.y += 12.;
	}
	else
	{
		self.randomButton.y -= 16.;
		self.frequentButton.y -= 16.;
		self.newestButton.y -= 16.;
		self.recentButton.y -= 16.;
		self.cancelButton.y -= 12.;
	}
	
	[UIView commitAnimations];
}

- (id)init
{	
	if ((self = [super initWithNibName:@"QuickAlbumsViewController" bundle:nil]))
    {
		_titles = [[NSDictionary alloc] initWithObjectsAndKeys:@"Recently Played", @"recent", @"Frequently Played", @"frequent", @"Newest Albums", @"newest", @"Random Albums", @"random", nil];
    }
	
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
	{
		self.randomButton.y += 16.;
		self.frequentButton.y += 16.;
		self.newestButton.y += 16.;
		self.recentButton.y += 16.;
		self.cancelButton.y += 12.;
	}
}

- (IBAction)random
{
	[self albumLoad:@"random"];
}

- (IBAction)frequent
{
	[self albumLoad:@"frequent"];
}

- (IBAction)newest
{
	[self albumLoad:@"newest"];
}

- (IBAction)recent
{
	[self albumLoad:@"recent"];
}

- (IBAction)cancel
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)cancelLoad
{
	[self.connection cancel];
	self.connection = nil;
	self.receivedData = nil;
	[viewObjectsS hideLoadingScreen];
}

- (void)albumLoad:(NSString*)theModifier
{
    [viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
        
    ISMSQuickAlbumsLoader *loader = [ISMSQuickAlbumsLoader loaderWithDelegate:self];
    loader.modifier = theModifier;
    [loader startLoad];
}

- (void)loadingFailed:(ISMSLoader *)theLoader withError:(NSError *)error
{
    [viewObjectsS hideLoadingScreen];

    CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"There was an error grabbing the album list.\n\nError:%@", error.localizedDescription] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
}

- (void)loadingFinished:(ISMSLoader *)theLoader
{
    [viewObjectsS hideLoadingScreen];

    SUSQuickAlbumsLoader *loader = (SUSQuickAlbumsLoader *)theLoader;
    
    HomeAlbumViewController *albumViewController = [[HomeAlbumViewController alloc] initWithNibName:@"HomeAlbumViewController" bundle:nil];
	albumViewController.title = [self.titles objectForKey:loader.modifier];
    
    albumViewController.listOfAlbums = [NSMutableArray arrayWithArray:loader.listOfAlbums];
    albumViewController.modifier = loader.modifier;
    	
	[self.parent pushViewControllerCustom:albumViewController];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

@end
