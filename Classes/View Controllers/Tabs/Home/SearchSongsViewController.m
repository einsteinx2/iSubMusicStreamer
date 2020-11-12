//
//  SearchSongsViewController.m
//  iSub
//
//  Created by bbaron on 10/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SearchSongsViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "AlbumViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "SearchXMLParser.h"
#import "CustomUIAlertView.h"
#import "NSMutableURLRequest+SUS.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "JukeboxSingleton.h"
#import "ISMSArtist.h"
#import "ISMSAlbum.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"
#import "Swift.h"

@implementation SearchSongsViewController

#pragma mark View lifecycle

- (BOOL)shouldAutorotate {
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait) {
        return NO;
    }
    
    return YES;
}

- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b;
{
    if ((self = [super initWithNibName:n bundle:b]))
    {
		self.offset = 0;
		self.isMoreResults = YES;
		self.isLoading = NO;
    }
    return self;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	if(musicS.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
    
    self.tableView.rowHeight = 60.0;
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
	
	if (!self.tableView.tableHeaderView) self.tableView.tableHeaderView = [[UIView alloc] init];
	if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
}
		
- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	[self.connection cancel];
	self.connection = nil;
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

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	if (self.searchType == ISMSSearchSongsSearchType_Artists)
	{
		return self.listOfArtists.count + 1;
	}
	else if (self.searchType == ISMSSearchSongsSearchType_Albums)
	{
		return self.listOfAlbums.count + 1;
	}
	else
	{
		return self.listOfSongs.count + 1;
	}
}

- (void)loadMoreResults
{
	if (self.isLoading)
		return;
	
	self.isLoading = YES;
	
	self.offset += 20;
    NSDictionary *parameters = nil;
    NSString *action = nil;
	NSString *offsetString = [NSString stringWithFormat:@"%lu", (unsigned long)self.offset];
	if (settingsS.isNewSearchAPI)
	{
        action = @"search2";
		NSString *queryString = [NSString stringWithFormat:@"%@*", self.query];
		switch (self.searchType) 
		{
			case ISMSSearchSongsSearchType_Artists:
				parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"20", @"artistCount", @"0", @"albumCount", @"0", @"songCount", 
							  n2N(queryString), @"query", n2N(offsetString), @"artistOffset", nil];
				break;
			case ISMSSearchSongsSearchType_Albums:
				parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"0", @"artistCount", @"20", @"albumCount", @"0", @"songCount", 
							  n2N(queryString), @"query", n2N(offsetString), @"albumOffset", nil];
				break;
			case ISMSSearchSongsSearchType_Songs:
				parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"0", @"artistCount", @"0", @"albumCount", @"20", @"songCount", 
							  n2N(queryString), @"query", n2N(offsetString), @"songOffset", nil];
				break;
			default:
				break;
		}
	}
	else
	{
        action = @"search";
        parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"20", @"count", n2N(self.query), @"any", n2N(offsetString), @"offset", nil];
	}
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:action parameters:parameters];

	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		self.receivedData = [[NSMutableData alloc] initWithCapacity:0];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error performing the search.\n\nThe connection could not be created" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
	}
}

