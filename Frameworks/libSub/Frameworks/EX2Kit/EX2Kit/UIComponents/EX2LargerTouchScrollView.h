//
//  EX2LargerTouchScrollView.h
//  EX2Kit
//
//  Created by Benjamin Baron on 5/10/13.
//
//

#import <UIKit/UIKit.h>

@interface EX2LargerTouchScrollView : UIScrollView

// Whether or not to fill the whole touch area of it's superview
@property (nonatomic) BOOL isTouchAreaFillsSuperview;

// Optional property for specifying a padding area around this view to accept touches.
// Only active when isTouchAreaFillsSuperview = NO.
@property (nonatomic) UIEdgeInsets touchAreaPadding;

@end
