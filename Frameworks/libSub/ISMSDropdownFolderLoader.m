//
//  ISMSDropdownFolderLoader.m
//  libSub
//
//  Created by Justin Hill on 2/6/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "ISMSDropdownFolderLoader.h"

@implementation ISMSDropdownFolderLoader

+ (id)loaderWithDelegate:(NSObject<ISMSLoaderDelegate> *)theDelegate
{
	if ([settingsS.serverType isEqualToString:SUBSONIC] || [settingsS.serverType isEqualToString:UBUNTU_ONE])
	{
		return [[SUSDropdownFolderLoader alloc] initWithDelegate:theDelegate];
	}
	else if ([settingsS.serverType isEqualToString:WAVEBOX])
	{
		return [[WBDropdownFolderLoader alloc] initWithDelegate:theDelegate];
	}
	return nil;
}

+ (id)loaderWithCallbackBlock:(LoaderCallback)theBlock
{
	if ([settingsS.serverType isEqualToString:SUBSONIC] || [settingsS.serverType isEqualToString:UBUNTU_ONE])
	{
		return [[SUSDropdownFolderLoader alloc] initWithCallbackBlock:theBlock];
	}
	else if ([settingsS.serverType isEqualToString:WAVEBOX])
	{
		return [[WBDropdownFolderLoader alloc] initWithCallbackBlock:theBlock];
	}
	return nil;
}


@end
