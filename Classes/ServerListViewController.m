//
//  ServerListViewController.m
//  iSub
//
//  Created by Ben Baron on 3/31/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ServerListViewController.h"
#import "SubsonicServerEditViewController.h"
#import "SettingsTabViewController.h"
#import "HelpTabViewController.h"
#import "FoldersViewController.h"
#import "ServerTypeViewController.h"
#import "UbuntuServerEditViewController.h"
#import "PMSServerEditViewControllerViewController.h"
#import "iPadRootViewController.h"
#import "MenuViewController.h"

@implementation ServerListViewController

@synthesize theNewRedirectionUrl, settingsTabViewController, helpTabViewController;
@synthesize isEditing, headerView, segmentedControl;

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

- (void)viewDidLoad 
{
    [super viewDidLoad];
    
	self.theNewRedirectionUrl = nil;
	
	self.tableView.allowsSelectionDuringEditing = YES;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable) name:@"reloadServerList" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showSaveButton) name:@"showSaveButton" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(switchServer:) name:@"switchServer" object:nil];
	
	//viewObjectsS.tempServerList = [[NSMutableArray arrayWithArray:viewObjectsS.serverList] retain];
	//DLog(@"tempServerList: %@", viewObjectsS.tempServerList);
	
	self.title = @"Servers";
	if(self != [[self.navigationController viewControllers] objectAtIndexSafe:0])
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleBordered target:self action:@selector(saveAction:)];
	self.navigationItem.rightBarButtonItem = self.editButtonItem;
	
	if (settingsS.serverList == nil || [settingsS.serverList count] == 0)
		[self addAction:nil];
	
	// Setup segmented control in the header view
	self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 40)];
	self.headerView.backgroundColor = [UIColor colorWithWhite:.3 alpha:1];
	
	self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Servers", @"Settings", @"Help"]];
	self.segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.segmentedControl addTarget:self action:@selector(segmentAction:) forControlEvents:UIControlEventValueChanged];
	self.segmentedControl.frame = CGRectMake(5, 2, 310, 36);
    if (IS_IOS7())
        self.segmentedControl.tintColor = ISMSHeaderColor;
	else
        self.segmentedControl.tintColor = [UIColor colorWithWhite:.57 alpha:1];
	self.segmentedControl.selectedSegmentIndex = 0;
	[self.headerView addSubview:self.segmentedControl];
	
	self.tableView.tableHeaderView = self.headerView;
	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
	else
	{
		if (!self.tableView.tableHeaderView) self.tableView.tableHeaderView = [[UIView alloc] init];
		if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
	}
}


- (void)reloadTable
{
	[self.tableView reloadData];
}


- (void)showSaveButton
{
	if(!self.isEditing)
	{
		if(self == [[self.navigationController viewControllers] firstObjectSafe])
			self.navigationItem.leftBarButtonItem = nil;
		else
			self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleBordered target:self action:@selector(saveAction:)];
		
	}
}


- (void)segmentAction:(id)sender
{
	self.settingsTabViewController.parentController = nil;
	self.settingsTabViewController = nil;
	self.helpTabViewController = nil;
	
	if (self.segmentedControl.selectedSegmentIndex == 0)
	{
		self.title = @"Servers";
		
		self.tableView.tableFooterView = nil;
		
		self.tableView.scrollEnabled = YES;
		self.navigationItem.rightBarButtonItem = self.editButtonItem;
		
		if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
		
		[self.tableView reloadData];
	}
	else if (self.segmentedControl.selectedSegmentIndex == 1)
	{
		self.title = @"Settings";
		
		self.tableView.scrollEnabled = YES;
		[self setEditing:NO animated:NO];
		self.navigationItem.rightBarButtonItem = nil;
		self.settingsTabViewController = [[SettingsTabViewController alloc] initWithNibName:@"SettingsTabViewController" bundle:nil];
		self.settingsTabViewController.parentController = self;
		self.tableView.tableFooterView = settingsTabViewController.view;
		if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
		[self.tableView reloadData];
	}
	else if (segmentedControl.selectedSegmentIndex == 2)
	{
		self.title = @"Help";
		
		self.tableView.scrollEnabled = NO;
		[self setEditing:NO animated:NO];
		self.navigationItem.rightBarButtonItem = nil;
		self.helpTabViewController = [[HelpTabViewController alloc] initWithNibName:@"HelpTabViewController" bundle:nil];
		self.helpTabViewController.view.frame = self.view.bounds;
        self.helpTabViewController.view.height -= 40.;
		self.tableView.tableFooterView = self.helpTabViewController.view;
		if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
		[self.tableView reloadData];
	}
}


- (void)setEditing:(BOOL)editing animated:(BOOL)animate
{
    [super setEditing:editing animated:animate];
    if(editing)
    {
		self.isEditing = YES;
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addAction:)];
    }
    else
    {
		self.isEditing = NO;
		[self showSaveButton];
    }
}

