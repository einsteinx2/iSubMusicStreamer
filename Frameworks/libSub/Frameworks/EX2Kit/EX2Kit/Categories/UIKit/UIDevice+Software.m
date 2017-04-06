//
//  UIDevice+Software.m
//  EX2Kit
//
//  Created by Ben Baron on 12/31/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "UIDevice+Software.h"
#import <sys/sysctl.h>
#import <CoreTelephony/CTCallCenter.h>
#import <CoreTelephony/CTCall.h>

@implementation UIDevice (Software)

- (NSString *)systemBuild 
{
	int mib[2] = {CTL_KERN, KERN_OSVERSION};
	size_t size = 0;
	
	// Get the size for the buffer
	sysctl(mib, 2, NULL, &size, NULL, 0);
	
	char *answer = malloc(size);
	sysctl(mib, 2, answer, &size, NULL, 0);
	
	NSString *results = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
	free(answer);
	return results;  
}

- (NSString *)completeVersionString
{
	return [NSString stringWithFormat:@"%@ %@ (%@)", [self systemName], [self systemVersion], [self systemBuild]];
}

// Soluton adapted from answers to this question: http://stackoverflow.com/questions/12342571/no-jailbreak-detection
- (BOOL)isJailbroken
{
    //If the app is running on the simulator
#if TARGET_IPHONE_SIMULATOR
    return NO;
    
    //If its running on an actual device
#else
    BOOL isJailbroken = NO;
    
    //These lines checks for the existence of Cydia
    isJailbroken = [[NSFileManager defaultManager] fileExistsAtPath:@"/Applications/Cydia.app"];
    if (!isJailbroken)
        isJailbroken = [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"cydia://"]];
    
    // This is an additional check to see if bash is accessible
    if (!isJailbroken)
        isJailbroken = [[NSFileManager defaultManager] fileExistsAtPath: @"/bin/bash"];
    
    return isJailbroken;
#endif
}

- (BOOL)isOnPhoneCall
{
    CTCallCenter *callCenter = [[CTCallCenter alloc] init];
    for (CTCall *call in callCenter.currentCalls)
    {
        if (call.callState != CTCallStateDisconnected)
            return YES;
    }
    return NO;
}

@end
