//
//  PMSServerEditViewControllerViewController.m
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "PMSServerEditViewControllerViewController.h"
#import "FoldersViewController.h"
#import "ServerListViewController.h"
#import "ServerTypeViewController.h"
#import "iPadRootViewController.h"
#import "MenuViewController.h"

LOG_LEVEL_ISUB_DEFAULT

@implementation PMSServerEditViewControllerViewController

#pragma mark - Rotation

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

#pragma mark - Lifecycle

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	if (!self.parentController)
	{
		CGRect frame = self.view.frame;
		frame.origin.y = 20;
		self.view.frame = frame;
	}
	
	self.theNewRedirectUrl = nil;
	
	if (viewObjectsS.serverToEdit)
	{
		self.urlField.text = viewObjectsS.serverToEdit.url;
		self.usernameField.text = viewObjectsS.serverToEdit.username;
		self.passwordField.text = viewObjectsS.serverToEdit.password;
	}
}

#pragma mark - Button handling

- (BOOL)checkUrl:(NSString *)url
{
	if (url.length == 0)
		return NO;
	
	if ([[url substringFromIndex:(url.length - 1)] isEqualToString:@"/"])
	{
		self.urlField.text = [url substringToIndex:([url length] - 1)];
		return YES;
	}
	
	if (url.length < 7)
	{
		self.urlField.text = [NSString stringWithFormat:@"http://%@", url];
		return YES;
	}
	else
	{
		if (![[url substringToIndex:7] isEqualToString:@"http://"])
		{
			BOOL addHttp = NO;
			if (url.length >= 8)
			{
				if (![[url substringToIndex:8] isEqualToString:@"https://"])
					addHttp = YES;
			}
			else 
			{
				addHttp = YES;
			}
			
			if (addHttp)
				self.urlField.text = [NSString stringWithFormat:@"http://%@", url];
			
			return YES;
		}
	}
	
	return YES;
}

- (BOOL)checkUsername:(NSString *)username
{
	return username.length > 0;
}

- (BOOL)checkPassword:(NSString *)password
{
	return password.length > 0;
}

- (IBAction) cancelButtonPressed:(id)sender
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


- (IBAction)saveButtonPressed:(id)sender
{
	if (![self checkUrl:self.urlField.text])
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"The URL must be in the format: http://mywebsite.com:port/folder\n\nBoth the :port and /folder are optional" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		[alert show];
	}
	
	if ([self checkUrl:self.urlField.text] && [self checkUsername:self.usernameField.text] && [self checkPassword:self.passwordField.text])
	{
        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Logging in"];
        
        self.loader = [[PMSLoginLoader alloc] initWithDelegate:self urlString:self.urlField.text username:self.usernameField.text password:self.passwordField.text];
        [self.loader startLoad];
    }
}

#pragma mark - UITextField delegate

// This dismisses the keyboard when the "done" button is pressed
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[self.urlField resignFirstResponder];
	[self.usernameField resignFirstResponder];
	[self.passwordField resignFirstResponder];
	return YES;
}

// This dismisses the keyboard when any area outside the keyboard is touched
- (void) touchesBegan :(NSSet *) touches withEvent:(UIEvent *)event
{
	[self.urlField resignFirstResponder];
	[self.usernameField resignFirstResponder];
	[self.passwordField resignFirstResponder];
	[super touchesBegan:touches withEvent:event];
}

#pragma mark - Loader delegate

- (void)loadingRedirected:(ISMSLoader *)theLoader redirectUrl:(NSURL *)url
{
    NSMutableString *redirectUrlString = [NSMutableString stringWithFormat:@"%@://%@", url.scheme, url.host];
	if (url.port)
		[redirectUrlString appendFormat:@":%@", url.port];
	
	if ([url.pathComponents count] > 3)
	{
		for (NSString *component in url.pathComponents)
		{
			if ([component isEqualToString:@"api"])
				break;
			
			if (![component isEqualToString:@"/"])
			{
				[redirectUrlString appendFormat:@"/%@", component];
			}
		}
	}
	
	//DLog(@"redirectUrlString: %@", redirectUrlString);
	
	settingsS.redirectUrlString = [NSString stringWithString:redirectUrlString];
}