- (void)addAction:(id)sender
{
	viewObjectsS.serverToEdit = nil;
	
	ServerTypeViewController *serverTypeViewController = [[ServerTypeViewController alloc] initWithNibName:@"ServerTypeViewController" bundle:nil];
    
	if ([serverTypeViewController respondsToSelector:@selector(setModalPresentationStyle:)])
		serverTypeViewController.modalPresentationStyle = UIModalPresentationFormSheet;
    
	if (IS_IPAD())
		[appDelegateS.ipadRootViewController presentViewController:serverTypeViewController animated:YES completion:nil];
	else
		[self presentViewController:serverTypeViewController animated:YES completion:nil];
    
    
}

- (void)saveAction:(id)sender
{
	[self.navigationController popToRootViewControllerAnimated:YES];
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)showServerEditScreen
{
	if ([viewObjectsS.serverToEdit.type isEqualToString:UBUNTU_ONE])
	{
		UbuntuServerEditViewController *ubuntuServerEditViewController = [[UbuntuServerEditViewController alloc] initWithNibName:@"UbuntuServerEditViewController" bundle:nil];
		if ([ubuntuServerEditViewController respondsToSelector:@selector(setModalPresentationStyle:)])
			ubuntuServerEditViewController.modalPresentationStyle = UIModalPresentationFormSheet;
		[self presentViewController:ubuntuServerEditViewController animated:YES completion:nil];
	}
	else if ([viewObjectsS.serverToEdit.type isEqualToString:SUBSONIC])
	{
		SubsonicServerEditViewController *subsonicServerEditViewController = [[SubsonicServerEditViewController alloc] initWithNibName:@"SubsonicServerEditViewController" bundle:nil];
		if ([subsonicServerEditViewController respondsToSelector:@selector(setModalPresentationStyle:)])
			subsonicServerEditViewController.modalPresentationStyle = UIModalPresentationFormSheet;
		[self presentViewController:subsonicServerEditViewController animated:YES completion:nil];
	}
    else if ([viewObjectsS.serverToEdit.type isEqualToString:WAVEBOX])
    {
        PMSServerEditViewControllerViewController *pmsServerEditViewController = [[PMSServerEditViewControllerViewController alloc] initWithNibName:@"PMSServerEditViewControllerViewController" bundle:nil];
		if ([pmsServerEditViewController respondsToSelector:@selector(setModalPresentationStyle:)])
			pmsServerEditViewController.modalPresentationStyle = UIModalPresentationFormSheet;
		[self presentViewController:pmsServerEditViewController animated:YES completion:nil];
    }
}

- (void)switchServer:(NSNotification*)notification 
{
    // Save the url string first because the other settings in the if block below are saved using the url
    settingsS.urlString = viewObjectsS.serverToEdit.url;

	if (notification.userInfo)
	{
		self.theNewRedirectionUrl = [notification.userInfo objectForKey:@"theNewRedirectUrl"];
        settingsS.isVideoSupported = [notification.userInfo[@"isVideoSupported"] boolValue];
        settingsS.isNewSearchAPI = [notification.userInfo[@"isNewSearchAPI"] boolValue];
	}
	
	// Save the plist values
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:viewObjectsS.serverToEdit.url forKey:@"url"];
	[defaults setObject:viewObjectsS.serverToEdit.username forKey:@"username"];
	[defaults setObject:viewObjectsS.serverToEdit.password forKey:@"password"];
	[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:settingsS.serverList] forKey:@"servers"];
	[defaults synchronize];
	
	// Update the variables
	settingsS.serverType = viewObjectsS.serverToEdit.type;
	settingsS.username = viewObjectsS.serverToEdit.username;
	settingsS.password = viewObjectsS.serverToEdit.password;
    settingsS.uuid = viewObjectsS.serverToEdit.uuid;
    settingsS.lastQueryId = viewObjectsS.serverToEdit.lastQueryId;
    settingsS.redirectUrlString = self.theNewRedirectionUrl;
    
