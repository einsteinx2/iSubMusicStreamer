//
//  WBDatabaseLoader.m
//  libSub
//
//  Created by Justin Hill on 1/26/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//


#import "WBDatabaseLoader.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"

@implementation WBDatabaseLoader

- (id)initWithCallbackBlock:(LoaderCallback)theBlock serverUuid:(NSString *)serverUuid
{
    self = [super initWithCallbackBlock:theBlock];
    self.uuid = serverUuid;
    
    return self;
}

- (NSURLRequest *)createRequest
{
    return [NSMutableURLRequest requestWithPMSAction:@"database"];
}

- (void)processResponse
{
    __autoreleasing NSError *err;
    
    NSString *dbFolderPath = [databaseS.databaseFolderPath stringByAppendingPathComponent:@"mediadbs"];
    NSString *dbPath = [dbFolderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.db", self.uuid]];
    
    NSString *lqid = [(NSHTTPURLResponse *)self.response allHeaderFields][@"WaveBox-LastQueryId"];
    self.lastQueryId = lqid;

    ALog(@"%@", [[(NSHTTPURLResponse *)self.response allHeaderFields][@"WaveBox-LastQueryId"] class]);
    ALog(@"%@", settingsS.lastQueryId);
    ALog(@"%@", dbPath);
    ALog(@"%@", err);

    if(![[NSFileManager defaultManager] fileExistsAtPath:dbFolderPath])
    {
        ALog(@"Attempting to create mediadbs directory");
        [[NSFileManager defaultManager] createDirectoryAtPath:dbFolderPath withIntermediateDirectories:YES attributes:nil error:&err];
    }
    
    if([self.receivedData writeToFile:dbPath atomically:YES])
    {
        ALog(@"Database file written to disk successfully");
    }
    else
    {
        [self informDelegateLoadingFailed:[[NSError alloc] initWithDomain:@"Unable to write database to disk" code:1 userInfo:nil]];
         return;
    }
    
    // Notify the delegate that the loading is finished
    [self informDelegateLoadingFinished];
}

@end
