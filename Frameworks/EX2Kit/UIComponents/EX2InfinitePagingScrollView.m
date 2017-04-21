//
//  EX2InfinitePagingScrollView.m
//  EX2Kit
//
//  Created by Benjamin Baron on 4/23/13.
//  Copyright (c) 2013 Ben Baron. All rights reserved.
//

#import "EX2InfinitePagingScrollView.h"

#define CENTER_OFFSET CGPointMake(self.frame.size.width * 2., 0.)

#define DEFAULT_AUTOSCROLL_INTERVAL 10.

@interface EX2InfinitePagingScrollView ()
{
    BOOL isAutoscrolling;
}
@property (nonatomic, strong) NSTimer *autoScrollTimer;
@end

@implementation EX2InfinitePagingScrollView

- (void)setup
{
    self.contentSize = CGSizeMake(self.width * 5., self.height);
    self.pagingEnabled = YES;
    self.showsHorizontalScrollIndicator = NO;
    self.showsVerticalScrollIndicator = NO;
    self.delegate = self;
    self.scrollsToTop = NO;
    
    _pageViews = [[NSMutableDictionary alloc] initWithCapacity:10];
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        [self setup];
    }
    isAutoscrolling = NO;
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [self setup];
    }
    isAutoscrolling = NO;
    return self;
}

- (void)dealloc
{
    self.delegate = nil;
}

- (void)clearAllPages
{
    // Dispose of any existing scrollView subviews
    [self.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.pageViews removeAllObjects];
}

- (void)clearInvisiblePages
{
    NSInteger index = self.currentPageIndex;
    NSArray *keys = self.pageViews.allKeys;
    for (NSNumber *key in keys)
    {
        NSInteger keyInt = key.integerValue;
        if (keyInt < index - 2 || keyInt > index + 2)
        {
            [self removePageAtIndex:keyInt];
        }
    }
}

- (void)removePageAtIndex:(NSInteger)index
{
    NSNumber *key = @(index);
    
    UIView *view = self.pageViews[key];
    [view removeFromSuperview];
    
    [self.pageViews removeObjectForKey:key];
}

- (CGPoint)centerOffset
{
    if (self.isWrapLeft && self.isWrapRight)
    {
        return CENTER_OFFSET;
    }
    else if (!self.isWrapLeft && self.currentPageIndex < 2)
    {
        return CGPointMake((self.size.width * (self.currentPageIndex + 2)) - CENTER_OFFSET.x, 0.);
    }
    else if (!self.isWrapRight && self.currentPageIndex > self.numberOfPages - 3)
    {
        return CGPointMake((self.size.width * (self.numberOfPages - self.currentPageIndex - 1)) + CENTER_OFFSET.x, 0.);
    }
    return CENTER_OFFSET;
}

- (void)setupPages
{
    // Fix content size in case we've been resized
    self.contentSize = CGSizeMake(self.width * 5., self.height);
    
    // We always scroll to the center page to start, and then load the appropriate pages on the left, center, and right
    self.contentOffset = self.centerOffset;
    
    // Load the views for the visible pages (2 pages to the left, center page, and two pages to the right)
    long start = self.currentPageIndex - 2;
    start = start < 0 && !self.isWrapLeft ? 0 : start;
    
    long end = self.currentPageIndex + 2;
    if (!self.isWrapRight)
        end = end > self.numberOfPages - 1 ? self.numberOfPages - 1 : end;
    
    if (self.numberOfPages == 1)
    {
        UIView *view = [self.pagingDelegate infinitePagingScrollView:self pageForIndex:0];
        view.frame = CGRectMake(self.centerOffset.x, 0., self.width, self.height);
        [self addSubview:view];
        self.pageViews[@(0)] = view;
    }
    else
    {
        for (long i = start; i <= end; i++)
        {
            @autoreleasepool
            {
                // Special handling for wrapping pages
                NSInteger loadIndex = i;
                if (self.isWrapRight && i > 0 && i > self.numberOfPages - 1)
                {
                    loadIndex = i - self.numberOfPages;
                }
                else if (self.isWrapLeft && loadIndex < 0)
                {
                    loadIndex = self.numberOfPages + i;
                }
                
                // First try to see if a page for this index already exists, if so we'll just move it instead of loading a new one
                NSNumber *key = @(i);
                UIView *view = self.pageViews[key];
                CGFloat x = (CGFloat)((int)self.centerOffset.x + ((int)self.frame.size.width * (i - self.currentPageIndex)));
                CGRect rect = CGRectMake(x, 0., self.width, self.height);
                
                if (view)
                {
                    // This view already exists, it just isn't in the right place
                    view.frame = rect;
                }
                else
                {
                    // This view doesn't exist yet, so load one and place it
                    if (self.createPageBlock)
                        view = self.createPageBlock(self, loadIndex);
                    else
                        view = [self.pagingDelegate infinitePagingScrollView:self pageForIndex:loadIndex];
                    if (view)
                    {
                        view.frame = rect;
                        [self addSubview:view];
                        self.pageViews[key] = view;
                    }
                }
            }
        }
    }
    
    [self clearInvisiblePages];
    
    // Ensure that the content offset is set properly in case an animation was in progress
    [self setContentOffset:self.centerOffset animated:YES];
}

