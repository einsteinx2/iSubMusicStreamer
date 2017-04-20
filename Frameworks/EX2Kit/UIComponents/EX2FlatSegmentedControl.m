//
//  EX2FlatSegmentedControl.m
//  EX2Kit
//
//  Created by Benjamin Baron on 6/25/13.
//
//

#import "EX2FlatSegmentedControl.h"
#import <QuartzCore/QuartzCore.h>

#define UnselectedGradientName @"unselected"
#define SelectedGradientName @"selected"

// Custom UIView to draw 1px lines on retina displays, because setting a UIView width to .5 makes it disappear
@interface EX2FlatSegmentedControlVerticalLine : UIView
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic, strong) UIColor *lineColor;
@end
@implementation EX2FlatSegmentedControlVerticalLine

- (void)drawRect:(CGRect)rect
{
    // Draw a vertical line the height of the view
    UIBezierPath *path = [[UIBezierPath alloc] init];
    path.lineWidth = self.lineWidth;
    [path moveToPoint:CGPointMake(self.width / 2., 0.)];
    [path addLineToPoint:CGPointMake(self.width / 2., self.height)];
    
    [self.lineColor setStroke];
    [path stroke];
}

- (void)setLineWidth:(CGFloat)lineWidth
{
    _lineWidth = lineWidth;
    [self setNeedsDisplaySafe];
}

- (void)setLineColor:(UIColor *)lineColor
{
    _lineColor = lineColor;
    [self setNeedsDisplaySafe];
}

@end

@implementation EX2FlatSegmentedControl
{
    NSUInteger _selectedSegmentIndex;
    NSMutableArray *_items;
}

#pragma mark - Lifecycle

- (id)init
{
    if ((self = [super init]))
    {
        [self commonInit];
    }
    return self;
}

- (id)initWithItems:(NSArray *)items
{
    if ((self = [self init]))
    {
        [items enumerateObjectsUsingBlock:^(id title, NSUInteger idx, BOOL *stop)
         {
             [self insertSegmentWithTitle:title atIndex:idx animated:NO];
         }];
    }
    return self;
}

- (void)awakeFromNib
{
    [self commonInit];
    _selectedSegmentIndex = super.selectedSegmentIndex;
    for (NSInteger i = 0; i < super.numberOfSegments; i++)
    {
        [self insertSegmentWithTitle:[super titleForSegmentAtIndex:i] atIndex:i animated:NO];
    }
    [super removeAllSegments];
    
    [super awakeFromNib];
}

