//
//  NSObject+UserInfo.h
//  EX2Kit
//
//  Created by Benjamin Baron on 5/13/13.
//
//  Used to attach arbitrary user info to any object
//

@interface NSObject (UserInfo)

@property (nonatomic, strong) NSMutableDictionary *ex2UserInfo;

- (void)ex2SetCustomObject:(id)value forKey:(id)key;
- (id)ex2CustomObjectForKey:(id)key;

@end
