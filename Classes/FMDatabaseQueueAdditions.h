//
//  FMDatabaseQueueAdditions.h
//  iSub
//
//  Created by Benjamin Baron on 4/22/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueue.h"

@interface FMDatabaseQueue (Additions)

- (int)intForQuery:(NSString*)query, ...;
- (long)longForQuery:(NSString*)query, ...; 
- (BOOL)boolForQuery:(NSString*)query, ...;
- (double)doubleForQuery:(NSString*)query, ...;
- (NSString*)stringForQuery:(NSString*)query, ...; 
- (NSData*)dataForQuery:(NSString*)query, ...;
- (NSDate*)dateForQuery:(NSString*)query, ...;

- (BOOL)tableExists:(NSString*)tableName;
- (BOOL)columnExists:(NSString*)tableName columnName:(NSString*)columnName;

@end
