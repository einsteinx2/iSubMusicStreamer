//
//  CustomUIScrollView.m
//  iSub
//
//  Created by Ben Baron on 4/6/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "PagingScrollView.h"
#import "EqualizerViewController.h"

@implementation PagingScrollView

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        self.pagingEnabled = YES;
        self.bounces = YES;
    }
    return self;
}

- (void)setContentOffset:(CGPoint)offset
{
    CGRect frame = [self frame];
    CGSize contentSize = [self contentSize];
    CGPoint contentOffset = [self contentOffset];
	
    // Clamp the offset.
    if (offset.x <= 0)
        offset.x = 0;
    else if (offset.x > contentSize.width - frame.size.width)
        offset.x = contentSize.width - frame.size.width;
	
    if (offset.y <= 0)
        offset.y = 0;
    else if (offset.y > contentSize.height - frame.size.height)
        offset.y = contentSize.height - frame.size.height;
	
    // Update only if necessary 
    if (offset.x != contentOffset.x || offset.y != contentOffset.y)
    {
        [super setContentOffset:offset];
    }
}


@end