//
//  UIImage+CustomStretch.h
//  EX2Kit
//
//  Created by Ben Baron on 5/26/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (CustomStretch)

- (UIImage *)resizableImageWithCapInsetsBackport:(UIEdgeInsets)capInsets;

@end
