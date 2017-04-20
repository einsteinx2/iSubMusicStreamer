//
//  CALayer+SublayerWithName.h
//  EX2Kit
//
//  Created by Benjamin Baron on 4/23/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@interface CALayer (SublayerWithName)

- (CALayer *)sublayerWithName:(NSString *)name;

@end
