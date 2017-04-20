//
//  BassEffectValue.h
//  Anghami
//
//  Created by Benjamin Baron on 12/4/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "BassEffectDAO.h"

@interface BassEffectValue : NSObject

@property BassEffectType type;
@property CGFloat percentX;
@property CGFloat percentY;
@property BOOL isDefault;

@end