- (UITableViewCell *)createLoadingCell:(NSUInteger)row
{
	// This is the last cell and there could be more results, load the next 20 results;
	UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"NoReuse"];
		
	if (self.isMoreResults)
	{
		cell.textLabel.text = @"Loading more results...";
        UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
		CGFloat y = [self tableView:self.tableView heightForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]] / 2.;
		indicator.center = CGPointMake(300, y);
		indicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[cell addSubview:indicator];
		[indicator startAnimating];
		
		[self loadMoreResults];
	}
	else 
	{
		if (self.listOfArtists.count > 0 || self.listOfAlbums.count > 0 || self.listOfSongs.count > 0)
		{			
			cell.textLabel.text = @"No more search results";
		}
		else
		{
			cell.textLabel.text = @"No results";
		}
	}
	
	return cell;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.searchType == ISMSSearchSongsSearchType_Artists) {
		if (indexPath.row < self.listOfArtists.count) {
            // Artist
            UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
            cell.hideNumberLabel = YES;
            cell.hideCoverArt = YES;
            cell.hideSecondaryLabel = YES;
            cell.hideDurationLabel = YES;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            [cell updateWithModel:[self.listOfArtists objectAtIndexSafe:indexPath.row]];
            return cell;
		} else if (indexPath.row == self.listOfArtists.count) {
			return [self createLoadingCell:indexPath.row];
		}
	} else if (self.searchType == ISMSSearchSongsSearchType_Albums) {
		if (indexPath.row < self.listOfAlbums.count) {
            // Album
            UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
            cell.hideNumberLabel = YES;
            cell.hideCoverArt = NO;
            cell.hideDurationLabel = YES;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            [cell updateWithModel:[self.listOfAlbums objectAtIndexSafe:indexPath.row]];
            return cell;
		} else if (indexPath.row == [self.listOfAlbums count]) {
			return [self createLoadingCell:indexPath.row];
		}
	} else {
		if (indexPath.row < self.listOfSongs.count) {
            // Song
            UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
            cell.hideNumberLabel = YES;
            cell.hideCoverArt = NO;
            cell.hideDurationLabel = YES;
            cell.accessoryType = UITableViewCellAccessoryNone;
            [cell updateWithModel:[self.listOfSongs objectAtIndexSafe:indexPath.row]];
            return cell;
		} else if (indexPath.row == self.listOfSongs.count) {
			return [self createLoadingCell:indexPath.row];
		}
	}
	
	// In case somehow no cell is created, return an empty cell
	static NSString *cellIdentifier = @"EmptyCell";
	return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{	
	if (!indexPath)
		return;
	
	if (self.searchType == ISMSSearchSongsSearchType_Artists)
	{
		if (viewObjectsS.isCellEnabled && indexPath.row != self.listOfArtists.count)
		{
			ISMSArtist *anArtist = [self.listOfArtists objectAtIndexSafe:indexPath.row];
			AlbumViewController *albumView = [[AlbumViewController alloc] initWithArtist:anArtist orAlbum:nil];
			
			[self pushViewControllerCustom:albumView];
			//[self.navigationController pushViewController:albumView animated:YES];
			
			return;
		}
	}
	else if (self.searchType == ISMSSearchSongsSearchType_Albums)
	{
		if (viewObjectsS.isCellEnabled && indexPath.row != self.listOfAlbums.count)
		{
			ISMSAlbum *anAlbum = [self.listOfAlbums objectAtIndexSafe:indexPath.row];
			AlbumViewController *albumView = [[AlbumViewController alloc] initWithArtist:nil orAlbum:anAlbum];
			
			[self pushViewControllerCustom:albumView];
			//[self.navigationController pushViewController:albumView animated:YES];
			
			return;
		}
	}
	else
	{
		if (viewObjectsS.isCellEnabled && indexPath.row != self.listOfSongs.count)
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
			
			// Add the songs to the playlist 
			NSMutableArray *songIds = [[NSMutableArray alloc] init];
			for (ISMSSong *aSong in self.listOfSongs)
			{
				@autoreleasepool {
				
					[aSong addToCurrentPlaylistDbQueue];
					
					// In jukebox mode, collect the song ids to send to the server
					if (settingsS.isJukeboxEnabled)
						[songIds addObject:aSong.songId];
				
				}
			}
			
			// If jukebox mode, send song ids to server
			if (settingsS.isJukeboxEnabled)
			{
				[jukeboxS jukeboxStop];
				[jukeboxS jukeboxClearPlaylist];
				[jukeboxS jukeboxAddSongs:songIds];
			}
			
			// Set player defaults
			playlistS.isShuffle = NO;
			
            [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
            
			// Start the song
			ISMSSong *playedSong = [musicS playSongAtPosition:indexPath.row];
			if (!playedSong.isVideo)
                [self showPlayer];
			
			return;
		}
	}
	
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.searchType == ISMSSearchSongsSearchType_Artists) {
        if (viewObjectsS.isCellEnabled && indexPath.row != self.listOfArtists.count) {
            return [SwipeAction downloadAndQueueConfigWithModel:[self.listOfArtists objectAtIndexSafe:indexPath.row]];
        }
    } else if (self.searchType == ISMSSearchSongsSearchType_Albums) {
        if (viewObjectsS.isCellEnabled && indexPath.row != self.listOfAlbums.count) {
            return [SwipeAction downloadAndQueueConfigWithModel:[self.listOfAlbums objectAtIndexSafe:indexPath.row]];
        }
    } else {
        if (viewObjectsS.isCellEnabled && indexPath.row != self.listOfSongs.count) {
            return [SwipeAction downloadAndQueueConfigWithModel:[self.listOfSongs objectAtIndexSafe:indexPath.row]];
        }
    }
    return nil;
}


#pragma mark -
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
	// Inform the user that the connection failed.
	NSString *message = [NSString stringWithFormat:@"There was an error completing the search.\n\nError:%@", error.localizedDescription];

	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	
    self.connection = nil;

	self.isLoading = NO;
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	//DLog(@"%@", [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding]);
	
	NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:self.receivedData];
	SearchXMLParser *parser = [[SearchXMLParser alloc] initXMLParser];
	[xmlParser setDelegate:parser];
	[xmlParser parse];
	
	//DLog(@"parser.listOfSongs:\n%@", parser.listOfSongs);
	
	if (self.searchType == ISMSSearchSongsSearchType_Artists)
	{
		if ([parser.listOfArtists count] == 0)
		{
			self.isMoreResults = NO;
		}
		else 
		{
			[self.listOfArtists addObjectsFromArray:parser.listOfArtists];
		}
	}
	else if (self.searchType == ISMSSearchSongsSearchType_Albums)
	{
		if ([parser.listOfAlbums count] == 0)
		{
			self.isMoreResults = NO;
		}
		else 
		{
			[self.listOfAlbums addObjectsFromArray:parser.listOfAlbums];
		}
	}
	else if (self.searchType == ISMSSearchSongsSearchType_Songs)
	{
		if ([parser.listOfSongs count] == 0)
		{
			self.isMoreResults = NO;
		}
		else 
		{
			[self.listOfSongs addObjectsFromArray:parser.listOfSongs];
		}
	}
	
	// Reload the table
	[self.tableView reloadData];
	self.isLoading = NO;
	
	self.receivedData = nil;
	self.connection = nil;
}

@end

