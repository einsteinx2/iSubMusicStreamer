//
//  FMDatabaseQueueAdditions.m
//  iSub
//
//  Created by Benjamin Baron on 4/22/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "FMDatabaseQueueAdditions.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

@interface FMDatabase (PrivateStuff)
- (FMResultSet * _Nullable)executeQuery:(NSString *)sql withArgumentsInArray:(NSArray * _Nullable)arrayArgs orDictionary:(NSDictionary * _Nullable)dictionaryArgs orVAList:(va_list)args shouldBind:(BOOL)shouldBind;
@end

@implementation FMDatabaseQueue (Additions)

#define RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(type, sel)                                                            \
va_list args;                                                                                                       \
va_start(args, query);                                                                                              \
__block va_list *args_ptr = &args;                                                                                  \
__block type ret;                                                                                                   \
[self inDatabase:^(FMDatabase *db) {                                                                                \
FMResultSet *resultSet = [db executeQuery:query withArgumentsInArray:0x00 orDictionary:0x00 orVAList:*args_ptr shouldBind:true];  \
    ret = [resultSet next] ? [resultSet sel:0] : (type)0;                                                           \
    [resultSet close];                                                                                              \
    [resultSet setParentDB:nil];                                                                                    \
}];                                                                                                                 \
va_end(args);                                                                                                       \
return ret;

- (NSString*)stringForQuery:(NSString*)query, ...
{
	RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(NSString *, stringForColumnIndex);
}

- (int)intForQuery:(NSString*)query, ... 
{
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(int, intForColumnIndex);
}

- (long)longForQuery:(NSString*)query, ... 
{
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(long, longForColumnIndex);
}

- (BOOL)boolForQuery:(NSString*)query, ... 
{
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(BOOL, boolForColumnIndex);
}

- (double)doubleForQuery:(NSString*)query, ... 
{
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(double, doubleForColumnIndex);
}

- (NSData*)dataForQuery:(NSString*)query, ... 
{
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(NSData *, dataForColumnIndex);
}

- (NSDate*)dateForQuery:(NSString*)query, ... 
{
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(NSDate *, dateForColumnIndex);
}

- (BOOL)tableExists:(NSString*)tableName
{
	__block BOOL exists;
	[self inDatabase:^(FMDatabase *db) {
		exists = [db tableExists:tableName];
	}];
	return exists;
}

- (BOOL)columnExists:(NSString*)columnName inTableWithName:(NSString*)tableName
{
	__block BOOL exists;
	[self inDatabase:^(FMDatabase *db) {
        exists = [db columnExists:columnName inTableWithName:tableName];
	}];
	return exists;
}

@end

