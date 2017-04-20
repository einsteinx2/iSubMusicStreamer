//
//  EX2Language.h
//  LocalizationTest
//
//  Created by Benjamin Baron on 1/31/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#define EX2LocalizedString(key, alt) [EX2Language get:key alter:@""]

@interface EX2Language : NSObject

+ (void)setLanguage:(NSString *)language;
+ (NSString *)get:(NSString *)key alter:(NSString *)alternate;

@end
