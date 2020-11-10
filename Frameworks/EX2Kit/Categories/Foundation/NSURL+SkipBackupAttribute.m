//
//  NSURL+SkipBackupAttribute.m
//  EX2Kit
//
//  Created by Benjamin Baron on 11/21/12.
//
//

#import "NSURL+SkipBackupAttribute.h"
#import "DDLog.h"
#import "EX2Macros.h"
#import <sys/xattr.h>

static const int ddLogLevel = LOG_LEVEL_ERROR;

@implementation NSURL (SkipBackupAttribute)

- (BOOL)addOrRemoveSkipAttribute:(BOOL)isAdd
{
    // Must be at least iOS 5.0.1 and this URL must point to a file
    if (SYSTEM_VERSION_LESS_THAN(@"5.0.1") || ![[NSFileManager defaultManager] fileExistsAtPath:self.path])
        return NO;
    
    if (SYSTEM_VERSION_EQUAL_TO(@"5.0.1"))
    {
        // Do the deprecated method
        const char* filePath = [self.path fileSystemRepresentation];
        const char* attrName = "com.apple.MobileBackup";
        u_int8_t attrValue = isAdd;
        
        int result = setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);
        return result == 0;
    }
    else
    {        
        // Do the new method
        NSError *error = nil;
        BOOL success = NO;
        
        @try
        {
            success = [self setResourceValue:@(isAdd) forKey:NSURLIsExcludedFromBackupKey error:&error];
            if(!success)
                DDLogError(@"Error excluding %@ from backup: %@", self.lastPathComponent, error);
        }
        @catch (NSException *exception)
        {
            DDLogError(@"Exception excluding %@ from backup: %@", self.lastPathComponent, exception);
        }
        
        return success;
    }
}

- (BOOL)addSkipBackupAttribute
{
    return [self addOrRemoveSkipAttribute:YES];
}

- (BOOL)removeSkipBackupAttribute
{
    return [self addOrRemoveSkipAttribute:NO];
}

@end
