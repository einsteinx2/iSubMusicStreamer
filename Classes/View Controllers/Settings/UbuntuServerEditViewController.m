//
//  UbuntuServerEditViewController.m
//  iSub
//
//  Created by Ben Baron on 1/15/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "UbuntuServerEditViewController.h"
#import "FoldersViewController.h"
#import "iPadRootViewController.h"
#import "ServerTypeViewController.h"
#import "MenuViewController.h"

#define URL @"https://one.ubuntu.com/music"

@implementation UbuntuServerEditViewController

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;

}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	if (!self.parentController)
	{
		CGRect frame = self.view.frame;
		frame.origin.y = 20;
		self.view.frame = frame;
	}
	
	if (viewObjectsS.serverToEdit)
	{
		self.usernameField.text = viewObjectsS.serverToEdit.username;
		self.passwordField.text = viewObjectsS.serverToEdit.password;
	}
}

- (BOOL)checkUsername:(NSString *)username
{
	return username.length > 0;
}

- (BOOL)checkPassword:(NSString *)password
{
	return password.length > 0;
}

- (IBAction)cancelButtonPressed:(id)sender
{
	viewObjectsS.serverToEdit = nil;
	
	if (self.parentController)
		[self.parentController dismissViewControllerAnimated:YES completion:nil];
	
	[self dismissViewControllerAnimated:YES completion:nil];
	
	if (![[NSUserDefaults standardUserDefaults] objectForKey:@"servers"])
	{
		// Pop the view back
		if (appDelegateS.currentTabBarController.selectedIndex == 4)
		{
			[appDelegateS.currentTabBarController.moreNavigationController popToViewController:[appDelegateS.currentTabBarController.moreNavigationController.viewControllers objectAtIndexSafe:1] animated:YES];
		}
		else
		{
			[(UINavigationController*)appDelegateS.currentTabBarController.selectedViewController popToRootViewControllerAnimated:YES];
		}
	}
}


- (IBAction) saveButtonPressed:(id)sender
{	
	if (![self checkUsername:self.usernameField.text])
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please enter a username" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		[alert show];
	}
	
	if (![self checkPassword:self.passwordField.text])
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please enter a password" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		[alert show];
	}
	
	if ([self checkUsername:self.usernameField.text] && [self checkPassword:self.passwordField.text])
	{
		ISMSServer *theServer = [[ISMSServer alloc] init];
		theServer.url = URL;
		theServer.username = self.usernameField.text;
		theServer.password = self.passwordField.text;
		theServer.type = UBUNTU_ONE;
		
		if (settingsS.serverList == nil)
			settingsS.serverList = [NSMutableArray arrayWithCapacity:1];
		
		if(viewObjectsS.serverToEdit)
		{					
			// Replace the entry in the server list
			NSInteger index = [settingsS.serverList indexOfObject:viewObjectsS.serverToEdit];
			[settingsS.serverList replaceObjectAtIndex:index withObject:theServer];
			
			// Update the serverToEdit to the new details
			viewObjectsS.serverToEdit = theServer;
			
			// Save the plist values
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			[defaults setObject:theServer.url forKey:@"url"];
			[defaults setObject:theServer.username forKey:@"username"];
			[defaults setObject:theServer.password forKey:@"password"];
			[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:settingsS.serverList] forKey:@"servers"];
			[defaults synchronize];
			
			[NSNotificationCenter postNotificationToMainThreadWithName:@"reloadServerList"];
			[NSNotificationCenter postNotificationToMainThreadWithName:@"showSaveButton"];
			
			if (self.parentController)
				[self.parentController dismissViewControllerAnimated:YES completion:nil];
			
			[self dismissViewControllerAnimated:YES completion:nil];
			
			[NSNotificationCenter postNotificationToMainThreadWithName:@"switchServer"];
		}
		else
		{
			// Create the entry in serverList
			viewObjectsS.serverToEdit = theServer;
			[settingsS.serverList addObject:viewObjectsS.serverToEdit];
			
			// Save the plist values
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			[defaults setObject:URL forKey:@"url"];
			[defaults setObject:self.usernameField.text forKey:@"username"];
			[defaults setObject:self.passwordField.text forKey:@"password"];
			[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:settingsS.serverList] forKey:@"servers"];
			[defaults synchronize];
			
			[NSNotificationCenter postNotificationToMainThreadWithName:@"reloadServerList"];
			[NSNotificationCenter postNotificationToMainThreadWithName:@"showSaveButton"];
			
			[self dismissViewControllerAnimated:YES completion:nil];
			
			if (self.parentController)
				[self.parentController dismissViewControllerAnimated:YES completion:nil];

			if (IS_IPAD())
				[appDelegateS.ipadRootViewController.menuViewController showHome];
				
			
			[NSNotificationCenter postNotificationToMainThreadWithName:@"switchServer"];
		}
		
	}
}


// This dismisses the keyboard when the "done" button is pressed
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[self.usernameField resignFirstResponder];
	[self.passwordField resignFirstResponder];
	return YES;
}

// This dismisses the keyboard when any area outside the keyboard is touched
- (void) touchesBegan :(NSSet *) touches withEvent:(UIEvent *)event
{
	[self.usernameField resignFirstResponder];
	[self.passwordField resignFirstResponder];
	[super touchesBegan:touches withEvent:event];
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}


@end
