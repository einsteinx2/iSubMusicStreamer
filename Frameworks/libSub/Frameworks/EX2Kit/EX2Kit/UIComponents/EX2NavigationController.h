//
//  EX2NavigationController.h
//  WOD
//
//  Created by Casey Marshall on 2/3/11.
//  Copyright 2011 Modal Domains. All rights reserved.
//
//  Heavily modified for EX2Kit by Ben Baron 2012

#import <UIKit/UIKit.h>

// This class is a reimplementation of UINavigationController, reimplemented
// here so it works better when embedded in another view controller.

@class EX2NavigationController;

@interface UIViewController (EX2NavigationController)
@property (nonatomic, weak) EX2NavigationController *ex2NavigationController;
@end

@protocol EX2NavigationControllerDelegate <NSObject>
@optional
- (void)ex2NavigationController:(EX2NavigationController *)controller willShowViewController:(UIViewController *)viewController animated:(BOOL)animated;
- (void)ex2NavigationController:(EX2NavigationController *)controller didShowViewController:(UIViewController *)viewController animated:(BOOL)animated;
@end

typedef enum EX2NavigationControllerAnimation
{
	// No animation.
	EX2NavigationControllerAnimationNone    = 0,
	
	// The new view slides in from the top.
	EX2NavigationControllerAnimationTop     = 1,
	
	// The new view slides in from the bottom.
	EX2NavigationControllerAnimationBottom  = 2,
	
	// The new view slides in from the left.
	EX2NavigationControllerAnimationLeft    = 3,
	
	// The new view slides in from the right.
	EX2NavigationControllerAnimationRight   = 4,
	
	// The default animation for the transition.
	EX2NavigationControllerAnimationDefault = 5
}
EX2NavigationControllerAnimation;

@interface EX2NavigationController : UIViewController

@property (strong, nonatomic) IBOutlet UINavigationBar *navigationBar;
@property (strong, nonatomic) IBOutlet UIView *contentView;
@property (strong, nonatomic) IBOutlet id<EX2NavigationControllerDelegate> delegate;

@property (strong, nonatomic) NSMutableArray *viewControllers;

@property (nonatomic, getter=isNavigationBarHidden) BOOL navigationBarHidden;

@property (nonatomic, readonly) UIViewController *rootViewController;

- (id)initWithRootViewController:(UIViewController *)viewController;

- (void)setViewControllers:(NSArray *)vc withAnimation:(EX2NavigationControllerAnimation)animation;
- (void)setViewControllers:(NSArray *)vc animated:(BOOL)animated;

- (void)pushViewController:(UIViewController *)viewController withAnimation:(EX2NavigationControllerAnimation)animation;
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated;

- (void)popViewControllerWithAnimation:(EX2NavigationControllerAnimation)animation;
- (void)popViewControllerAnimated:(BOOL)animated;

- (void)popToRootViewControllerAnimated:(BOOL)animated;

- (BOOL)isRootViewController:(UIViewController *)viewController;

- (void)setNavigationBarHidden:(BOOL)hidden animated:(BOOL)animated;

@end
