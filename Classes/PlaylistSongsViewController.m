//
//  PlaylistSongsViewController.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "PlaylistSongsViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "PlaylistSongUITableViewCell.h"
#import "EGORefreshTableHeaderView.h"

#import "UIViewController+PushViewControllerCustom.h"

@interface PlaylistSongsViewController (Private)

- (void)dataSourceDidFinishLoadingNewData;

@end


@implementation PlaylistSongsViewController

@synthesize md5, serverPlaylist;
@synthesize reloading, refreshHeaderView;
@synthesize connection, receivedData, playlistCount; 

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];

    if (viewObjectsS.isLocalPlaylist)
	{
		self.title = [databaseS.localPlaylistsDbQueue stringForQuery:@"SELECT playlist FROM localPlaylists WHERE md5 = ?", self.md5];
		
		if (!settingsS.isOfflineMode)
		{
			UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
			headerView.backgroundColor = viewObjectsS.darkNormal;
			
			UIImageView *sendImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"upload-playlist.png"]];
			sendImage.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
			sendImage.frame = CGRectMake(23, 11, 24, 24);
			[headerView addSubview:sendImage];
			
			UILabel *sendLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 320, 50)];
			sendLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
			sendLabel.backgroundColor = [UIColor clearColor];
			sendLabel.textColor = ISMSHeaderTextColor;
			sendLabel.textAlignment = NSTextAlignmentCenter;
			sendLabel.font = ISMSBoldFont(30);
			sendLabel.text = @"Save to Server";
			[headerView addSubview:sendLabel];
			
			UIButton *sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
			sendButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
			sendButton.frame = CGRectMake(0, 0, 320, 40);
			[sendButton addTarget:self action:@selector(uploadPlaylistAction:) forControlEvents:UIControlEventTouchUpInside];
			[headerView addSubview:sendButton];
			
			self.tableView.tableHeaderView = headerView;
		}
		
		if (!IS_IPAD())
		{
			if (!self.tableView.tableHeaderView) self.tableView.tableHeaderView = [[UIView alloc] init];
		}
	}
	else
	{
        self.title = self.serverPlaylist.playlistName;
		playlistCount = [databaseS.localPlaylistsDbQueue intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM splaylist%@", md5]];
		[self.tableView reloadData];
		
		// Add the pull to refresh view
		self.refreshHeaderView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, 320.0f, self.tableView.bounds.size.height)];
		self.refreshHeaderView.backgroundColor = [UIColor whiteColor];
		[self.tableView addSubview:refreshHeaderView];
	}
	

	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
	
	if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
}

-(void)loadData
{
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(serverPlaylist.playlistId) forKey:@"id"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getPlaylist" parameters:parameters];
	
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		// Create the NSMutableData to hold the received data.
		// receivedData is an instance variable declared elsewhere.
		self.receivedData = [NSMutableData data];
		
		self.tableView.scrollEnabled = NO;
		[viewObjectsS showAlbumLoadingScreen:self.view sender:self];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error grabbing the playlist.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
	}
}	

- (void)cancelLoad
{
	[self.connection cancel];
	self.connection = nil;
	self.receivedData = nil;
	self.tableView.scrollEnabled = YES;
	[viewObjectsS hideLoadingScreen];
	
	if (!viewObjectsS.isLocalPlaylist)
	{
		[self dataSourceDidFinishLoadingNewData];
	}
}

- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
    
    // For some reason this controller needs to do this, but none of the others do :/
    self.navigationController.navigationBar.translucent = NO;
	
	if(musicS.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	if (viewObjectsS.isLocalPlaylist)
	{
		self.playlistCount = [databaseS.localPlaylistsDbQueue intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM playlist%@", self.md5]];
		[self.tableView reloadData];
	}
	else
	{
		if (self.playlistCount == 0)
		{
			[self loadData];
		}
	}
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void) settingsAction:(id)sender 
{
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverListViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverListViewController animated:YES];
}


- (IBAction)nowPlayingAction:(id)sender
{
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
}

