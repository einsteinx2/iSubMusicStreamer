//
//  NSString+cStringUTF8.h
//  EX2Kit
//
//  Created by Ben Baron on 11/17/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (cStringUTF8)

- (const char *)cStringUTF8;

@end