//DLog(@" settingsS.urlString: %@   settingsS.redirectUrlString: %@", settingsS.urlString, settingsS.redirectUrlString);
		
	if (self == [[self.navigationController viewControllers] objectAtIndexSafe:0] && !IS_IPAD())
	{
		[self.navigationController.view removeFromSuperview];
	}
	else
	{
		[self.navigationController popToRootViewControllerAnimated:YES];
		
		if ([appDelegateS.wifiReach currentReachabilityStatus] == NotReachable)
			return;
		
		// Cancel any caching
		[streamManagerS removeAllStreams];
		
		// Cancel any tab loads
		if ([SUSAllSongsLoader isLoading])
		{
		//DLog(@"detected all songs loading");
			settingsS.isCancelLoading = YES;
		}
		
		
		while (settingsS.isCancelLoading)
		{
			//NSLog(@"waiting for the load to cancel before continuing");
			if (!settingsS.isCancelLoading)
				break;
		}
		
		// Stop any playing song and remove old tab bar controller from window
		[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:@"recover"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[audioEngineS.player stop];
		 settingsS.isJukeboxEnabled = NO;
		
		if (settingsS.isOfflineMode)
		{
			settingsS.isOfflineMode = NO;
			
			if (IS_IPAD())
			{
				[appDelegateS.ipadRootViewController.menuViewController toggleOfflineMode];
			}
			else
			{
				for (UIView *subview in appDelegateS.window.subviews)
				{
					[subview removeFromSuperview];
				}
				[viewObjectsS orderMainTabBarController];
			}
		}
		
		// Reset the databases
		[databaseS closeAllDatabases];
		
		[databaseS setupDatabases];
		
		// Reset the tabs
		if (!IS_IPAD())
			[appDelegateS.rootViewController.navigationController popToRootViewControllerAnimated:NO];
        
		appDelegateS.window.backgroundColor = viewObjectsS.windowColor;
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ServerSwitched];
	}
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	if (self.segmentedControl.selectedSegmentIndex == 0)
		return settingsS.serverList.count;
	else
		return 0;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *cellIdentifier = @"ServerListCell";
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	
	ISMSServer *aServer = [settingsS.serverList objectAtIndexSafe:indexPath.row];
	
	// Set up the cell...
	UILabel *serverNameLabel = [[UILabel alloc] init];
	serverNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	serverNameLabel.backgroundColor = [UIColor clearColor];
	serverNameLabel.textAlignment = NSTextAlignmentLeft; // default
	serverNameLabel.font = ISMSBoldFont(20);
	[serverNameLabel setText:aServer.url];
	[cell.contentView addSubview:serverNameLabel];
	
	UILabel *detailsLabel = [[UILabel alloc] init];
	detailsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	detailsLabel.backgroundColor = [UIColor clearColor];
	detailsLabel.textAlignment = NSTextAlignmentLeft; // default
	detailsLabel.font = ISMSRegularFont(15);
	[detailsLabel setText:[NSString stringWithFormat:@"username: %@", aServer.username]];
	[cell.contentView addSubview:detailsLabel];
	
	UIImage *typeImage = nil;
	if ([aServer.type isEqualToString:SUBSONIC])
		typeImage = [UIImage imageNamed:@"server-subsonic.png"];
	else if ([aServer.type isEqualToString:UBUNTU_ONE])
		typeImage = [UIImage imageNamed:@"server-ubuntu.png"];

	UIImageView *serverType = [[UIImageView alloc] initWithImage:typeImage];
	serverType.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[cell.contentView addSubview:serverType];
	
	if([settingsS.urlString isEqualToString:aServer.url] && 
	   [settingsS.username isEqualToString:aServer.username] &&
	   [settingsS.password isEqualToString:aServer.password])
	{
		UIImageView *currentServerMarker = [[UIImageView alloc] init];
		currentServerMarker.image = [UIImage imageNamed:@"current-server.png"];
		[cell.contentView addSubview:currentServerMarker];
		
		currentServerMarker.frame = CGRectMake(3, 12, 26, 26);
		serverNameLabel.frame = CGRectMake(35, 0, 236, 25);
		detailsLabel.frame = CGRectMake(35, 27, 236, 18);
	}
	else 
	{
		serverNameLabel.frame = CGRectMake(5, 0, 266, 25);
		detailsLabel.frame = CGRectMake(5, 27, 266, 18);
	}
	serverType.frame = CGRectMake(271, 3, 44, 44);
	
	cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
	
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath)
		return;
	
	viewObjectsS.serverToEdit = [settingsS.serverList objectAtIndexSafe:indexPath.row];
    //DLog(@"viewObjectsS.serverToEdit.url: %@", viewObjectsS.serverToEdit.url);

	if (self.isEditing)
	{
		[self showServerEditScreen];
	}
	else
	{
		self.theNewRedirectionUrl = nil;
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Checking Server"];
        
        if ([viewObjectsS.serverToEdit.type isEqualToString:SUBSONIC] || [viewObjectsS.serverToEdit.type isEqualToString:UBUNTU_ONE])
        {
            SUSStatusLoader *statusLoader = [[SUSStatusLoader alloc] initWithDelegate:self];
            statusLoader.urlString = viewObjectsS.serverToEdit.url;
            statusLoader.username = viewObjectsS.serverToEdit.username;
            statusLoader.password = viewObjectsS.serverToEdit.password;
            [statusLoader startLoad];
        }
        else if ([viewObjectsS.serverToEdit.type isEqualToString:WAVEBOX])
        {
            PMSLoginLoader *loginLoader = [[PMSLoginLoader alloc] initWithDelegate:self urlString:viewObjectsS.serverToEdit.url username:viewObjectsS.serverToEdit.username password:viewObjectsS.serverToEdit.password];
            [loginLoader startLoad];
        }
	}
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath 
{
	NSArray *server = [ settingsS.serverList objectAtIndexSafe:fromIndexPath.row];
	[settingsS.serverList removeObjectAtIndex:fromIndexPath.row];
	[settingsS.serverList insertObject:server atIndex:toIndexPath.row];
	[[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject: settingsS.serverList] forKey:@"servers"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	[self.tableView reloadData];
}


// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath 
{
    if (editingStyle == UITableViewCellEditingStyleDelete) 
	{
		// Alert user to select new default server if they deleting the default
		if ([ settingsS.urlString isEqualToString:[(ISMSServer *)[ settingsS.serverList objectAtIndexSafe:indexPath.row] url]])
		{
			CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"Make sure to select a new server" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
			alert.tag = 4;
			[alert show];
		}
		
        // Delete the row from the data source
        [settingsS.serverList removeObjectAtIndex:indexPath.row];
		
		@try
		{
			[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
		}
		@catch (NSException *exception) 
		{
		//DLog(@"Exception: %@ - %@", exception.name, exception.reason);
		}
		
		[self.tableView reloadData];
		
		// Save the plist values
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject: settingsS.serverList] forKey:@"servers"];
		[defaults synchronize];
    }   
}

