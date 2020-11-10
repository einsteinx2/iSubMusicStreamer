//
//  StackScrollViewController.h
//  StackScrollView
//
//  Created by Reefaq Mohammed Mac Pro on 5/10/11.
//  Copyright 2011 raw engineering. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum
{
	StackScrollViewDragNone,
	StackScrollViewDragLeft,
	StackScrollViewDragRight
} StackScrollViewScrollDirection;

@interface StackScrollViewController :  UIViewController <UIScrollViewDelegate, UIGestureRecognizerDelegate> 

@property (nonatomic) BOOL isSlidingEnabled;

@property (nonatomic, strong) UIView *slideViews;
@property (nonatomic, strong) UIView* borderViews;

@property (nonatomic, strong) UIView* viewAtLeft;
@property (nonatomic, strong) UIView* viewAtRight;
@property (nonatomic, strong) UIView* viewAtLeft2;
@property (nonatomic, strong) UIView* viewAtRight2;	
@property (nonatomic, strong) UIView* viewAtRightAtTouchBegan;
@property (nonatomic, strong) UIView* viewAtLeftAtTouchBegan;

@property (nonatomic, strong) NSMutableArray* viewControllersStack;

@property (nonatomic) StackScrollViewScrollDirection dragDirection;

@property (nonatomic) CGFloat viewXPosition;		
@property (nonatomic) CGFloat displacementPosition;
@property (nonatomic) CGFloat lastTouchPoint;
@property (nonatomic) CGFloat slideStartPosition;

@property (nonatomic) CGPoint positionOfViewAtRightAtTouchBegan;
@property (nonatomic) CGPoint positionOfViewAtLeftAtTouchBegan;

- (void)addViewInSlider:(UIViewController*)controller;
- (void)addViewInSlider:(UIViewController*)controller invokeByController:(UIViewController*)invokeByController isStackStartView:(BOOL)isStackStartView;
- (void)bounceBack:(NSString*)animationID finished:(NSNumber*)finished context:(void*)context;

@end
