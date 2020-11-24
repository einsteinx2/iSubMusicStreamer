//
//  ServerListViewController.m
//  iSub
//
//  Created by Ben Baron on 3/31/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ServerListViewController.h"
#import "SettingsTabViewController.h"
#import "FoldersViewController.h"
#import "SUSStatusLoader.h"
#import "SUSAllSongsLoader.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "AudioEngine.h"
#import "SavedSettings.h"
#import "DatabaseSingleton.h"
#import "ISMSStreamManager.h"
#import "ISMSErrorDomain.h"
#import "ISMSServer.h"
#import "EX2Kit.h"
#import "Swift.h"

LOG_LEVEL_ISUB_DEFAULT

@implementation ServerListViewController

- (void)dealloc {
	[NSNotificationCenter removeObserverOnMainThread:self];
}

- (void)viewDidLoad  {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorNamed:@"isubBackgroundColor"];
    	
	self.tableView.allowsSelectionDuringEditing = YES;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
	
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(reloadTable) name:@"reloadServerList"];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(showSaveButton) name:@"showSaveButton"];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(switchServer:) name:@"switchServer"];
	
	self.title = @"Servers";
    if (self != [[self.navigationController viewControllers] objectAtIndexSafe:0]) {
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:self action:@selector(saveAction:)];
    }
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
	
    if (settingsS.serverList == nil || [settingsS.serverList count] == 0) {
		[self addAction:nil];
    }
	
    self.segmentControlContainer = [[UIView alloc] init];
    self.segmentControlContainer.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Servers", @"Settings"]];
    self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.segmentedControl addTarget:self action:@selector(segmentAction:) forControlEvents:UIControlEventValueChanged];
    self.segmentedControl.selectedSegmentIndex = 0;

    [self.segmentControlContainer addSubview:self.segmentedControl];
    [self.view addSubview:self.segmentControlContainer];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.segmentControlContainer.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:7],
        [self.segmentControlContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:5],
        [self.segmentControlContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-5],
        [self.segmentControlContainer.heightAnchor constraintEqualToConstant:36],
        
        [self.segmentedControl.topAnchor constraintEqualToAnchor:self.segmentControlContainer.topAnchor],
        [self.segmentedControl.bottomAnchor constraintEqualToAnchor:self.segmentControlContainer.bottomAnchor],
        [self.segmentedControl.leadingAnchor constraintEqualToAnchor:self.segmentControlContainer.leadingAnchor],
        [self.segmentedControl.trailingAnchor constraintEqualToAnchor:self.segmentControlContainer.trailingAnchor]
    ]];
    
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.segmentControlContainer.bottomAnchor constant:7],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
}

- (void)reloadTable {
	[self.tableView reloadData];
}

- (void)showSaveButton {
	if (!self.isEditing) {
        if (self == [[self.navigationController viewControllers] firstObject]) {
			self.navigationItem.leftBarButtonItem = nil;
        } else {
			self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:self action:@selector(saveAction:)];
        }
	}
}

- (void)segmentAction:(id)sender {
	self.settingsTabViewController.parentController = nil;
	self.settingsTabViewController = nil;
	
	if (self.segmentedControl.selectedSegmentIndex == 0) {
		self.title = @"Servers";
		self.tableView.tableFooterView = nil;
		self.tableView.scrollEnabled = YES;
		self.navigationItem.rightBarButtonItem = self.editButtonItem;
		[self.tableView reloadData];
	} else if (self.segmentedControl.selectedSegmentIndex == 1) {
		self.title = @"Settings";
		self.tableView.scrollEnabled = YES;
		[self setEditing:NO animated:NO];
		self.navigationItem.rightBarButtonItem = nil;
		self.settingsTabViewController = [[SettingsTabViewController alloc] initWithNibName:@"SettingsTabViewController" bundle:nil];
		self.settingsTabViewController.parentController = self;
        if (UIDevice.isIPad) {
            UIView *settingsView = self.settingsTabViewController.view;
            UIView *settingsContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.width, settingsView.height)];
            settingsContainer.backgroundColor = settingsView.backgroundColor;
            [settingsContainer addSubview:self.settingsTabViewController.view];
            
            settingsView.translatesAutoresizingMaskIntoConstraints = NO;
            [NSLayoutConstraint activateConstraints:@[
                [settingsView.widthAnchor constraintEqualToConstant:400],
                [settingsView.heightAnchor constraintEqualToAnchor:settingsContainer.heightAnchor],
                [settingsView.topAnchor constraintEqualToAnchor:settingsContainer.topAnchor],
                [settingsView.centerXAnchor constraintEqualToAnchor:settingsContainer.centerXAnchor]
            ]];
            self.tableView.tableFooterView = settingsContainer;
        } else {
            self.tableView.tableFooterView = self.settingsTabViewController.view;
        }
		
		[self.tableView reloadData];
	}
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animate {
    [super setEditing:editing animated:animate];
    if (editing) {
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addAction:)];
    } else {
		[self showSaveButton];
    }
}

