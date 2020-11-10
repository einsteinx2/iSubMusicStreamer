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
    return [[SUSStatusLoader alloc] initWithDelegate:theDelegate];
}

+ (id)loaderWithCallbackBlock:(LoaderCallback)theBlock
{
    return [[SUSStatusLoader alloc] initWithCallbackBlock:theBlock];
}

@end
