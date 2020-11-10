//
//  PageControlViewController.h
//  iSub
//
//  Created by Ben Baron on 4/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@class PagingScrollView;
@interface PageControlViewController : UIViewController <UIScrollViewDelegate>

@property (strong) IBOutlet UIScrollView *scrollView;
@property (strong) IBOutlet UIPageControl *pageControl;
@property (strong) IBOutlet UIView *pageControlHolder;
@property (strong) NSMutableArray *viewControllers;
@property NSUInteger numberOfPages;
@property BOOL pageControlUsed;

@property (strong) UISwipeGestureRecognizer *swipeDetector;


- (IBAction)changePage:(id)sender;
- (void)hideSongInfo;
- (void)resetScrollView;

@end
