//
//  NSArray+Plist.h
//  EX2Kit
//
//  Created by Benjamin Baron on 6/19/13.
//
//

#import <Foundation/Foundation.h>

@interface NSArray (Plist)

- (BOOL)writeToPlist:(NSString *)path;
+ (id)readFromPlist:(NSString *)path;

@end