- (void)setCurrentPageIndex:(NSInteger)index
{
    _currentPageIndex = index;
    [self setupPages];
}

- (void)scrollToPrevPageAnimated
{
    NSInteger index = self.currentPageIndex - 1;
    if (index < 0 && !self.isWrapLeft)
    {
        // Do nothing
        return;
    }
    
    [self scrollToPageIndexAnimated:index];
}

- (void)scrollToNextPageAnimated
{
    NSInteger index = self.currentPageIndex + 1;
    if (index >= self.numberOfPages && !self.isWrapRight)
    {
        // Do nothing
        return;
    }
    
    [self scrollToPageIndexAnimated:index];
}

- (void)scrollToPageIndexAnimated:(NSInteger)index
{
    if (index == self.currentPageIndex - 1 || index == self.currentPageIndex + 1)
    {
        CGFloat offset = index == self.currentPageIndex - 1 ? -self.width : self.width;
        [self setContentOffset:CGPointMake(self.centerOffset.x + offset, 0.) animated:YES];
    }
    else if (self.currentPageIndex != index)
    {
        // Different pages, but too far, so just set it with no animation
        self.currentPageIndex = index;
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if ([self.pagingDelegate respondsToSelector:@selector(infinitePagingScrollViewWillBeginDragging:)])
    {
        [self.pagingDelegate infinitePagingScrollViewWillBeginDragging:self];
    }
    if (self.autoScrollTimer)
        [self.autoScrollTimer invalidate];
}

- (void)scrollViewDidScroll:(UIScrollView *)sender
{
    CGFloat distanceFromCenter = self.contentOffset.x - self.centerOffset.x;
    
    // See if we need to change the index and shuffle pages
    if (fabs(distanceFromCenter) >= self.bounds.size.width)
    {
        NSInteger index = distanceFromCenter < 0 ? self.currentPageIndex-1 : self.currentPageIndex+1;
        if (index < 0 && self.isWrapLeft)
        {
            index = self.numberOfPages - 1;
        }
        else if (index >= self.numberOfPages && self.isWrapRight)
        {
            index = 0;
        }
        
        _currentPageIndex = index;
        [self setupPages];
        
        if ([self.pagingDelegate respondsToSelector:@selector(infinitePagingScrollViewDidChangePages:)])
        {
            // Run async
            [EX2Dispatch runInMainThreadAsync:^{
                [self.pagingDelegate infinitePagingScrollViewDidChangePages:self];
            }];
        }
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    // If we're auto-scrolling, restart the timer
    if (isAutoscrolling)
    {
        [self startAutoScrolling];
    }
    
    // Call the delegate
    if ([self.pagingDelegate respondsToSelector:@selector(infinitePagingScrollViewDidEndDecelerating:)])
    {
        // Run async
        [EX2Dispatch runInMainThreadAsync:^{
            [self.pagingDelegate infinitePagingScrollViewDidEndDecelerating:self];
        }];
    }
}

- (void)startAutoScrolling
{
    isAutoscrolling = YES;
    // Cancel any existing timer
    if (self.autoScrollTimer)
        [self.autoScrollTimer invalidate];
    
    // Set some defaults
    if (self.autoScrollDirection == EX2AutoScrollDirection_None)
        self.autoScrollDirection = EX2AutoScrollDirection_Right;
    if (self.autoScrollInterval == 0.)
        self.autoScrollInterval = DEFAULT_AUTOSCROLL_INTERVAL;
    
    // Choose the correct selector
    SEL selector = self.autoScrollDirection == EX2AutoScrollDirection_Right ? @selector(scrollToNextPageAnimated) : @selector(scrollToPrevPageAnimated);
    
    self.autoScrollTimer = [NSTimer scheduledTimerWithTimeInterval:self.autoScrollInterval target:self selector:selector userInfo:nil repeats:YES];
}

- (void)stopAutoScrolling
{
    isAutoscrolling = NO;
    [self.autoScrollTimer invalidate];
    self.autoScrollTimer = nil;
}

@end
