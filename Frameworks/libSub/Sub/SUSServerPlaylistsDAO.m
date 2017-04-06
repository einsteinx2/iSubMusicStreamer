//
//  SUSServerPlaylistDAO.m
//  iSub
//
//  Created by Benjamin Baron on 11/1/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSServerPlaylistsDAO.h"
#import "SUSServerPlaylistsLoader.h"

@implementation SUSServerPlaylistsDAO

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
    return databaseS.localPlaylistsDbQueue;
}

#pragma mark - Loader Manager Methods

- (void)restartLoad
{
    [self startLoad];
}

- (void)startLoad
{	
    self.loader = [[SUSServerPlaylistsLoader alloc] initWithDelegate:self];
    [self.loader startLoad];
}

- (void)cancelLoad
{
    [self.loader cancelLoad];
	self.loader.delegate = nil;
    self.loader = nil;
}

#pragma mark - Loader Delegate Methods

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
	self.serverPlaylists = [NSArray arrayWithArray:self.loader.serverPlaylists];
	
	self.loader.delegate = nil;
	self.loader = nil;
    
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[self.delegate loadingFinished:nil];
	}
}

@end