- (void)commonInit
{
    [self.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    _selectedSegmentIndex = -1;
    _items = [NSMutableArray array];
    _segmentMargin = 20.;
    _borderWidth = .5;
    
    UIColor *gray = [UIColor colorWithHexString:@"707070"];
    
    _borderColor = gray;
    _selectedBackgroundColor = gray;
    _selectedTextColor = UIColor.whiteColor;
    _unselectedTextColor = gray;
    _unselectedFont = [UIFont fontWithName:@"HelveticaNeue-Bold" size:16.];
    _selectedFont = _unselectedFont;
    
    self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    
    self.layer.borderColor = gray.CGColor;
    self.layer.borderWidth = _borderWidth;
    self.layer.cornerRadius = 5.;
    self.clipsToBounds = YES;
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    CGRect frame = self.frame;
    if (frame.size.height == 0)
    {
        frame.size.height = 40.;
        self.frame = frame;
    }
    if (frame.size.width == 0)
    {
        [self adjustSize];
    }
}

#pragma mark - Properties

- (void)setItems:(NSArray *)items
{
    [self removeAllSegments];
    [items enumerateObjectsUsingBlock:^(id title, NSUInteger idx, BOOL *stop)
     {
         [self insertSegmentWithTitle:title atIndex:idx animated:NO];
     }];
}

- (NSArray *)items
{
    NSMutableArray *itemStrings = [NSMutableArray array];
    for (UILabel *item in _items)
    {
        UILabel *label = item.subviews.firstObjectSafe;
        [itemStrings addObjectSafe:label.text];
    }
    return [NSArray arrayWithArray:itemStrings];
}

- (NSUInteger)numberOfSegments
{
    return _items.count;
}

- (void)setBorderColor:(UIColor *)borderColor
{
    _borderColor = borderColor;
    self.layer.borderColor = borderColor.CGColor;
    
    // Fix the spacer colors
    for (UIView *item in _items)
    {
        UILabel *label = item.subviews.firstObjectSafe;
        EX2FlatSegmentedControlVerticalLine *spacer = label.subviews.firstObjectSafe;
        if ([spacer isKindOfClass:[EX2FlatSegmentedControlVerticalLine class]])
        {
            spacer.lineColor = borderColor;
        }
    }
}

- (void)setSelectedBackgroundColor:(UIColor *)selectedBackgroundColor
{
    _selectedBackgroundColor = selectedBackgroundColor;
    [self highlightSelectedSegment];
}

- (void)setUnselectedBackgroundGradientStart:(UIColor *)unselectedBackgroundGradientStart
{
    _unselectedBackgroundGradientStart = unselectedBackgroundGradientStart;
    
    self.isUseGradient ? [self createGradientLayersForItems] : [self removeGradientLayersForItems];
}

- (void)setUnselectedBackgroundGradientEnd:(UIColor *)unselectedBackgroundGradientEnd
{
    _unselectedBackgroundGradientEnd = unselectedBackgroundGradientEnd;
    
    self.isUseGradient ? [self createGradientLayersForItems] : [self removeGradientLayersForItems];
}

- (void)setSelectedBackgroundGradientStart:(UIColor *)selectedBackgroundGradientStart
{
    _selectedBackgroundGradientStart = selectedBackgroundGradientStart;
    
    self.isUseGradient ? [self createGradientLayersForItems] : [self removeGradientLayersForItems];
}

- (void)setSelectedBackgroundGradientEnd:(UIColor *)selectedBackgroundGradientEnd
{
    _selectedBackgroundGradientEnd = selectedBackgroundGradientEnd;
    
    self.isUseGradient ? [self createGradientLayersForItems] : [self removeGradientLayersForItems];
}

- (void)setSelectedTextColor:(UIColor *)selectedTextColor
{
    _selectedTextColor = selectedTextColor;
    [self highlightSelectedSegment];
}

- (void)setSelectedSegmentIndex:(NSInteger)selectedSegmentIndex
{
    if (_selectedSegmentIndex != selectedSegmentIndex && selectedSegmentIndex < _items.count)
    {
        _selectedSegmentIndex = selectedSegmentIndex;
        
        [self highlightSelectedSegment];
    }
}

- (NSInteger)selectedSegmentIndex
{
    return _selectedSegmentIndex;
}

- (void)setSegmentMargin:(CGFloat)segmentMargin
{
    if (_segmentMargin != segmentMargin)
    {
        _segmentMargin = segmentMargin;
        [self adjustSize];
    }
}

- (void)setSelectedFont:(UIFont *)selectedFont
{
    if (![_selectedFont isEqual:selectedFont])
    {
        _selectedFont = selectedFont;
        [self adjustSize];
    }
}

- (void)setUnselectedFont:(UIFont *)unselectedFont
{
    if (![_unselectedFont isEqual:unselectedFont])
    {
        _unselectedFont = unselectedFont;
        [self adjustSize];
    }
}

- (void)setBorderWidth:(CGFloat)borderWidth
{
    _borderWidth = borderWidth;
    self.layer.borderWidth = _borderWidth;
    
    for (UIView *item in _items)
    {
        UILabel *label = item.subviews.firstObjectSafe;
        EX2FlatSegmentedControlVerticalLine *spacer = label.subviews.firstObjectSafe;
        if ([spacer isKindOfClass:[EX2FlatSegmentedControlVerticalLine class]])
        {
            spacer.lineWidth = borderWidth;
        }
    }
}

- (void)setStaticWidth:(CGFloat)staticWidth
{
    _staticWidth = staticWidth;
    [self adjustSize];
}

#pragma mark - Helper Methods

// Adjust size so that all segments are equally sized and fit
- (void)adjustSize
{
    if (self.items.count == 0)
    {
        self.width = 0.;
        return;
    }
    
    // Find the largest label size or use the static size
    __block CGFloat maxWidth = self.staticWidth / self.items.count;
    if (maxWidth == 0.)
    {
        for (UILabel *item in _items)
        {
            // Use the largest font for sizing
            UIFont *sizingFont = self.selectedFont;
            if (self.unselectedFont.pointSize > self.selectedFont.pointSize)
                sizingFont = self.unselectedFont;
            
            CGFloat width = [item.text sizeWithFont:sizingFont].width;
            if (width > maxWidth)
                maxWidth = width;
        }
        
        // Add the margins
        maxWidth += (self.segmentMargin * 2);
    }
    
    // Adjust all segments to match that size
    [_items enumerateObjectsUsingBlock:^(UILabel *item, NSUInteger index, BOOL *stop)
     {
         item.frame = CGRectMake(index * maxWidth, 0., maxWidth, self.height);
         
         if (self.isUseGradient)
         {
             [self adjustGradientLayerSizesForItems];
         }
     }];
    
    self.width = _items.count * maxWidth;
}

- (void)highlightSelectedSegment
{
    [_items enumerateObjectsUsingBlock:^(UILabel *item, NSUInteger index, BOOL *stop) {
        if (self.isUseGradient)
        {
            for (CALayer *layer in item.layer.sublayers)
            {
                if ([layer.name isEqualToString:SelectedGradientName])
                {
                    layer.opacity = index == self.selectedSegmentIndex ? 1. : 0.;
                }
                else if ([layer.name isEqualToString:UnselectedGradientName])
                {
                    layer.opacity = index == self.selectedSegmentIndex ? 0. : 1.;
                }
            }
        }
        else
        {
            item.backgroundColor = index == self.selectedSegmentIndex ? self.selectedBackgroundColor : UIColor.clearColor;
        }
        
        UILabel *label = item.subviews.firstObjectSafe;
        label.textColor = index == self.selectedSegmentIndex ? self.selectedTextColor : self.unselectedTextColor;
        label.font = index == self.selectedSegmentIndex ? self.selectedFont : self.unselectedFont;
    }];
}

- (UIView *)createSpacerView:(UIView *)segmentView
{
    CGRect frame = CGRectMake(segmentView.width - .5, 0., 1., self.height);
    EX2FlatSegmentedControlVerticalLine *spacerView = [[EX2FlatSegmentedControlVerticalLine alloc] initWithFrame:frame];
    spacerView.backgroundColor = UIColor.clearColor;
    spacerView.lineColor = self.borderColor;
    spacerView.lineWidth = self.borderWidth;
    spacerView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin;
    return spacerView;
}

#pragma mark - UISegmentControl Methods

- (void)insertSegmentWithImage:(UIImage *)image atIndex:(NSUInteger)segment animated:(BOOL)animated
{
    NSAssert(NO, @"insertSegmentWithImage:atIndex:animated: is not supported by EX2FlatSegmentedControl");
}

- (UIImage *)imageForSegmentAtIndex:(NSUInteger)segment
{
    NSAssert(NO, @"imageForSegmentAtIndex: is not supported by EX2FlatSegmentedControl");
    return nil;
}

- (void)setImage:(UIImage *)image forSegmentAtIndex:(NSUInteger)segment
{
    NSAssert(NO, @"setImage:forSegmentAtIndex: is not supported by EX2FlatSegmentedControl");
}

- (void)setTitle:(NSString *)title forSegmentAtIndex:(NSUInteger)segment
{ 
    if (segment < self.numberOfSegments)
    {
        // Set the title
        UIView *segmentView = _items[segment];
        UILabel *segmentLabel = segmentView.subviews.firstObjectSafe;
        if ([segmentLabel isKindOfClass:[UILabel class]])
        {
            segmentLabel.text = title;
        }
        
        // Adjust the size of the control so each items have the same width
        [self adjustSize];
    }
}

- (NSString *)titleForSegmentAtIndex:(NSUInteger)segment
{
    if (segment < self.numberOfSegments)
    {
        UIView *segmentView = _items[segment];
        UILabel *segmentLabel = segmentView.subviews.firstObjectSafe;
        if ([segmentLabel isKindOfClass:[UILabel class]])
        {
            return segmentLabel.text;
        }
    }
    
    return nil;
}

- (void)insertSegmentWithTitle:(NSString *)title atIndex:(NSUInteger)index animated:(BOOL)animated
{
    // Create the segment view
    UILabel *segmentView = [[UILabel alloc] init];
    segmentView.text = title;
    segmentView.textAlignment = UITextAlignmentCenter;
    segmentView.accessibilityLabel = segmentView.text;
    segmentView.textColor = self.unselectedTextColor;
    segmentView.font = self.unselectedFont;
    segmentView.backgroundColor = UIColor.clearColor;
    segmentView.userInteractionEnabled = YES;
    segmentView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [segmentView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSelect:)]];
    
    // Create the holder view
    UIView *holderView = [[UIView alloc] init];
    [holderView addSubview:segmentView];
    
    // Add the gradient if necessary
    if (self.isUseGradient)
    {
        [self createGradientLayersForItem:holderView];
    }
    
    // Insert it at the correct position
    index = index >= self.numberOfSegments ? self.numberOfSegments : index;
    if (index < _items.count)
    {
        // Create the spacer view
        [segmentView addSubview:[self createSpacerView:segmentView]];
        
        // Insert the segment
        [self insertSubview:holderView belowSubview:_items[index]];
        [_items insertObject:holderView atIndex:index];
    }
    else
    {
        // Create the spacer for the previous end item
        [_items.lastObject addSubview:[self createSpacerView:_items.lastObject]];
        
        // Add the segment to the end
        [self addSubview:holderView];
        [_items addObject:holderView];
    }
    
    // Adjust the selected segment index if necessary
    if (self.selectedSegmentIndex >= index && self.selectedSegmentIndex != _items.count - 1)
    {
        self.selectedSegmentIndex++;
    }
    
    // Redraw the control
    if (animated)
    {
        [UIView animateWithDuration:.4 animations:^
         {
             [self adjustSize];
         }];
    }
    else
    {
        [self adjustSize];
    }
    
    [self highlightSelectedSegment];
}

