//
//  SUSCoverArtLoader.m
//  iSub
//
//  Created by Ben Baron on 11/1/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSCoverArtLoader.h"
#import "NSMutableURLRequest+SUS.h"

@interface ISMSCoverArtLoader()
// Keep strong reference to self so we don't die until done downloading when used standalone
@property (strong) ISMSCoverArtLoader *selfRef;
@end

@implementation ISMSCoverArtLoader

static NSMutableArray *loadingImageNames;
static NSObject *syncObject;

__attribute__((constructor))
static void initialize_navigationBarImages() 
{
	loadingImageNames = [[NSMutableArray alloc] init];
	syncObject = [[NSObject alloc] init];
}

#define ISMSNotification_CoverArtFinishedInternal @"ISMS cover art finished internal notification"
#define ISMSNotification_CoverArtFailedInternal @"ISMS cover art failed internal notification"

#pragma mark - Lifecycle

- (id)initWithDelegate:(NSObject<ISMSLoaderDelegate>*)delegate coverArtId:(NSString *)artId isLarge:(BOOL)large
{
	if ((self = [super initWithDelegate:delegate]))
	{
		_isLarge = large;
		_coverArtId = [artId copy];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(coverArtDownloadFinished:) name:ISMSNotification_CoverArtFinishedInternal object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(coverArtDownloadFailed:) name:ISMSNotification_CoverArtFailedInternal object:nil];
	}
	return self;
}

- (id)initWithCallbackBlock:(LoaderCallback)theBlock coverArtId:(NSString *)artId isLarge:(BOOL)large
{
	if ((self = [super initWithCallbackBlock:theBlock]))
	{
		_isLarge = large;
		_coverArtId = [artId copy];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(coverArtDownloadFinished:) name:ISMSNotification_CoverArtFinishedInternal object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(coverArtDownloadFailed:) name:ISMSNotification_CoverArtFailedInternal object:nil];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (ISMSLoaderType)type
{
    return ISMSLoaderType_CoverArt;
}

- (void)coverArtDownloadFinished:(NSNotification *)notification
{
	if ([notification.object isKindOfClass:[NSString class]])
	{
		if ([self.coverArtId isEqualToString:notification.object])
		{
            // We can get deallocated inside informDelegateLoadingFinished, so grab the isLarge BOOL now
            BOOL large = self.isLarge;
            
			// My art download finished, so notify my delegate
			[self informDelegateLoadingFinished];
			
			if (large)
				[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_AlbumArtLargeDownloaded];
		}
	}
}

- (void)coverArtDownloadFailed:(NSNotification *)notification
{
	if ([notification.object isKindOfClass:[NSString class]])
	{
		if ([self.coverArtId isEqualToString:notification.object])
		{
			// My art download failed, so notify my delegate
			[self informDelegateLoadingFailed:nil];
		}
	}
}

#pragma mark - Private DB Methods

#pragma mark - Properties

- (FMDatabaseQueue *)dbQueue
{
	if (self.isLarge)
	{
		return IS_IPAD() ? databaseS.coverArtCacheDb540Queue : databaseS.coverArtCacheDb320Queue;
	}
	else
	{
		return databaseS.coverArtCacheDb60Queue;
	}
}

- (BOOL)isCoverArtCached
{
	return [self.dbQueue stringForQuery:@"SELECT id FROM coverArtCache WHERE id = ?", [self.coverArtId md5]] ? YES : NO;
}

#pragma mark - Data loading

- (BOOL)downloadArtIfNotExists
{
	if (self.coverArtId)
	{
		if (![self isCoverArtCached])
		{
			[self startLoad];
			return YES;
		}
	}
	return NO;
}

- (void)startLoad
{
	@synchronized(syncObject)
	{
		self.selfRef = self;
		if (self.coverArtId && !settingsS.isOfflineMode)
		{
			if (![self isCoverArtCached])
			{
				if (![loadingImageNames containsObject:self.coverArtId])
				{
					// This art is not loading, so start loading it					
					NSString *size = nil;
					if (self.isLarge)
					{
						if (IS_IPAD())
							size = SCREEN_SCALE() == 2.0 ? @"1080" : @"540";
						else
							size = SCREEN_SCALE() == 2.0 ? @"640" : @"320";
					}
					else
					{
						size = SCREEN_SCALE() == 2.0 ? @"120" : @"60";
					}
					
                    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:n2N(size), @"size", n2N(self.coverArtId), @"id", nil];
                    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getCoverArt" parameters:parameters];
					if (request)
					{
						self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
						if (self.connection)
						{
							self.receivedData = [NSMutableData data];
                            
                            [loadingImageNames addObject:self.coverArtId];
						}
						else
						{
							// Inform the delegate that the loading failed.
							NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
							[self informDelegateLoadingFailed:error];
							
							self.selfRef = nil;
						}
					}
				}
			}
		}
	}
}

- (void)cancelLoad
{
    [super cancelLoad];
    
    @synchronized(syncObject)
    {
        [loadingImageNames removeObject:self.coverArtId];
    }
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
    @synchronized(syncObject)
    {
        [loadingImageNames removeObject:self.coverArtId];
    }
    
	self.receivedData = nil;
	self.connection = nil;
	
	// Inform the delegate that loading failed
	//[self informDelegateLoadingFailed:error];
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CoverArtFinishedInternal object:[self.coverArtId copy]];
	
	self.selfRef = nil;
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{
    @synchronized(syncObject)
    {
        [loadingImageNames removeObject:self.coverArtId];
    }
    
	// Check to see if the data is a valid image. If so, use it; if not, use the default image.
#ifdef IOS
	if([UIImage imageWithData:self.receivedData])
#else
    if([[NSImage alloc] initWithData:self.receivedData])
#endif
	{
        DLog(@"art loading completed for: %@", self.coverArtId);
		[self.dbQueue inDatabase:^(FMDatabase *db)
		{
			[db executeUpdate:@"REPLACE INTO coverArtCache (id, data) VALUES (?, ?)", [self.coverArtId md5], self.receivedData];
		}];
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CoverArtFinishedInternal object:[self.coverArtId copy]];
	}
    else
    {
        DLog(@"art loading failed for: %@", self.coverArtId);
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CoverArtFinishedInternal object:[self.coverArtId copy]];
    }

	self.receivedData = nil;
	self.connection = nil;
	
	self.selfRef = nil;
}

@end
