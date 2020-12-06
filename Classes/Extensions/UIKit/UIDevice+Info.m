//
//  UIDevice+Info.m
//  iSub
//
//  Created by Benjamin Baron on 12/6/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "UIDevice+Info.h"
#import "UIApplication+Helper.h"
#import <sys/sysctl.h>

@implementation UIDevice (Info)

+ (BOOL)isPad {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

+ (BOOL)isSmall {
    // Should match iPhone SE 2nd Edition and iPhone 6/7/8 (all phones with home buttons)
    CGSize screenSize = UIScreen.mainScreen.bounds.size;
    return (UIInterfaceOrientationIsPortrait(UIApplication.orientation) ? screenSize.height : screenSize.width) < 700;
}

+ (NSString *)platform {
    // Get size
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    
    // Get value
    char *value = malloc(size);
    sysctlbyname("hw.machine", value, &size, NULL, 0);
    NSString *platform = [NSString stringWithCString:value encoding: NSUTF8StringEncoding];
    free(value);
    return platform;
}

+ (NSString *)systemBuild {
    int mib[2] = { CTL_KERN, KERN_OSVERSION };
    
    // Get size
    size_t size = 0;
    sysctl(mib, 2, NULL, &size, NULL, 0);
    
    // Get value
    char *value = malloc(size);
    sysctl(mib, 2, value, &size, NULL, 0);
    NSString *systemBuild = [NSString stringWithCString:value encoding: NSUTF8StringEncoding];
    free(value);
    return systemBuild;
}

+ (NSString *)completeVersionString {
    return [NSString stringWithFormat:@"%@ %@ (%@)", UIDevice.currentDevice.systemName, UIDevice.currentDevice.systemVersion, self.systemBuild];
}

@end
