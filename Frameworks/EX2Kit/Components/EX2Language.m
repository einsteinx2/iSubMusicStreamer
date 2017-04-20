//
//  EX2Language.m
//  LocalizationTest
//
//  Created by Benjamin Baron on 1/31/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "EX2Language.h"

@implementation EX2Language

static __strong NSBundle *_bundle = nil;

+ (void)initialize
{
    NSArray *languages = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"];
    NSString *current = [languages objectAtIndex:0];
    [self setLanguage:current];
}

/*
 example calls:
 [Language setLanguage:@"it"];
 [Language setLanguage:@"de"];
 */
+ (void)setLanguage:(NSString *)language
{
    [[NSUserDefaults standardUserDefaults] setObject:@[@"language"] forKey:@"AppleLanguages"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    
    NSLog(@"preferredLang: %@", language);
    NSString *path = [[NSBundle mainBundle] pathForResource:language ofType:@"lproj"];
    _bundle = [NSBundle bundleWithPath:path];
}

+ (NSString *)get:(NSString *)key alter:(NSString *)alternate
{
    return [_bundle localizedStringForKey:key value:alternate table:nil];
}

@end