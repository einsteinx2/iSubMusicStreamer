//
//  ServerListViewController.m
//  iSub
//
//  Created by Ben Baron on 3/31/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ServerListViewController.h"
#import "SettingsTabViewController.h"
#import "Defines.h"
#import "AudioEngine.h"
#import "SavedSettings.h"
#import "ISMSStreamManager.h"
#import "ISMSErrorDomain.h"
#import "EX2Kit.h"
#import "Swift.h"
#import "Reachability.h"

LOG_LEVEL_ISUB_DEFAULT

@interface ServerListViewController() <APILoaderDelegate>
@end

@implementation ServerListViewController

- (void)dealloc {
	[NSNotificationCenter removeObserverOnMainThread:self];
}

- (void)viewDidLoad  {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorNamed:@"isubBackgroundColor"];
    	
	self.tableView.allowsSelectionDuringEditing = YES;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
	
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(reloadTable) name:@"reloadServerList" object:nil];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(showSaveButton) name:@"showSaveButton" object:nil];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(switchServer:) name:@"switchServer" object:nil];
	
	self.title = @"Servers";
    if (self != self.navigationController.viewControllers.firstObject) {
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:self action:@selector(saveAction:)];
    }
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    self.servers = Store.shared.servers;
	
    if (self.servers.count == 0) {
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
    [self.settingsTabViewController removeFromParentViewController];
    [self.settingsTabViewController.view removeFromSuperview];
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
        [self addChildViewController:self.settingsTabViewController];
        if (UIDevice.isPad) {
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
    ServerEditViewController *serverEditViewController = [[ServerEditViewController alloc] init];
    serverEditViewController.modalPresentationStyle = UIModalPresentationFormSheet;
    if (UIDevice.isPad) {
        [SceneDelegate.shared.padRootViewController presentViewController:serverEditViewController animated:YES completion:nil];
    } else {
        [self presentViewController:serverEditViewController animated:YES completion:nil];
    }
}

- (void)saveAction:(id)sender {
	[self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)switchServer:(NSNotification*)notification {
    self.servers = Store.shared.servers;
    self.serverToEdit = nil;
    NSInteger serverId = [notification.userInfo[@"serverId"] integerValue];
    Server *currentServer = [Store.shared serverWithId:serverId];
    currentServer.isVideoSupported = [notification.userInfo[@"isVideoSupported"] boolValue];
    currentServer.isNewSearchSupported = [notification.userInfo[@"isNewSearchSupported"] boolValue];
    // Update server properties
    (void)[Store.shared addWithServer:currentServer];

    settingsS.currentServer = currentServer;
    [self switchServer];
}

- (void)switchServer {
	if (self == self.navigationController.viewControllers.firstObject && !UIDevice.isPad) {
		[self.navigationController.view removeFromSuperview];
	} else {
		[self.navigationController popToRootViewControllerAnimated:YES];
		
        if (!AppDelegate.shared.isNetworkReachable) {
			return;
        }
		
		// Cancel any caching
		[streamManagerS removeAllStreams];
		
		// Cancel any tab loads
        settingsS.isCancelLoading = YES;
    
		while (settingsS.isCancelLoading) {
            if (!settingsS.isCancelLoading){
				break;
            }
		}
		
		// Stop any playing song and remove old tab bar controller from window
		[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:@"recover"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[BassGaplessPlayer.shared stop];
		settingsS.isJukeboxEnabled = NO;
		
		if (settingsS.isOfflineMode) {
			settingsS.isOfflineMode = NO;
			
			if (UIDevice.isPad) {
                [SceneDelegate.shared.padRootViewController.menuViewController toggleOfflineMode];
			} else {
				for (UIView *subview in SceneDelegate.shared.window.subviews) {
					[subview removeFromSuperview];
				}
			}
		}
		
		// Reset the databases
        [Store.shared closeAllDatabases];
        [Store.shared setupDatabases];
		
		// Reset the tabs
        if (!UIDevice.isPad) {
            for (UIViewController *controller in SceneDelegate.shared.tabBarController.viewControllers) {
                if ([controller isKindOfClass:UINavigationController.class]) {
                    [(UINavigationController *)controller popToRootViewControllerAnimated:NO];
                }
            }
        }
        
//		SceneDelegate.shared.window.backgroundColor = viewObjectsS.windowColor;
		
		[NSNotificationCenter postOnMainThreadWithName:Notifications.serverSwitched object:nil userInfo:nil];
	}
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.segmentedControl.selectedSegmentIndex == 0 ? self.servers.count : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *cellIdentifier = @"ServerListCell";
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	
    Server *server = self.servers[indexPath.row];
	
	// Set up the cell...
	UILabel *serverNameLabel = [[UILabel alloc] init];
	serverNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	serverNameLabel.backgroundColor = [UIColor clearColor];
	serverNameLabel.textAlignment = NSTextAlignmentLeft; // default
	serverNameLabel.font = [UIFont boldSystemFontOfSize:20];
	[serverNameLabel setText:server.url.absoluteString];
	[cell.contentView addSubview:serverNameLabel];
	
	UILabel *detailsLabel = [[UILabel alloc] init];
	detailsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	detailsLabel.backgroundColor = [UIColor clearColor];
	detailsLabel.textAlignment = NSTextAlignmentLeft; // default
    detailsLabel.font = [UIFont systemFontOfSize:15];
	[detailsLabel setText:[NSString stringWithFormat:@"username: %@", server.username]];
	[cell.contentView addSubview:detailsLabel];
	
    UIImage *typeImage = [UIImage imageNamed:@"server-subsonic"];

	UIImageView *serverType = [[UIImageView alloc] initWithImage:typeImage];
	serverType.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[cell.contentView addSubview:serverType];
	
    if ([server isEqual:settingsS.currentServer]) {
		UIImageView *currentServerMarker = [[UIImageView alloc] init];
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            currentServerMarker.image = [[UIImage imageNamed:@"current-server"] imageWithTint:UIColor.whiteColor];
        } else {
            currentServerMarker.image = [UIImage imageNamed:@"current-server"];
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
	
    self.serverToEdit = self.servers[indexPath.row];

	if (self.isEditing) {
        ServerEditViewController *serverEditViewController = [[ServerEditViewController alloc] init];
        serverEditViewController.modalPresentationStyle = UIModalPresentationFormSheet;
        serverEditViewController.serverToEdit = self.serverToEdit;
        [self presentViewController:serverEditViewController animated:YES completion:nil];
	} else {
        [HUD showWithMessage:@"Checking Server"];
        if (self.serverToEdit) {
            StatusLoader *statusLoader = [[StatusLoader alloc] initWithUrlString:self.serverToEdit.url.absoluteString username:self.serverToEdit.username password:self.serverToEdit.password delegate:self];
            [statusLoader startLoad];
        }
	}
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

// TODO: Delete all server resources (maybe do it in the Store)
// TODO: Automatically switch to another server or show the add server screen
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        Server *server = self.servers[indexPath.row];
        (void)[Store.shared deleteServerWithId:server.serverId];
        self.servers = Store.shared.servers;
        
		// Alert user to select new default server if they deleting the default
        if ([server isEqual:settingsS.currentServer]) {
            if (settingsS.isPopupsEnabled) {
                NSString *message = @"Make sure to select a new server";
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Notice" message:message preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
		}
		
		@try {
			[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
		} @catch (NSException *exception) {
            [self.tableView reloadData];
		}
    }   
}

- (void)loadingFinished:(APILoader *)loader {
    // Update server properties
    if (loader.type == APILoaderTypeStatus) {
        self.serverToEdit.isVideoSupported = ((StatusLoader *)loader).isVideoSupported;
        self.serverToEdit.isNewSearchSupported = ((StatusLoader *)loader).isNewSearchSupported;
        if (self.serverToEdit) {
            (void)[Store.shared addWithServer:self.serverToEdit];
        }
    }
    
    // Switch to the server
    settingsS.currentServer = self.serverToEdit;
    [self switchServer];
    
    DDLogInfo(@"[ServerListViewController] server verification passed, hiding loading screen");
    [HUD hide];
}

- (void)loadingFailed:(APILoader *)loader error:(NSError *)error {
    NSString *message = nil;
	if (error.code == ISMSErrorCode_IncorrectCredentials) {
		message = [NSString stringWithFormat:@"Either your username or password is incorrect\n\n☆☆ Choose a server to return to online mode. ☆☆\n\nError code %li:\n%@", (long)error.code, error.localizedDescription];
	} else {
        message = [NSString stringWithFormat:@"Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\n☆☆ Choose a server to return to online mode. ☆☆\n\nError code %li:\n%@", (long)error.code, error.localizedDescription];
	}
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Server Unavailable" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
        
    DDLogError(@"[ServerListViewController] server verification failed, hiding loading screen");
    [HUD hide];
}

@end
