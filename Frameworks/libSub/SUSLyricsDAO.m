//
//  SUSLyricsDAO.m
//  iSub
//
//  Created by Benjamin Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLyricsDAO.h"

#import "SUSLyricsLoader.h"
#import <QuartzCore/QuartzCore.h>

@implementation SUSLyricsDAO

- (id)initWithDelegate:(NSObject <ISMSLoaderDelegate> *)theDelegate
{
    if ((self = [super init]))
    {
        _delegate = theDelegate;
    }
    return self;
}

- (void)dealloc
{
	[_loader cancelLoad];
	_loader.delegate = nil;
}

- (FMDatabaseQueue *)dbQueue
{
	return databaseS.lyricsDbQueue;
}

#pragma mark - Public DAO Methods

- (NSString *)lyricsForArtist:(NSString *)artist andTitle:(NSString *)title
{	
    return [self.dbQueue stringForQuery:@"SELECT lyrics FROM lyrics WHERE artist = ? AND title = ?", artist, title];
}

- (NSString *)loadLyricsForArtist:(NSString *)artist andTitle:(NSString *)title
{
	[self cancelLoad];

    NSString *lyrics = [self lyricsForArtist:artist andTitle:title];
	if (lyrics)
	{
		return lyrics;
	}
    else if (settingsS.isLyricsEnabled) 
    {
		self.loader = [[SUSLyricsLoader alloc] initWithDelegate:self];
        self.loader.artist = artist;
        self.loader.title = title;
        [self.loader startLoad];
    }
	else
	{
		return @"No lyrics saved for this song";
	}
    
    return nil;
}

#pragma mark - ISMSLoader manager

- (void)startLoad
{
//DLog(@"this shouldn't be called");
}

- (void)cancelLoad
{
	[self.loader cancelLoad];
	self.loader.delegate = nil;
	self.loader = nil;
}

#pragma mark - ISMSLoader delegate

- (void)loadingFailed:(ISMSLoader*)theLoader withError:(NSError *)error
{
	self.loader.delegate = nil;
	self.loader = nil;
	
	if ([self.delegate respondsToSelector:@selector(loadingFailed:withError:)])
	{
		[self.delegate loadingFailed:nil withError:error];
	}
}

- (void)loadingFinished:(ISMSLoader*)theLoader
{
	self.loader.delegate = nil;
	self.loader = nil;
	
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[self.delegate loadingFinished:nil];
	}
}

@end
