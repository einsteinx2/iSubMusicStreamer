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
    return [[SUSQuickAlbumsLoader alloc] initWithDelegate:theDelegate];
}

+ (id)loaderWithCallbackBlock:(LoaderCallback)theBlock
{
    return [[SUSQuickAlbumsLoader alloc] initWithCallbackBlock:theBlock];
}

@end