- (void)uploadPlaylistAction:(id)sender
{	
	NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(self.title), @"name", nil];
    
	NSString *query = [NSString stringWithFormat:@"SELECT COUNT(*) FROM playlist%@", self.md5];
	NSUInteger count = [databaseS.localPlaylistsDbQueue intForQuery:query];
	NSMutableArray *songIds = [NSMutableArray arrayWithCapacity:count];
	for (int i = 1; i <= count; i++)
	{
		@autoreleasepool 
		{
			NSString *query = [NSString stringWithFormat:@"SELECT songId FROM playlist%@ WHERE ROWID = %i", self.md5, i];
			NSString *songId = [databaseS.localPlaylistsDbQueue stringForQuery:query];
			
			[songIds addObject:n2N(songId)];
		}
	}
	[parameters setObject:[NSArray arrayWithArray:songIds] forKey:@"songId"];
	
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"createPlaylist" parameters:parameters];
	
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		// Create the NSMutableData to hold the received data.
		// receivedData is an instance variable declared elsewhere.
		self.receivedData = [NSMutableData data];
		
		self.tableView.scrollEnabled = NO;
		[viewObjectsS showAlbumLoadingScreen:self.view sender:self];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error saving the playlist to the server.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
	}
}

#pragma mark Connection Delegate

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [self.receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	NSString *message = @"";
	if (viewObjectsS.isLocalPlaylist)
	{
		message = [NSString stringWithFormat:@"There was an error saving the playlist to the server.\n\nError %li: %@", 
											 (long)[error code],
											 [error localizedDescription]];
	}
	else
	{
		message = [NSString stringWithFormat:@"There was an error loading the playlist.\n\nError %li: %@",
				   (long)[error code],
				   [error localizedDescription]];
	}
	
	// Inform the user that the connection failed.
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	
	self.tableView.scrollEnabled = YES;
	[viewObjectsS hideLoadingScreen];
	
	self.connection = nil;
	self.receivedData = nil;
	
	[self dataSourceDidFinishLoadingNewData];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
    DLog(@"%@", [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);
	if (!viewObjectsS.isLocalPlaylist)
	{
        // Parse the data
        //
        RXMLElement *root = [[RXMLElement alloc] initFromXMLData:self.receivedData];
        if (![root isValid])
        {
            //NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
            // TODO: Handle this error
        }
        else
        {
            RXMLElement *error = [root child:@"error"];
            if ([error isValid])
            {
                //NSString *code = [error attribute:@"code"];
                //NSString *message = [error attribute:@"message"];
                //[self subsonicErrorCode:[code intValue] message:message];
                // TODO: Handle this error
            }
            else
            {
                // TODO: Handle !isValid case
                if ([[root child:@"playlist"] isValid])
                {
                    [databaseS removeServerPlaylistTable:self.md5];
                    [databaseS createServerPlaylistTable:self.md5];
                    [root iterate:@"playlist.entry" usingBlock:^(RXMLElement *e) {
                        ISMSSong *aSong = [[ISMSSong alloc] initWithRXMLElement:e];
                        [aSong insertIntoServerPlaylistWithPlaylistId:self.md5];
                    }];
                }
            }
        }
		
		self.tableView.scrollEnabled = YES;

		self.playlistCount = [databaseS.localPlaylistsDbQueue intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM splaylist%@", self.md5]];
		[self.tableView reloadData];
		
		[self dataSourceDidFinishLoadingNewData];
		
		[viewObjectsS hideLoadingScreen];
	}
	else
	{
		[self parseData];
	}
	
	self.tableView.scrollEnabled = YES;
	self.receivedData = nil;
	self.connection = nil;
}

static NSString *kName_Error = @"error";

- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil];
	alert.tag = 1;
	[alert show];
	//DLog(@"Subsonic error %@:  %@", errorCode, message);
}

- (void)parseData
{
    // Parse the data
    //
    RXMLElement *root = [[RXMLElement alloc] initFromXMLData:self.receivedData];
    if (![root isValid])
    {
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
        [self subsonicErrorCode:nil message:error.description];
    }
    else
    {
        RXMLElement *error = [root child:@"error"];
        if ([error isValid])
        {
            NSString *code = [error attribute:@"code"];
            NSString *message = [error attribute:@"message"];
            [self subsonicErrorCode:code message:message];
        }
    }
    
    [viewObjectsS hideLoadingScreen];
}


