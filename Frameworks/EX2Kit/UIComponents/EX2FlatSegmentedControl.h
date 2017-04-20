//
//  EX2FlatSegmentedControl.h
//  EX2Kit
//
//  Created by Benjamin Baron on 6/25/13.
//
//

#import <UIKit/UIKit.h>

@interface EX2FlatSegmentedControl : UISegmentedControl

@property (nonatomic, strong) UIColor *borderColor;

// Flat background
@property (nonatomic, strong) UIColor *selectedBackgroundColor;

// Optional gradient background
@property (nonatomic, strong) UIColor *unselectedBackgroundGradientStart;
@property (nonatomic, strong) UIColor *unselectedBackgroundGradientEnd;
@property (nonatomic, strong) UIColor *selectedBackgroundGradientStart;
@property (nonatomic, strong) UIColor *selectedBackgroundGradientEnd;

// Text colors
@property (nonatomic, strong) UIColor *selectedTextColor;
@property (nonatomic, strong) UIColor *unselectedTextColor;

// Text fonts
@property (nonatomic, strong) UIFont *selectedFont;
@property (nonatomic, strong) UIFont *unselectedFont;

// Sizes
@property (nonatomic) CGFloat segmentMargin;
@property (nonatomic) CGFloat borderWidth;
@property (nonatomic) CGFloat staticWidth; // Use a predefined width instead of auto-sizing based on the text

// Items
@property (nonatomic, strong) NSArray *items;

@end