- (void)addAction:(id)sender {
	viewObjectsS.serverToEdit = nil;
	
    ServerEditViewController *serverEditViewController = [[ServerEditViewController alloc] init];
    serverEditViewController.modalPresentationStyle = UIModalPresentationFormSheet;
    if (UIDevice.isIPad) {
        [appDelegateS.padRootViewController presentViewController:serverEditViewController animated:YES completion:nil];
    } else {
        [self presentViewController:serverEditViewController animated:YES completion:nil];
    }
}

- (void)saveAction:(id)sender {
	[self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)showServerEditScreen {
    ServerEditViewController *serverEditViewController = [[ServerEditViewController alloc] init];
    serverEditViewController.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:serverEditViewController animated:YES completion:nil];
}

- (void)switchServer:(NSNotification*)notification  {
    // Save the url string first because the other settings in the if block below are saved using the url
    settingsS.urlString = viewObjectsS.serverToEdit.url;

	if (notification.userInfo) {
        settingsS.isVideoSupported = [notification.userInfo[@"isVideoSupported"] boolValue];
        settingsS.isNewSearchAPI = [notification.userInfo[@"isNewSearchAPI"] boolValue];
	}
	
	// Save the plist values
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:viewObjectsS.serverToEdit.url forKey:@"url"];
	[defaults setObject:viewObjectsS.serverToEdit.username forKey:@"username"];
	[defaults setObject:viewObjectsS.serverToEdit.password forKey:@"password"];
    NSData *archivedServerList = [NSKeyedArchiver archivedDataWithRootObject:settingsS.serverList requiringSecureCoding:YES error:nil];
	[defaults setObject:archivedServerList forKey:@"servers"];
	[defaults synchronize];
	
	// Update the variables
	settingsS.serverType = viewObjectsS.serverToEdit.type;
	settingsS.username = viewObjectsS.serverToEdit.username;
	settingsS.password = viewObjectsS.serverToEdit.password;
    settingsS.uuid = viewObjectsS.serverToEdit.uuid;
    settingsS.lastQueryId = viewObjectsS.serverToEdit.lastQueryId;
    		
	if (self == [[self.navigationController viewControllers] objectAtIndexSafe:0] && !UIDevice.isIPad) {
		[self.navigationController.view removeFromSuperview];
	} else {
		[self.navigationController popToRootViewControllerAnimated:YES];
		
        if ([appDelegateS.wifiReach currentReachabilityStatus] == NotReachable) {
			return;
        }
		
		// Cancel any caching
		[streamManagerS removeAllStreams];
		
		// Cancel any tab loads
		if ([SUSAllSongsLoader isLoading]) {
			settingsS.isCancelLoading = YES;
		}
    
		while (settingsS.isCancelLoading) {
            if (!settingsS.isCancelLoading){
				break;
            }
		}
		
		// Stop any playing song and remove old tab bar controller from window
		[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:@"recover"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[audioEngineS.player stop];
		settingsS.isJukeboxEnabled = NO;
		
		if (settingsS.isOfflineMode) {
			settingsS.isOfflineMode = NO;
			
			if (UIDevice.isIPad) {
				[appDelegateS.padRootViewController.menuViewController toggleOfflineMode];
			} else {
				for (UIView *subview in appDelegateS.window.subviews) {
					[subview removeFromSuperview];
				}
				[viewObjectsS orderMainTabBarController];
			}
		}
		
		// Reset the databases
		[databaseS closeAllDatabases];
		
		[databaseS setupDatabases];
		
		// Reset the tabs
        if (!UIDevice.isIPad) {
			[appDelegateS.rootViewController.navigationController popToRootViewControllerAnimated:NO];
        }
        
		appDelegateS.window.backgroundColor = viewObjectsS.windowColor;
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ServerSwitched];
	}
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.segmentedControl.selectedSegmentIndex == 0) {
		return settingsS.serverList.count;
    } else {
		return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *cellIdentifier = @"ServerListCell";
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	
	ISMSServer *aServer = [settingsS.serverList objectAtIndexSafe:indexPath.row];
	
	// Set up the cell...
	UILabel *serverNameLabel = [[UILabel alloc] init];
	serverNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	serverNameLabel.backgroundColor = [UIColor clearColor];
	serverNameLabel.textAlignment = NSTextAlignmentLeft; // default
	serverNameLabel.font = [UIFont boldSystemFontOfSize:20];
	[serverNameLabel setText:aServer.url];
	[cell.contentView addSubview:serverNameLabel];
	
	UILabel *detailsLabel = [[UILabel alloc] init];
	detailsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	detailsLabel.backgroundColor = [UIColor clearColor];
	detailsLabel.textAlignment = NSTextAlignmentLeft; // default
    detailsLabel.font = [UIFont systemFontOfSize:15];
	[detailsLabel setText:[NSString stringWithFormat:@"username: %@", aServer.username]];
	[cell.contentView addSubview:detailsLabel];
	
    UIImage *typeImage = [UIImage imageNamed:@"server-subsonic.png"];

	UIImageView *serverType = [[UIImageView alloc] initWithImage:typeImage];
	serverType.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[cell.contentView addSubview:serverType];
	
	if ([settingsS.urlString isEqualToString:aServer.url] && [settingsS.username isEqualToString:aServer.username] && [settingsS.password isEqualToString:aServer.password]) {
		UIImageView *currentServerMarker = [[UIImageView alloc] init];
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            currentServerMarker.image = [[UIImage imageNamed:@"current-server.png"] imageWithTint:UIColor.whiteColor];
        } else {
            currentServerMarker.image = [UIImage imageNamed:@"current-server.png"];
        }
		[cell.contentView addSubview:currentServerMarker];
		
		currentServerMarker.frame = CGRectMake(3, 12, 26, 26);
		serverNameLabel.frame = CGRectMake(35, 0, 236, 25);
		detailsLabel.frame = CGRectMake(35, 27, 236, 18);
	} else {
		serverNameLabel.frame = CGRectMake(5, 0, 266, 25);
		detailsLabel.frame = CGRectMake(5, 27, 266, 18);
	}
	serverType.frame = CGRectMake(271, 3, 44, 44);
		
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath  {
	if (!indexPath) return;
	
	viewObjectsS.serverToEdit = [settingsS.serverList objectAtIndexSafe:indexPath.row];

	if (self.isEditing) {
		[self showServerEditScreen];
	} else {
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Checking Server"];
        
        SUSStatusLoader *statusLoader = [[SUSStatusLoader alloc] initWithDelegate:self];
        statusLoader.urlString = viewObjectsS.serverToEdit.url;
        statusLoader.username = viewObjectsS.serverToEdit.username;
        statusLoader.password = viewObjectsS.serverToEdit.password;
        [statusLoader startLoad];
	}
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath  {
	return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath  {
	NSArray *server = [ settingsS.serverList objectAtIndexSafe:fromIndexPath.row];
	[settingsS.serverList removeObjectAtIndex:fromIndexPath.row];
	[settingsS.serverList insertObject:server atIndex:toIndexPath.row];
    NSData *archivedServerList = [NSKeyedArchiver archivedDataWithRootObject:settingsS.serverList requiringSecureCoding:YES error:nil];
	[[NSUserDefaults standardUserDefaults] setObject:archivedServerList forKey:@"servers"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	[self.tableView reloadData];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
		// Alert user to select new default server if they deleting the default
		if ([settingsS.urlString isEqualToString:[(ISMSServer *)[settingsS.serverList objectAtIndexSafe:indexPath.row] url]]) {
            if (settingsS.isPopupsEnabled) {
                NSString *message = @"Make sure to select a new server";
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Notice" message:message preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
		}
		
        // Delete the row from the data source
        [settingsS.serverList removeObjectAtIndex:indexPath.row];
		
		@try {
			[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
		} @catch (NSException *exception) {
            //DLog(@"Exception: %@ - %@", exception.name, exception.reason);
		}
		
		[self.tableView reloadData];
		
		// Save the plist values
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSData *archivedServerList = [NSKeyedArchiver archivedDataWithRootObject:settingsS.serverList requiringSecureCoding:YES error:nil];
		[defaults setObject:archivedServerList forKey:@"servers"];
		[defaults synchronize];
    }   
}

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error {
    NSString *message = nil;
	if (error.code == ISMSErrorCode_IncorrectCredentials) {
		message = [NSString stringWithFormat:@"Either your username or password is incorrect\n\n☆☆ Choose a server to return to online mode. ☆☆\n\nError code %li:\n%@", (long)error.code, error.localizedDescription];
	} else {
        message = [NSString stringWithFormat:@"Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\n☆☆ Choose a server to return to online mode. ☆☆\n\nError code %li:\n%@", (long)error.code, error.localizedDescription];
	}
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Server Unavailable" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
        
    DDLogError(@"server verification failed, hiding loading screen");
    [viewObjectsS hideLoadingScreen];
}

- (void)loadingFinished:(SUSLoader *)theLoader {
	settingsS.serverType = viewObjectsS.serverToEdit.type;
	settingsS.urlString = viewObjectsS.serverToEdit.url;
	settingsS.username = viewObjectsS.serverToEdit.username;
	settingsS.password = viewObjectsS.serverToEdit.password;
    
    if (theLoader.type == SUSLoaderType_Status) {
        settingsS.isVideoSupported = ((SUSStatusLoader *)theLoader).isVideoSupported;
        settingsS.isNewSearchAPI = ((SUSStatusLoader *)theLoader).isNewSearchAPI;
    }
	
	[self switchServer:nil];
    
    DDLogVerbose(@"server verification passed, hiding loading screen");
    [viewObjectsS hideLoadingScreen];
}

@end
