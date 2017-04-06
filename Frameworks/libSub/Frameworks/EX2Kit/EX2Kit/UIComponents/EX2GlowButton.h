//
//  EX2GlowButton.h
//  EX2Kit
//
//  Created by Benjamin Baron on 5/21/13.
//
//

#import <UIKit/UIKit.h>

@interface EX2GlowButton : UIButton

@property (nonatomic, strong) UIColor *glowColor;
@property (nonatomic) CGFloat fromIntensity;
@property (nonatomic) CGFloat toIntensity;
@property (nonatomic) CGFloat radius;
@property (nonatomic) NSUInteger overdub;

@end