- (void)loadingFailed:(ISMSLoader *)theLoader withError:(NSError *)error
{
    self.loader.delegate = nil;
    self.loader = nil;
	[viewObjectsS hideLoadingScreen];
	
	NSString *message = @"";
	if (error.code == ISMSErrorCode_IncorrectCredentials)
		message = @"Either your username or password is incorrect. Please try again";
	else
		message = [NSString stringWithFormat:@"Either the WaveBox URL is incorrect, the WaveBox server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\nError code %li:\n%@", (long)[error code], [error localizedDescription]];
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
}

- (void)loadingFinished:(ISMSLoader *)theLoader
{    
    ISMSServer *theServer = [[ISMSServer alloc] init];
    theServer.url = self.urlField.text;
    theServer.username = self.usernameField.text;
    theServer.password = self.passwordField.text;
    
    theServer.type = WAVEBOX;
    
    settingsS.urlString = self.loader.urlString;
    settingsS.username = self.loader.username;
    settingsS.password = self.loader.password;
    settingsS.sessionId = self.loader.sessionId;
    
    if (!settingsS.serverList)
        settingsS.serverList = [NSMutableArray arrayWithCapacity:1];
    
    if(viewObjectsS.serverToEdit)
    {
        [viewObjectsS hideLoadingScreen];

        // If we're finishing up editing a server, it's selected.  We should
        // update its media database.
        
        // to do: update media database.
        
        
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
        
        NSDictionary *userInfo = nil;
        if (self.theNewRedirectUrl)
        {
            userInfo = [NSDictionary dictionaryWithObject:self.theNewRedirectUrl forKey:@"theNewRedirectUrl"];
        }
        [NSNotificationCenter postNotificationToMainThreadWithName:@"switchServer" userInfo:userInfo];
    }
    else
    {
        // Since we're creating a new server in the list, it should have
        // a UUID to identify it and so we can reliably have unique names
        // for our media databases.
        CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
        theServer.uuid = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
        CFRelease(uuid);
        
        settingsS.uuid = theServer.uuid;
        
        // Download the database.
        WBDatabaseLoader *dbLoader = [[WBDatabaseLoader alloc] initWithCallbackBlock:^(BOOL success, NSError *error, ISMSLoader *theLoader)
        {
            WBDatabaseLoader *typedLoader = (WBDatabaseLoader *)theLoader;
            if (success)
            {
                DDLogVerbose(@"Got the database.");
                theServer.lastQueryId = typedLoader.lastQueryId;
                [databaseS setCurrentMetadataDatabase];
                [viewObjectsS hideLoadingScreen];
                [NSNotificationCenter postNotificationToMainThreadWithName:@"reloadServerList"];
                [NSNotificationCenter postNotificationToMainThreadWithName:@"showSaveButton"];
                
                if (self.parentController)
                    [self.parentController dismissViewControllerAnimated:YES completion:nil];
                
                [self dismissViewControllerAnimated:YES completion:nil];
                
                if (IS_IPAD())
                    [appDelegateS.ipadRootViewController.menuViewController showHome];
                
                NSDictionary *userInfo = nil;
                if (self.theNewRedirectUrl)
                {
                    userInfo = [NSDictionary dictionaryWithObject:self.theNewRedirectUrl forKey:@"theNewRedirectUrl"];
                }
                
                // Create the entry in serverList
                viewObjectsS.serverToEdit = theServer;
                [settingsS.serverList addObject:viewObjectsS.serverToEdit];
                
                // Save the plist values
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setObject:self.urlField.text forKey:@"url"];
                [defaults setObject:self.usernameField.text forKey:@"username"];
                [defaults setObject:self.passwordField.text forKey:@"password"];
                [defaults setObject:viewObjectsS.serverToEdit.lastQueryId forKey:@"lastQueryId"];
                [defaults setObject:viewObjectsS.serverToEdit.uuid forKey:@"uuid"];
                [defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:settingsS.serverList] forKey:@"servers"];
                [defaults synchronize];
                
                [NSNotificationCenter postNotificationToMainThreadWithName:@"switchServer" userInfo:userInfo];
            }
            else
            {
                DLog(@"Failed to get the database.");
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Uh oh!" message:@"WaveBox failed to provide us with its metadata database." delegate:nil cancelButtonTitle:@"Close" otherButtonTitles:nil];
                [alert show];
            }
        } serverUuid: theServer.uuid];
        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Syncing metadata"];
        [dbLoader startLoad];
    }
    
    self.loader.delegate = nil;
    self.loader = nil;
}

@end
