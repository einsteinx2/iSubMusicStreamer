//
//  ISMSScrobbleLoader.m
//  libSub
//
//  Created by Justin Hill on 2/8/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "ISMSScrobbleLoader.h"

@implementation ISMSScrobbleLoader

+ (id)loaderWithDelegate:(NSObject<ISMSLoaderDelegate> *)theDelegate
{
	if ([settingsS.serverType isEqualToString:SUBSONIC] || [settingsS.serverType isEqualToString:UBUNTU_ONE])
	{
		return [[SUSScrobbleLoader alloc] initWithDelegate:theDelegate];
	}
	else if ([settingsS.serverType isEqualToString:WAVEBOX])
	{
		return [[WBScrobbleLoader alloc] initWithDelegate:theDelegate];
	}
	return nil;
}

+ (id)loaderWithCallbackBlock:(LoaderCallback)theBlock
{
	if ([settingsS.serverType isEqualToString:SUBSONIC] || [settingsS.serverType isEqualToString:UBUNTU_ONE])
	{
		return [[SUSScrobbleLoader alloc] initWithCallbackBlock:theBlock];
	}
	else if ([settingsS.serverType isEqualToString:WAVEBOX])
	{
		return [[WBScrobbleLoader alloc] initWithCallbackBlock:theBlock];
	}
	return nil;
}

@end
