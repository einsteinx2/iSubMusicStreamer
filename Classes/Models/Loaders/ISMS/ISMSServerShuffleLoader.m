//
//  ISMSServerShuffleLoader.m
//  libSub
//
//  Created by Justin Hill on 2/6/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "ISMSServerShuffleLoader.h"

@implementation ISMSServerShuffleLoader

+ (id)loaderWithDelegate:(NSObject<ISMSLoaderDelegate> *)theDelegate
{
    return [[SUSServerShuffleLoader alloc] initWithDelegate:theDelegate];
}

+ (id)loaderWithCallbackBlock:(LoaderCallback)theBlock
{
    return [[SUSServerShuffleLoader alloc] initWithCallbackBlock:theBlock];
}

@end
