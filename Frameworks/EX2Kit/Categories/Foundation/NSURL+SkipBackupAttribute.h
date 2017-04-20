//
//  NSURL+SkipBackupAttribute.h
//  EX2Kit
//
//  Created by Benjamin Baron on 11/21/12.
//
//

#import <Foundation/Foundation.h>

@interface NSURL (SkipBackupAttribute)

- (BOOL)addSkipBackupAttribute;
- (BOOL)removeSkipBackupAttribute;

@end
