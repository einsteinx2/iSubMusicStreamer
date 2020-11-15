//
//  NSObject+UserInfo.m
//  EX2Kit
//
//  Created by Benjamin Baron on 5/13/13.
//
//

#import "NSObject+UserInfo.h"
#import <objc/runtime.h>

@implementation NSObject (UserInfo)

static void *key;

- (NSMutableDictionary *)ex2UserInfo
{
    return objc_getAssociatedObject(self, &key);
}

- (void)setEx2UserInfo:(NSMutableDictionary *)ex2UserInfo
{
     objc_setAssociatedObject(self, &key, ex2UserInfo, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)ex2SetCustomObject:(id)value forKey:(id)key
{
    if (!key) return;
    
    @synchronized(self)
    {
        if (!self.ex2UserInfo)
        {
            self.ex2UserInfo = [NSMutableDictionary dictionaryWithCapacity:0];
        }
        
        if (value)
        {
            self.ex2UserInfo[key] = value;
        }
        else
        {
            [self.ex2UserInfo removeObjectForKey:key];
        }
    }
}

- (id)ex2CustomObjectForKey:(id)key
{
    if (!key) return nil;
    
    @synchronized(self)
    {
        return self.ex2UserInfo[key];
    }
}

@end