#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	return self.playlistCount;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *cellIdentifier = @"PlaylistSongCell";
	PlaylistSongUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell)
	{
		cell = [[PlaylistSongUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}
	
	cell.indexPath = indexPath;
	
	// Set up the cell...
	ISMSSong *aSong;
	if (viewObjectsS.isLocalPlaylist)
	{
		aSong = [ISMSSong songFromDbRow:indexPath.row inTable:[NSString stringWithFormat:@"playlist%@", self.md5] inDatabaseQueue:databaseS.localPlaylistsDbQueue];
		//DLog(@"aSong: %@", aSong);
	}
	else
	{
		//aSong = [viewObjectsS.listOfPlaylistSongs objectAtIndexSafe:indexPath.row];
		aSong = [ISMSSong songFromServerPlaylistId:self.md5 row:indexPath.row];
	}
	cell.mySong = aSong;
	
	cell.coverArtView.coverArtId = aSong.coverArtId;
	
    if (aSong.isFullyCached)
    {
        cell.backgroundView = [[UIView alloc] init];
        cell.backgroundView.backgroundColor = [viewObjectsS currentLightColor];
    }
    else
    {
        cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
    }
	
	[cell.numberLabel setText:[NSString stringWithFormat:@"%li", (long)(indexPath.row + 1)]];
	[cell.songNameLabel setText:aSong.title];
	if (aSong.album)
		[cell.artistNameLabel setText:[NSString stringWithFormat:@"%@ - %@", aSong.artist, aSong.album]];
	else
		[cell.artistNameLabel setText:aSong.artist];
	
	return cell;
}

- (void)didSelectRowInternal:(NSIndexPath *)indexPath
{
	// Clear the current playlist
	if (settingsS.isJukeboxEnabled)
	{
		[databaseS resetJukeboxPlaylist];
		[jukeboxS jukeboxClearRemotePlaylist];
	}
	else
	{
		[databaseS resetCurrentPlaylistDb];
	}
	
	playlistS.isShuffle = NO;
	
	/*for (int i = 0; i < self.playlistCount; i++)
	{
		@autoreleasepool
		{
			ISMSSong *aSong;
			if (viewObjectsS.isLocalPlaylist)
			{
				aSong = [ISMSSong songFromDbRow:i inTable:[NSString stringWithFormat:@"playlist%@", self.md5] inDatabaseQueue:databaseS.localPlaylistsDbQueue];
			}
			else
			{
				aSong = [ISMSSong songFromServerPlaylistId:self.md5 row:i];
			}
			
			[aSong addToCurrentPlaylistDbQueue];
		}
	}*/
	
	// Need to do this for speed
	NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", [settingsS.urlString md5]];
	NSString *currTableName = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
	NSString *playTableName = [NSString stringWithFormat:@"%@%@", viewObjectsS.isLocalPlaylist ? @"playlist" : @"splaylist", self.md5];
	[databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
	 {
		 [db executeUpdate:@"ATTACH DATABASE ? AS ?", [databaseS.databaseFolderPath stringByAppendingPathComponent:databaseName], @"currentPlaylistDb"];
		 if ([db hadError]) { DLog(@"Err attaching the currentPlaylistDb %d: %@", [db lastErrorCode], [db lastErrorMessage]); }
		 
		 [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ SELECT * FROM %@", currTableName, playTableName]];
		 [db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
	 }];
	
	if (settingsS.isJukeboxEnabled)
		[jukeboxS jukeboxReplacePlaylistWithLocal];

    [viewObjectsS hideLoadingScreen];
    
    ISMSSong *playedSong = [musicS playSongAtPosition:indexPath.row];
    if (!playedSong.isVideo)
        [self showPlayer];
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath)
		return;
	
	if (viewObjectsS.isCellEnabled)
	{
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
		[self performSelector:@selector(didSelectRowInternal:) withObject:indexPath afterDelay:0.05];
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

#pragma mark -
#pragma mark Pull to refresh methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{	
	if (scrollView.isDragging && !viewObjectsS.isLocalPlaylist) 
	{
		if (self.refreshHeaderView.state == EGOOPullRefreshPulling && scrollView.contentOffset.y > -65.0f && scrollView.contentOffset.y < 0.0f && !self.reloading) 
		{
			[self.refreshHeaderView setState:EGOOPullRefreshNormal];
		} 
		else if (self.refreshHeaderView.state == EGOOPullRefreshNormal && scrollView.contentOffset.y < -65.0f && !self.reloading) 
		{
			[self.refreshHeaderView setState:EGOOPullRefreshPulling];
		}
	}
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	
	if (scrollView.contentOffset.y <= - 65.0f && !self.reloading && !viewObjectsS.isLocalPlaylist) 
	{
		self.reloading = YES;
		//[self reloadAction:nil];
		[self loadData];
		[self.refreshHeaderView setState:EGOOPullRefreshLoading];
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.2];
		self.tableView.contentInset = UIEdgeInsetsMake(60.0f, 0.0f, 0.0f, 0.0f);
		[UIView commitAnimations];
	}
}

- (void)dataSourceDidFinishLoadingNewData
{
	self.reloading = NO;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	[self.tableView setContentInset:UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f)];
	[UIView commitAnimations];
	
	[self.refreshHeaderView setState:EGOOPullRefreshNormal];
}



@end

