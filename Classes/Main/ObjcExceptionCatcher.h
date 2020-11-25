//
//  ObjcExceptionCatcher.h
//  iSub
//
//  Created by Benjamin Baron on 11/25/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

// Example based on answers in: https://stackoverflow.com/questions/35119531/catch-objective-c-exception-in-swift

#ifndef ObjcExceptionCatcher_h
#define ObjcExceptionCatcher_h

#import <Foundation/Foundation.h>

NS_INLINE NSException * _Nullable objcTryBlock(void(NS_NOESCAPE^_Nonnull tryBlock)(void)) {
    @try {
        tryBlock();
    }
    @catch (NSException *exception) {
        return exception;
    }
    return nil;
}

#endif /* ObjcExceptionCatcher_h */