- (BOOL)isUseGradient
{
    return self.unselectedBackgroundGradientStart && self.unselectedBackgroundGradientEnd && self.selectedBackgroundGradientStart && self.selectedBackgroundGradientEnd;
}
            
- (CAGradientLayer *)createGradientLayerForItem:(UIView *)item startColor:(UIColor *)startColor endColor:(UIColor *)endColor
{
    CAGradientLayer *gradient = [[CAGradientLayer alloc] init];
    gradient.bounds = item.layer.bounds;
    gradient.contentsScale = item.layer.contentsScale;
    gradient.colors = @[(__bridge id)startColor.CGColor, (__bridge id)endColor.CGColor];
    gradient.startPoint = CGPointMake(.5, 0.);
    gradient.endPoint = CGPointMake(.5, 1.);
    return gradient;
}

- (void)removeGradientLayersForItem:(UIView *)item
{
    NSArray *sublayers = [NSArray arrayWithArray:item.layer.sublayers];
    for (CALayer *layer in sublayers)
    {
        if ([layer.name isEqualToString:UnselectedGradientName] || [layer.name isEqualToString:SelectedGradientName])
        {
            [layer removeFromSuperlayer];
        }
    }
}

- (void)removeGradientLayersForItems
{
    for (UIView *item in _items)
    {
        [self removeGradientLayersForItem:item];
    }
    
    [self highlightSelectedSegment];
}

