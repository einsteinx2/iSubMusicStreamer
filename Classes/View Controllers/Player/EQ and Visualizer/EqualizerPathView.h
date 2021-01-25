//
//  EqualizerPathView.h
//  iSub
//
//  Created by Ben Baron on 1/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface EqualizerPathView : UIView {
	CGPoint *points;
	NSInteger length;
}

- (void)setPoints:(CGPoint *)thePoints length:(NSInteger)theLength;

@end
