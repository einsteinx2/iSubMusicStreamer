//
//  EX2Kit.h
//  EX2Kit
//
//  Created by Ben Baron on 6/14/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#ifndef EX2Kit_EX2Kit_h
#define EX2Kit_EX2Kit_h

#import "EX2Macros.h"
#import "EX2Categories.h"
#import "EX2Static.h"
#import "EX2Components.h"

#ifdef IOS
#import "EX2UIComponents.h"
#endif

#import "CocoaLumberjack.h"

@interface EX2Kit : NSObject

+ (NSBundle *)resourceBundle;

@end

#endif
