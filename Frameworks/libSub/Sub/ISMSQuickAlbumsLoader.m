//
//  ISMSQuickAlbumsLoader.m
//  libSub
//
//  Created by Justin Hill on 1/31/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "ISMSQuickAlbumsLoader.h"

@implementation ISMSQuickAlbumsLoader

- (ISMSLoaderType)type
{
    return ISMSLoaderType_QuickAlbums;
}

+ (id)loaderWithDelegate:(NSObject<ISMSLoaderDelegate> *)theDelegate
{
	if ([settingsS.serverType isEqualToString:SUBSONIC] || [settingsS.serverType isEqualToString:UBUNTU_ONE])
	{
		return [[SUSQuickAlbumsLoader alloc] initWithDelegate:theDelegate];
	}
	else if ([settingsS.serverType isEqualToString:WAVEBOX])
	{
		return [[WBQuickAlbumsLoader alloc] initWithDelegate:theDelegate];
	}
	return nil;
}

+ (id)loaderWithCallbackBlock:(LoaderCallback)theBlock
{
	if ([settingsS.serverType isEqualToString:SUBSONIC] || [settingsS.serverType isEqualToString:UBUNTU_ONE])
	{
		return [[SUSQuickAlbumsLoader alloc] initWithCallbackBlock:theBlock];
	}
	else if ([settingsS.serverType isEqualToString:WAVEBOX])
	{
		return [[WBQuickAlbumsLoader alloc] initWithCallbackBlock:theBlock];
	}
	return nil;
}

@end