- (void)createGradientLayersForItem:(UIView *)item
{
    // Remove existing gradient layers
    [self removeGradientLayersForItem:item];
    
    // Add gradient layers
    CAGradientLayer *unselectedGradient = [self createGradientLayerForItem:item
                                                                startColor:self.unselectedBackgroundGradientStart
                                                                  endColor:self.unselectedBackgroundGradientEnd];
    unselectedGradient.name = UnselectedGradientName;
    CAGradientLayer *selectedGradient = [self createGradientLayerForItem:item
                                                              startColor:self.selectedBackgroundGradientStart
                                                                endColor:self.selectedBackgroundGradientEnd];
    selectedGradient.name = SelectedGradientName;
    selectedGradient.opacity = 0.;
    [item.layer insertSublayer:selectedGradient atIndex:0];
    [item.layer insertSublayer:unselectedGradient atIndex:0];
}

- (void)createGradientLayersForItems
{
    for (UIView *item in _items)
    {
        [self createGradientLayersForItem:item];
    }
    
    [self highlightSelectedSegment];
}

- (void)adjustGradientLayerSizeForItem:(UIView *)item
{
    for (CALayer *layer in item.layer.sublayers)
    {
        if ([layer.name isEqualToString:UnselectedGradientName] || [layer.name isEqualToString:SelectedGradientName])
        {
            CGRect bounds = item.layer.bounds;
            bounds.size.width *= layer.contentsScale;
            bounds.size.height *= layer.contentsScale;
            
            layer.frame = bounds;
        }
    }
}

- (void)adjustGradientLayerSizesForItems
{
    for (UIView *item in _items)
    {
        [self adjustGradientLayerSizeForItem:item];
    }
}

- (void)removeSegmentAtIndex:(NSUInteger)index animated:(BOOL)animated
{
    if (index >= _items.count)
        return;
    
    // Adjust the selected segment index if necessary
    if (self.selectedSegmentIndex >= index)
    {
        self.selectedSegmentIndex--;
    }
    
    // If this is the last segment, remove the spacer from the new last segment
    if (index == _items.count - 1)
    {
        UIView *lastSegment = _items[index - 1];
        [lastSegment.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    }
    
    // Remove the segment and redraw
    UIView *segmentView = _items[index];
    if (animated)
    {
        [_items removeObject:segmentView];
        [UIView animateWithDuration:.4 animations:^
         {
             [self adjustSize];
         }
        completion:^(BOOL finished)
         {
             [segmentView removeFromSuperview];
         }];
    }
    else
    {
        [segmentView removeFromSuperview];
        [_items removeObject:segmentView];
        [self adjustSize];
    }
}

- (void)removeAllSegments
{
    [_items makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [_items removeAllObjects];
    self.selectedSegmentIndex = -1;
}

- (void)handleSelect:(UIGestureRecognizer *)gestureRecognizer
{
    NSUInteger index = [_items indexOfObject:gestureRecognizer.view.superview];
    if (index != NSNotFound)
    {
        // Set the new selected index
        self.selectedSegmentIndex = index;
        
        [self sendActionsForControlEvents:UIControlEventValueChanged];
    }
}

@end
