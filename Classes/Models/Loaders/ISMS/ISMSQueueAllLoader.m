//
//  QueueAll.m
//  iSub
//
//  Created by Ben Baron on 1/16/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "ISMSQueueAllLoader.h"
#import "ISMSStreamManager.h"
#import "PlaylistSingleton.h"

@implementation ISMSQueueAllLoader

+ (id)loader
{
	if ([settingsS.serverType isEqualToString:SUBSONIC])
	{
		return [[SUSQueueAllLoader alloc] init];
	}
	return nil;
}

- (void)loadAlbumFolder
{		
	assert(0 && "ISMSQueueAllLoader - Must subclass");
}

- (void)startLoad
{
    //DLog(@"must use loadData:artist:");
}

- (void)cancelLoad
{
    //DLog(@"cancelLoad called");
	self.isCancelled = YES;
	[super cancelLoad];
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_HideLoadingScreen];
}

- (void)finishLoad
{	
	if (self.isCancelled)
		return;
	
	// Continue the iteration
	if (self.folderIds.count > 0)
	{
		[self loadAlbumFolder];
	}
	else 
	{
		if (self.isShuffleButton)
		{
			// Perform the shuffle
			if (settingsS.isJukeboxEnabled)
				[jukeboxS jukeboxClearRemotePlaylist];
			
			[databaseS shufflePlaylist];
			
			if (settingsS.isJukeboxEnabled)
				[jukeboxS jukeboxReplacePlaylistWithLocal];
		}
		
		if (self.isQueue)
		{
			if (settingsS.isJukeboxEnabled)
			{
				//[jukeboxS jukeboxReplacePlaylistWithLocal];
			}
			else
			{
				[streamManagerS fillStreamQueue:audioEngineS.player.isStarted];
			}
		}
		
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_HideLoadingScreen];
		
		if (self.doShowPlayer)
		{
			[musicS showPlayer];
		}
	}
}

- (void)loadData:(NSString *)folderId artist:(ISMSArtist *)theArtist //isQueue:(BOOL)queue 
{	
	self.folderIds = [NSMutableArray arrayWithCapacity:0];
	self.listOfSongs = [NSMutableArray arrayWithCapacity:0];
	self.listOfAlbums = [NSMutableArray arrayWithCapacity:0];
	
	self.isCancelled = NO;
	
	[self.folderIds addObject:folderId];
	self.myArtist = theArtist;
	
	//jukeboxSongIds = [[NSMutableArray alloc] init];
	
	if (settingsS.isJukeboxEnabled)
	{
		self.currentPlaylist = @"jukeboxCurrentPlaylist";
		self.shufflePlaylist = @"jukeboxShufflePlaylist";
	}
	else
	{
		self.currentPlaylist = @"currentPlaylist";
		self.shufflePlaylist = @"shufflePlaylist";
	}
	
	[self loadAlbumFolder];
}

- (void)queueData:(NSString *)folderId artist:(ISMSArtist *)theArtist
{
	self.isQueue = YES;
	self.isShuffleButton = NO;
	self.doShowPlayer = NO;
	[self loadData:folderId artist:theArtist];
}

- (void)cacheData:(NSString *)folderId artist:(ISMSArtist *)theArtist
{
	self.isQueue = NO;
	self.isShuffleButton = NO;
	self.doShowPlayer = NO;
	[self loadData:folderId artist:theArtist];
}

- (void)playAllData:(NSString *)folderId artist:(ISMSArtist *)theArtist
{
	self.isQueue = YES;
	self.isShuffleButton = NO;
	self.doShowPlayer = YES;
	[self loadData:folderId artist:theArtist];
}

- (void)shuffleData:(NSString *)folderId artist:(ISMSArtist *)theArtist
{
	self.isQueue = YES;
	self.isShuffleButton = YES;
	self.doShowPlayer = YES;
	[self loadData:folderId artist:theArtist];
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
#ifdef IOS
	// Inform the user that the connection failed.
	NSString *message = [NSString stringWithFormat:@"There was an error loading the album.\n\nError %ld: %@", (long)[error code], [error localizedDescription]];
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
#endif
    
	self.receivedData = nil;
	self.connection = nil;
	
	// Remove the processed folder from array
	if (self.folderIds.count > 0)
		[self.folderIds removeObjectAtIndex:0];
	
	// Continue the iteration
	[self finishLoad];
	
//DLog(@"QueueAll CONNECTION FAILED!!!");
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{		
	// Parse the data
	[self process];
	
	// Add the songs
	for (ISMSSong *aSong in self.listOfSongs)
	{
		if (self.isQueue)
		{
			[aSong addToCurrentPlaylistDbQueue];
		}
		else
		{
			[aSong addToCacheQueueDbQueue];
		}
	}
	[self.listOfSongs removeAllObjects];
	
	// Remove the processed folder from array
	if (self.folderIds.count > 0)
		[self.folderIds removeObjectAtIndex:0];
	
	for (NSInteger i = self.listOfAlbums.count - 1; i >= 0; i--)
	{
		NSString *albumId = [[self.listOfAlbums objectAtIndexSafe:i] albumId];
		[self.folderIds insertObject:albumId atIndex:0];
	}
	[self.listOfAlbums removeAllObjects];
//DLog(@"folderIds: %@", folderIds);
	
	self.receivedData = nil;
	self.connection = nil;
	
	// Continue the iteration
	//[self performSelector:@selector(finishLoad) withObject:nil afterDelay:0.05];
	if (self.isQueue)
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	
	[self finishLoad];
}

- (void)process
{
	assert(0 && "ISMSQueueAllLoader: must subclass");
}

@end
