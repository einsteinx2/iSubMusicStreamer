//
//  ISMSStatusLoader.m
//  iSub
//
//  Created by Ben Baron on 8/22/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "ISMSStatusLoader.h"

@implementation ISMSStatusLoader

- (ISMSLoaderType)type
{
    return ISMSLoaderType_Status;
}

+ (id)loaderWithDelegate:(NSObject<ISMSLoaderDelegate> *)theDelegate
{
	if ([settingsS.serverType isEqualToString:SUBSONIC] || [settingsS.serverType isEqualToString:UBUNTU_ONE])
	{
		return [[SUSStatusLoader alloc] initWithDelegate:theDelegate];
	}
	else if ([settingsS.serverType isEqualToString:WAVEBOX])
	{
		return [[PMSStatusLoader alloc] initWithDelegate:theDelegate];
	}
	return nil;
}

+ (id)loaderWithCallbackBlock:(LoaderCallback)theBlock
{
	if ([settingsS.serverType isEqualToString:SUBSONIC] || [settingsS.serverType isEqualToString:UBUNTU_ONE])
	{
		return [[SUSStatusLoader alloc] initWithCallbackBlock:theBlock];
	}
	else if ([settingsS.serverType isEqualToString:WAVEBOX])
	{
		return [[PMSStatusLoader alloc] initWithCallbackBlock:theBlock];
	}
	return nil;
}

@end
