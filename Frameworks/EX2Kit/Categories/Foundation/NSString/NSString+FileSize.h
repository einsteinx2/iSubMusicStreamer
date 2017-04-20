//
//  NSString+FileSize.h
//  EX2Kit
//
//  Created by Ben Baron on 2/7/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (FileSize)

+ (NSString *)formatFileSize:(unsigned long long)size;
- (unsigned long long)fileSizeFromFormat;

@end
