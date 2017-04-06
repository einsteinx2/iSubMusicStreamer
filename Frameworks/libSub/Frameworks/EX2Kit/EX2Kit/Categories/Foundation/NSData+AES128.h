//
//  NSData-AES256.h
//  iSub
//
//  Created by Ben Baron on 3/14/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSData (AES128)

- (NSData *)AES128EncryptWithKey:(NSString *)key;
- (NSData *)AES128DecryptWithKey:(NSString *)key;

@end
