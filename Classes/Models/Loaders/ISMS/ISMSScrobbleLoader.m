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
    return [[SUSScrobbleLoader alloc] initWithDelegate:theDelegate];
}

+ (id)loaderWithCallbackBlock:(LoaderCallback)theBlock
{
    return [[SUSScrobbleLoader alloc] initWithCallbackBlock:theBlock];
}

@end
