//
//  WBDatabaseUpdateLoader.m
//  libSub
//
//  Created by Justin Hill on 2/26/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "WBDatabaseUpdateLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"

@implementation WBDatabaseUpdateLoader

- (id)initWithDelegate:(NSObject<ISMSLoaderDelegate> *)theDelegate
{
    self = [super initWithDelegate:theDelegate];
    _requestYieldedNewQueries = NO;
    return self;
}

- (id)initWithCallbackBlock:(LoaderCallback)theBlock
{
    self = [super initWithCallbackBlock:theBlock];
    _requestYieldedNewQueries = NO;
    return self;
}

- (NSURLRequest *)createRequest
{
    ALog(@"lastQueryId: %@, class: %@", settingsS.lastQueryId, [settingsS.lastQueryId class]);
    return [NSMutableURLRequest requestWithPMSAction:@"database" parameters:@{ @"id": settingsS.lastQueryId }];
}

- (void)processResponse
{
    //ALog(@"%@", [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);

    NSString *responseString = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];

    SBJsonParser *json = [[SBJsonParser alloc] init];
    NSDictionary *response = [json objectWithString:responseString];
    
    if ([response[@"queries"] count] > 0)
    {
        self.requestYieldedNewQueries = YES;
    
        [databaseS.metadataDbQueue inDatabase:^(FMDatabase *db)
        {
            NSNumber *lastId = nil;
            
            BOOL success = YES;
            [db beginTransaction];
            
            for (NSDictionary *query in response[@"queries"])
            {
                ALog(@"Executing query: %@", query[@"query"]);
                lastId = query[@"id"];
                NSArray *vals = [json objectWithString:query[@"values"]];
                if (![db executeUpdate:query[@"query"] withArgumentsInArray:vals])
                {
                    [db rollback];
                    success = NO;
                    break;
                }
            }
            
            if (success)
            {
                [db commit];
            }
        
            NSInteger lq = [lastId integerValue] + 1;
            settingsS.lastQueryId = [NSString stringWithFormat:@"%ld", (long)lq];
        }];
    }
    else
    {
        ALog(@"There aren't any new records to insert.");
    }


    [self informDelegateLoadingFinished];
}

@end
