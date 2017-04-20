//
//  UIImage+CustomStretch.m
//  EX2Kit
//
//  Created by Ben Baron on 5/26/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "UIImage+CustomStretch.h"

@implementation UIImage (CustomStretch)

- (UIImage *)resizableImageWithCapInsetsBackport:(UIEdgeInsets)capInsets
{
	if ([self respondsToSelector:@selector(resizableImageWithCapInsets:)])
	{
		return [self resizableImageWithCapInsets:capInsets];
	}
	else
	{
		return [self stretchableImageWithLeftCapWidth:capInsets.left topCapHeight:capInsets.top];
	}
}

@end
