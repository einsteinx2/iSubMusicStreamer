//
//  NSString+compareWithoutIndefiniteArticles.m
//  EX2Kit
//
//  Created by Ben Baron on 12/17/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NSString+compareWithoutIndefiniteArticles.h"

@implementation NSString (compareWithoutIndefiniteArticles)

+ (NSArray *)indefiniteArticles
{
    return @[@"the", @"los", @"las", @"les", @"el", @"la", @"le"];
}

- (NSString *)stringWithoutIndefiniteArticle
{
    for (NSString *article in [NSString indefiniteArticles])
    {
        // See if the string starts with this article, note the space after each article to reduce false positives  
        if ([self.lowercaseString hasPrefix:[NSString stringWithFormat:@"%@ ", article]])
        {
            // Make sure we don't mess with it if there's nothing after the article
            if (self.length > (article.length + 1))
            {
                // Move the article to the end after a comma
                return [NSString stringWithFormat:@"%@, %@", [self substringFromIndex:(article.length + 1)], [self substringToIndex:article.length]];
            }
        }
    }
    
    // Does not contain an article
    return [self copy];
}

- (NSComparisonResult)compareWithoutIndefiniteArticles:(NSString *)otherString
{
	return [[self stringWithoutIndefiniteArticle] compare:[otherString stringWithoutIndefiniteArticle]];
}

- (NSComparisonResult)caseInsensitiveCompareWithoutIndefiniteArticles:(NSString *)otherString
{
	return [[self stringWithoutIndefiniteArticle] caseInsensitiveCompare:[otherString stringWithoutIndefiniteArticle]];
}

@end
