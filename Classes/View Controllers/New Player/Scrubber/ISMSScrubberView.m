//
//  ISMSScrubberView.m
//  iSub
//
//  Created by Justin Hill on 10/2/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

#import "ISMSScrubberView.h"

@interface ISMSScrubberView ()
{
    double _elapsedPercentage;
}

@end

@implementation ISMSScrubberView

- (instancetype)init {
    if (self = [super init]) {
        self.backgroundColor = [UIColor whiteColor];
    }
    
    return self;
}

- (double)elapsedPercentage {
    return _elapsedPercentage;
}

- (void)setElapsedPercentage:(double)elapsedPercentage {
    _elapsedPercentage = elapsedPercentage;
}

@end
