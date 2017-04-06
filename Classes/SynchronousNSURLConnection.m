//
//  SynchronousNSURLConnection.m
//  iSub
//
//  Created by bbaron on 11/6/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SynchronousNSURLConnection.h"


@implementation SynchronousNSURLConnection

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
	{
		return YES; // Self-signed cert will be accepted
		// Note: it doesn't seem to matter what you return for a proper SSL cert, only self-signed certs
	}
	// If no other authentication is required, return NO for everything else
	// Otherwise maybe YES for NSURLAuthenticationMethodDefault and etc.
	return NO;
}


- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    if (data == nil)
        data = [[NSMutableData alloc] initWithCapacity:2048];
	
    [data appendData:incrementalData];
}


- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	NSLog(@"Connection to album art failed");
	if([songAtTimeOfLoad.songId isEqualToString:musicControls.currentSongObject.songId])
	{
		self.image = [UIImage imageNamed:@"default-album-art.png"];
	}
	
	[songAtTimeOfLoad release], songAtTimeOfLoad = nil;
	[data release], data = nil;
	[connection release], connection = nil;
}	


- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	/*
	 //Resize image to fit in frame
	 CGSize frameSize = CGSizeMake(320, 320);
	 UIGraphicsBeginImageContext(frameSize);// a CGSize that has the size you want
	 [[UIImage imageWithData:data] drawInRect:CGRectMake(0,0,frameSize.width,frameSize.height)];
	 appDelegate.currentCoverArt = UIGraphicsGetImageFromCurrentImageContext();
	 UIGraphicsEndImageContext();*/
	
	if([songAtTimeOfLoad.songId isEqualToString:musicControls.currentSongObject.songId])
	{
		// Check to see if the data is a valid image. If so, use it; if not, use the default image.
		if([UIImage imageWithData:data])
		{
			[databaseControls.coverArtCacheDb320 executeUpdate:@"INSERT OR REPLACE INTO coverArtCache (id, data) VALUES (?, ?)", [NSString md5:songAtTimeOfLoad.coverArtId], data];
			
			if (appDelegate.isHighRez)
			{
				UIGraphicsBeginImageContextWithOptions(CGSizeMake(320.0,320.0), NO, 2.0);
				[[UIImage imageWithData:data] drawInRect:CGRectMake(0,0,320,320)];
				self.image = UIGraphicsGetImageFromCurrentImageContext();
				UIGraphicsEndImageContext();
			}
			else
			{
				self.image = [UIImage imageWithData:data];
			}
		}
		else 
		{
			self.image = [UIImage imageNamed:@"default-album-art.png"];
		}
	}
	
	[songAtTimeOfLoad release], songAtTimeOfLoad = nil;
	[data release], data = nil;
	[connection release], connection = nil;
}

@end
