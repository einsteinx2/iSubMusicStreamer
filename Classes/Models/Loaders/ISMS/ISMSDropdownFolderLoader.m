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
    return [[SUSDropdownFolderLoader alloc] initWithDelegate:theDelegate];
}

+ (id)loaderWithCallbackBlock:(LoaderCallback)theBlock
{
    return [[SUSDropdownFolderLoader alloc] initWithCallbackBlock:theBlock];
}


@end
