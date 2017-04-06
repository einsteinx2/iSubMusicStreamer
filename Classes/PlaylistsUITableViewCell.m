//
//  PlaylistsUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "PlaylistsUITableViewCell.h"
#import "CellOverlay.h"

@implementation PlaylistsUITableViewCell

@synthesize receivedData, connection;
@synthesize playlistNameScrollView, playlistNameLabel;
@synthesize serverPlaylist, isDownload;

#pragma mark - Lifecycle
 
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{		
		isDownload = NO;
		receivedData = nil;
		connection = nil;
		serverPlaylist = nil;
		
		playlistNameScrollView = [[UIScrollView alloc] init];
		playlistNameScrollView.frame = CGRectMake(5, 10, 310, 44);
		playlistNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		playlistNameScrollView.showsVerticalScrollIndicator = NO;
		playlistNameScrollView.showsHorizontalScrollIndicator = NO;
		playlistNameScrollView.userInteractionEnabled = NO;
		playlistNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:playlistNameScrollView];
		
		playlistNameLabel = [[UILabel alloc] init];
		playlistNameLabel.backgroundColor = [UIColor clearColor];
		playlistNameLabel.textAlignment = NSTextAlignmentLeft; // default
		playlistNameLabel.font = ISMSBoldFont(20);
		[playlistNameScrollView addSubview:playlistNameLabel];
    }
    return self;
}


- (void)layoutSubviews 
{
    [super layoutSubviews];
	
	//self.deleteToggleImage.frame = CGRectMake(4.0, 18.5, 23.0, 23.0);
	
	// Automatically set the width based on the width of the text
	self.playlistNameLabel.frame = CGRectMake(0, 0, 290, 44);
    CGSize expectedLabelSize = [self.playlistNameLabel.text boundingRectWithSize:CGSizeMake(1000,44)
                                                                         options:NSStringDrawingUsesLineFragmentOrigin
                                                                      attributes:@{NSFontAttributeName:self.playlistNameLabel.font}
                                                                         context:nil].size;
	CGRect newFrame = self.playlistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	self.playlistNameLabel.frame = newFrame;
}

#pragma mark - Overlay

- (void)showOverlay
{
	[super showOverlay];
	
	self.overlayView.downloadButton.alpha = (float)!settingsS.isOfflineMode;
	self.overlayView.downloadButton.enabled = !settingsS.isOfflineMode;
    
    if (!settingsS.isCacheUnlocked)
    {
        self.overlayView.downloadButton.enabled = NO;
    }
}

- (void)downloadAction
{
	[viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
	
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(self.serverPlaylist.playlistId) forKey:@"id"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getPlaylist" parameters:parameters];
    
    self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
        self.isDownload = YES;
		self.receivedData = [NSMutableData dataWithCapacity:0];
	} 
	else 
	{
		// TODO: Handle error
	}
	
	self.overlayView.downloadButton.alpha = .3;
	self.overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}

- (void)queueAction
{
	[viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
	
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(self.serverPlaylist.playlistId) forKey:@"id"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getPlaylist" parameters:parameters];
    
    self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
        self.isDownload = NO;
		self.receivedData = [NSMutableData dataWithCapacity:0];
	} 
	else 
	{
		// TODO: Handle error
	}
    
	[self hideOverlay];
}

- (void)cancelLoad
{
	[self.connection cancel];
	self.connection = nil;
	self.receivedData = nil;
	[viewObjectsS hideLoadingScreen];
}

#pragma mark - Scrolling

- (void)scrollLabels
{
	if (self.playlistNameLabel.frame.size.width > self.playlistNameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:self.playlistNameLabel.frame.size.width/(float)150];
		self.playlistNameScrollView.contentOffset = CGPointMake(self.playlistNameLabel.frame.size.width - self.playlistNameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:self.playlistNameLabel.frame.size.width/(float)150];
	self.playlistNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

#pragma mark - Connection Delegate

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
	self.receivedData = nil;
	self.connection = nil;
	
	// Inform the delegate that loading failed
	[viewObjectsS hideLoadingScreen];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
    // Parse the data
    //
    RXMLElement *root = [[RXMLElement alloc] initFromXMLData:receivedData];
    if (![root isValid])
    {
        //NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
        // TODO: handle this error
    }
    else
    {
        RXMLElement *error = [root child:@"error"];
        if ([error isValid])
        {
            //NSString *code = [error attribute:@"code"];
            //NSString *message = [error attribute:@"message"];
            // TODO: handle this error
        }
        else
        {
            // TODO: Handle !isValid case
            if ([[root child:@"playlist"] isValid])
            {
                NSString *md5 = [serverPlaylist.playlistName md5];
                [databaseS removeServerPlaylistTable:md5];
                [databaseS createServerPlaylistTable:md5];
                
                [root iterate:@"playlist.entry" usingBlock:^(RXMLElement *e) {
                    ISMSSong *aSong = [[ISMSSong alloc] initWithRXMLElement:e];
                    [aSong insertIntoServerPlaylistWithPlaylistId:md5];
                    if (isDownload)
                    {
                        [aSong addToCacheQueueDbQueue];
                    }
                    else
                    {
                        [aSong addToCurrentPlaylistDbQueue];
                    }
                }];
            }
        }
    }
	
	// Hide the loading screen
	[viewObjectsS hideLoadingScreen];
	
	self.receivedData = nil;
	self.connection = nil;
	
	if (!self.isDownload)
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
}

@end
