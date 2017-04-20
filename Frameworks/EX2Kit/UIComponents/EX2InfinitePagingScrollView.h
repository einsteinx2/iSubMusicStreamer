//
//  EX2InfinitePagingScrollView.h
//  EX2Kit
//
//  Created by Benjamin Baron on 4/23/13.
//  Copyright (c) 2013 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EX2LargerTouchScrollView.h"

@class  EX2InfinitePagingScrollView;

typedef enum
{
    EX2AutoScrollDirection_None,
    EX2AutoScrollDirection_Left,
    EX2AutoScrollDirection_Right
} EX2AutoScrollDirection;

typedef UIView * (^EX2InfinitePagingScrollViewPageBlock)(EX2InfinitePagingScrollView *scrollView, NSInteger index);

@protocol EX2InfinitePagingScrollViewDelegate <NSObject>

@required
- (UIView *)infinitePagingScrollView:(EX2InfinitePagingScrollView *)scrollView pageForIndex:(NSInteger)index;

@optional
- (void)infinitePagingScrollViewWillBeginDragging:(EX2InfinitePagingScrollView *)scrollView;
- (void)infinitePagingScrollViewDidChangePages:(EX2InfinitePagingScrollView *)scrollView;
- (void)infinitePagingScrollViewDidEndDecelerating:(EX2InfinitePagingScrollView *)scrollView;

@end

@interface EX2InfinitePagingScrollView : EX2LargerTouchScrollView <UIScrollViewDelegate>

@property (nonatomic, weak) id<EX2InfinitePagingScrollViewDelegate> pagingDelegate;

// Optional block to be used instead of the delegate to create pages
@property (nonatomic, copy) EX2InfinitePagingScrollViewPageBlock createPageBlock;

// Keyed on NSNumber of index, works like sparse array
@property (nonatomic, strong) NSMutableDictionary *pageViews;

@property (nonatomic) NSInteger currentPageIndex;
@property (nonatomic) NSUInteger numberOfPages;
@property (nonatomic) BOOL isWrapLeft;
@property (nonatomic) BOOL isWrapRight;

@property (nonatomic) EX2AutoScrollDirection autoScrollDirection;
@property (nonatomic) NSTimeInterval autoScrollInterval;

- (void)clearAllPages;
- (void)setupPages;

- (void)scrollToPageIndexAnimated:(NSInteger)index;
- (void)scrollToPrevPageAnimated;
- (void)scrollToNextPageAnimated;

- (void)startAutoScrolling;
- (void)stopAutoScrolling;

@end
