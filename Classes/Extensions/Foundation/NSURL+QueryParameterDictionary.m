//
//  NSURL+QueryParameterDictionary.m
//  EX2Kit
//
//  Created by Benjamin Baron on 10/29/12.
//
//

#import "NSURL+QueryParameterDictionary.h"
#import "NSArray+Safe.h"

@implementation NSURL (QueryParameterDictionary)

// Thanks to this SO answer: http://stackoverflow.com/a/11679248/299262
- (NSDictionary *)queryParameterDictionary {
    NSString *string =  [[self.absoluteString stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByRemovingPercentEncoding];
    NSScanner *scanner = [NSScanner scannerWithString:string];
    [scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@"&?"]];
    
    NSString *temp;
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [scanner scanUpToString:@"?" intoString:nil];       //ignore the beginning of the string and skip to the vars
    while ([scanner scanUpToString:@"&" intoString:&temp]) {
        NSArray *parts = [temp componentsSeparatedByString:@"="];
        if (parts.count == 2) {
            [dict setObject:[parts objectAtIndexSafe:1] forKey:[parts objectAtIndexSafe:0]];
        }
    }
    
    return dict;
}

@end
