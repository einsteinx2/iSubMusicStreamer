//
//  EqualizerPathView.h
//  iSub
//
//  Created by Ben Baron on 1/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EqualizerPathView : UIView
{
	CGPoint *points;
	NSUInteger length;
}

- (void)setPoints:(CGPoint *)thePoints length:(NSUInteger)theLength;

@end
