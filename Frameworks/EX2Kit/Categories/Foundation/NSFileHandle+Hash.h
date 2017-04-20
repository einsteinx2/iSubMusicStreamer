//
//  NSFileHandle+Hash.h
//  EX2Kit
//
//  Created by Benjamin Baron on 3/29/13.
//
//

#import <Foundation/Foundation.h>

@interface NSFileHandle (Hash)

- (NSString *)sha1;
- (NSString *)md5;

@end