- (void)loadingRedirected:(ISMSLoader *)theLoader redirectUrl:(NSURL *)url
{
    NSMutableString *redirectUrlString = [NSMutableString stringWithFormat:@"%@://%@", url.scheme, url.host];
	if (url.port)
		[redirectUrlString appendFormat:@":%@", url.port];
	
	if ([url.pathComponents count] > 3)
	{
		for (NSString *component in url.pathComponents)
		{
			if ([component isEqualToString:@"api"] || [component isEqualToString:@"rest"])
				break;
			
			if (![component isEqualToString:@"/"])
			{
				[redirectUrlString appendFormat:@"/%@", component];
			}
		}
	}
	
    DLog(@"redirectUrlString: %@", redirectUrlString);
	
	self.theNewRedirectionUrl = [NSString stringWithString:redirectUrlString];
    
    //self.theNewRedirectionUrl = [NSString stringWithFormat:@"%@://%@:%@", url.scheme, url.host, url.port];
}

- (void)loadingFailed:(ISMSLoader *)theLoader withError:(NSError *)error
{
    UIAlertView *alert = nil;
	if (error.code == ISMSErrorCode_IncorrectCredentials)
	{
		alert = [[UIAlertView alloc] initWithTitle:@"Server Unavailable" message:[NSString stringWithFormat:@"Either your username or password is incorrect\n\n☆☆ Tap the gear in the top left and choose a server to return to online mode. ☆☆\n\nError code %li:\n%@", (long)[error code], [error localizedDescription]] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	}
	else
	{
		alert = [[UIAlertView alloc] initWithTitle:@"Server Unavailable" message:[NSString stringWithFormat:@"Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\n☆☆ Tap the gear in the top left and choose a server to return to online mode. ☆☆\n\nError code %li:\n%@", (long)[error code], [error localizedDescription]] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	}
	alert.tag = 3;
	[alert show];
        
    DLog(@"server verification failed, hiding loading screen");
    [viewObjectsS hideLoadingScreen];
}

- (void)loadingFinished:(ISMSLoader *)theLoader
{    	
	settingsS.serverType = viewObjectsS.serverToEdit.type;
	settingsS.urlString = viewObjectsS.serverToEdit.url;
	settingsS.username = viewObjectsS.serverToEdit.username;
	settingsS.password = viewObjectsS.serverToEdit.password;
    settingsS.redirectUrlString = self.theNewRedirectionUrl;
    
    if (theLoader.type == ISMSLoaderType_Login)
    {
        settingsS.sessionId = ((PMSLoginLoader *)theLoader).sessionId;
        settingsS.isVideoSupported = YES;
        [databaseS setCurrentMetadataDatabase];
    }
    else if (theLoader.type == ISMSLoaderType_Status && [viewObjectsS.serverToEdit.type isEqualToString:SUBSONIC])
    {
        settingsS.isVideoSupported = ((SUSStatusLoader *)theLoader).isVideoSupported;
        settingsS.isNewSearchAPI = ((SUSStatusLoader *)theLoader).isNewSearchAPI;
    }
	
	[self switchServer:nil];
    
    DLog(@"server verification passed, hiding loading screen");
    [viewObjectsS hideLoadingScreen];
}

@end

