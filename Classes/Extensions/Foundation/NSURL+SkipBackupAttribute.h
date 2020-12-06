//
//  NSURL+SkipBackupAttribute.h
//  EX2Kit
//
//  Created by Benjamin Baron on 11/21/12.
//
//

#import <UIKit/UIKit.h>

@interface NSURL (SkipBackupAttribute)

- (BOOL)addSkipBackupAttribute;
- (BOOL)removeSkipBackupAttribute;

@end
