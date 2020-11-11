//
//  Index.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Index)
@interface ISMSIndex : NSObject

@property (nullable, copy) NSString *name;
@property NSUInteger position;
@property NSUInteger count;

@end

NS_ASSUME_NONNULL_END
